import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';
import { emailService } from '../src/services/email.service';
import { authService } from '../src/services/auth.service';

describe('Milestone 6 — Email OTP Registration & Security Stabilization', () => {
  beforeEach(() => {
    emailService.clearTestMailbox();
  });

  describe('1. Valid Code Verification & Session Issuance', () => {
    it('generates a 6-digit OTP, sends email, verifies correctly, and issues JWT session', async () => {
      const email = `otp_valid_${Date.now()}@example.com`;
      const password = 'Password123!';
      const name = 'Alex Chen';

      // Step 1: Request Registration OTP
      const reqRes = await request(app)
        .post('/api/v1/auth/register-request')
        .send({ name, email, password, timezone: 'Asia/Kolkata' });

      expect(reqRes.status).toBe(200);
      expect(reqRes.body.success).toBe(true);
      expect(reqRes.body.pendingVerification).toBe(true);
      expect(reqRes.body.token).toBeUndefined(); // MUST NOT issue session token prior to verification

      // Check test mailbox
      const otp = emailService.getLatestOtpForEmail(email);
      expect(otp).toBeDefined();
      expect(otp).toMatch(/^\d{6}$/);

      // Verify user is NOT in database yet
      const unverifiedDbUser = await prisma.user.findUnique({ where: { email } });
      expect(unverifiedDbUser).toBeNull();

      // Step 2: Verify Registration OTP
      const verifyRes = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp });

      expect(verifyRes.status).toBe(200);
      expect(verifyRes.body.token).toBeDefined();
      expect(verifyRes.body.user).toBeDefined();
      expect(verifyRes.body.user.email).toBe(email);
      expect(verifyRes.body.user.name).toBe(name);

      // Verify user now exists in database with isEmailVerified: true
      const verifiedDbUser = await prisma.user.findUnique({ where: { email } });
      expect(verifiedDbUser).not.toBeNull();
      expect(verifiedDbUser?.isEmailVerified).toBe(true);
      expect(verifiedDbUser?.name).toBe(name);

      // Verify default constraints and subjects were created
      const constraint = await prisma.userConstraint.findUnique({ where: { userId: verifiedDbUser!.id } });
      expect(constraint).not.toBeNull();
      expect(constraint?.minSleepHours).toBe(7.0);

      const subjects = await prisma.subject.findMany({ where: { userId: verifiedDbUser!.id } });
      expect(subjects.length).toBeGreaterThanOrEqual(5);
    });
  });

  describe('2. Invalid Code Handling & Remaining Attempts', () => {
    it('returns 400 INVALID_OTP with decremented remaining attempts on wrong code', async () => {
      const email = `otp_invalid_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      const wrongOtp = '000000';
      const verifyRes = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp: wrongOtp });

      expect(verifyRes.status).toBe(400);
      expect(verifyRes.body.error.code).toBe('INVALID_OTP');
      expect(verifyRes.body.error.remainingAttempts).toBe(4);
    });

    it('locks out code after 5 failed attempts with TOO_MANY_ATTEMPTS', async () => {
      const email = `otp_lockout_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      const realOtp = emailService.getLatestOtpForEmail(email)!;

      // Fail 5 times
      for (let i = 0; i < 4; i++) {
        const res = await request(app)
          .post('/api/v1/auth/verify-registration-otp')
          .send({ email, otp: '111111' });
        expect(res.status).toBe(400);
      }

      // 5th attempt locks code
      const fifthRes = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp: '111111' });
      expect(fifthRes.status).toBe(429);
      expect(fifthRes.body.error.code).toBe('TOO_MANY_ATTEMPTS');

      // Subsequent attempt even with REAL code is rejected
      const lockedRes = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp: realOtp });
      expect(lockedRes.status).toBe(429);
      expect(lockedRes.body.error.code).toBe('TOO_MANY_ATTEMPTS');
    });
  });

  describe('3. Code Expiration (>10 minutes)', () => {
    it('rejects expired OTP with 400 OTP_EXPIRED', async () => {
      const email = `otp_expired_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      const otp = emailService.getLatestOtpForEmail(email)!;

      // Simulate expiration by setting expiresAt in the past
      await prisma.registrationOtp.updateMany({
        where: { email },
        data: { expiresAt: new Date(Date.now() - 5000) }
      });

      const res = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp });

      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('OTP_EXPIRED');
    });
  });

  describe('4. Resend Cooldown & Previous Code Invalidation', () => {
    it('enforces 60-second cooldown between code requests', async () => {
      const email = `otp_cooldown_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      // Immediate resend attempt
      const resendRes = await request(app)
        .post('/api/v1/auth/resend-registration-otp')
        .send({ email });

      expect(resendRes.status).toBe(429);
      expect(resendRes.body.error.code).toBe('COOLDOWN_ACTIVE');
      expect(resendRes.body.error.retryAfterSeconds).toBeGreaterThan(0);
    });

    it('resends new code after cooldown and invalidates the previous code', async () => {
      const email = `otp_resend_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      const firstOtp = emailService.getLatestOtpForEmail(email)!;

      // Fast-forward cooldown in DB
      await prisma.registrationOtp.updateMany({
        where: { email },
        data: { resendCooldownUntil: new Date(Date.now() - 1000) }
      });

      // Resend OTP
      const resendRes = await request(app)
        .post('/api/v1/auth/resend-registration-otp')
        .send({ email });

      expect(resendRes.status).toBe(200);
      expect(resendRes.body.success).toBe(true);

      const secondOtp = emailService.getLatestOtpForEmail(email)!;

      // Attempt to verify with OLD code should fail
      if (firstOtp !== secondOtp) {
        const oldVerify = await request(app)
          .post('/api/v1/auth/verify-registration-otp')
          .send({ email, otp: firstOtp });
        expect(oldVerify.status).toBe(400);
      }

      // Verifying with NEW code succeeds
      const newVerify = await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp: secondOtp });
      expect(newVerify.status).toBe(200);
      expect(newVerify.body.token).toBeDefined();
    });
  });

  describe('5. Duplicate & Concurrent Verification Protection', () => {
    it('prevents concurrent verification requests from creating duplicate users', async () => {
      const email = `otp_concurrent_${Date.now()}@example.com`;
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      const otp = emailService.getLatestOtpForEmail(email)!;

      // Fire two verification requests concurrently
      const [res1, res2] = await Promise.all([
        request(app).post('/api/v1/auth/verify-registration-otp').send({ email, otp }),
        request(app).post('/api/v1/auth/verify-registration-otp').send({ email, otp })
      ]);

      const successCount = [res1, res2].filter(r => r.status === 200).length;
      const rejectCount = [res1, res2].filter(r => r.status >= 400).length;

      expect(successCount).toBe(1);
      expect(rejectCount).toBe(1);

      // Verify exactly one user in database
      const users = await prisma.user.findMany({ where: { email } });
      expect(users.length).toBe(1);
    });
  });

  describe('6. Existing User Compatibility & Non-Disclosure', () => {
    it('existing user logs in directly with password without OTP', async () => {
      const email = `existing_user_${Date.now()}@example.com`;
      const password = 'Password123!';

      // Create existing user directly
      await authService.createVerifiedUser(email, password, 'Asia/Kolkata', 'Existing User');

      // Login directly
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({ email, password });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.token).toBeDefined();
    });

    it('register-request for existing email does not disclose user existence', async () => {
      const email = `existing_private_${Date.now()}@example.com`;
      await authService.createVerifiedUser(email, 'Password123!', 'Asia/Kolkata');

      // Attempt registration with same email
      const regRes = await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'OtherPassword123!' });

      // Returns generic success without revealing existence
      expect(regRes.status).toBe(200);
      expect(regRes.body.success).toBe(true);
      expect(regRes.body.pendingVerification).toBe(true);

      // Notice email is sent to account owner
      const mailbox = emailService.getTestMailbox();
      const notice = mailbox.find(m => m.to === email && m.subject.includes('Notification'));
      expect(notice).toBeDefined();
    });
  });

  describe('7. Unverified Account Login Protection', () => {
    it('blocks login when email is not verified', async () => {
      const email = `unverified_${Date.now()}@example.com`;
      const password = 'Password123!';

      // Request OTP but DO NOT verify
      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password });

      // Attempt login
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({ email, password });

      // Should fail (401 because user is not in User table yet)
      expect(loginRes.status).toBe(401);
    });

    it('allows successful login after completing OTP verification', async () => {
      const email = `verified_login_${Date.now()}@example.com`;
      const password = 'Password123!';

      await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password });

      const otp = emailService.getLatestOtpForEmail(email)!;
      await request(app)
        .post('/api/v1/auth/verify-registration-otp')
        .send({ email, otp });

      // Now login succeeds
      const loginRes = await request(app)
        .post('/api/v1/auth/login')
        .send({ email, password });

      expect(loginRes.status).toBe(200);
      expect(loginRes.body.token).toBeDefined();
    });
  });

  describe('8. Email Provider Failure Safety', () => {
    it('returns 502 EMAIL_DELIVERY_FAILED when provider transport fails in non-test mode', async () => {
      // Temporarily simulate non-test mode error
      const origEnv = process.env.NODE_ENV;
      (process.env as any).NODE_ENV = 'production';

      const email = `provider_fail_${Date.now()}@example.com`;
      const res = await request(app)
        .post('/api/v1/auth/register-request')
        .send({ email, password: 'Password123!' });

      // Restore env
      (process.env as any).NODE_ENV = origEnv;

      expect(res.status).toBe(502);
      expect(res.body.error.code).toBe('EMAIL_DELIVERY_FAILED');
    });
  });
});
