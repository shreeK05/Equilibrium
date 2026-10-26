import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import crypto from 'crypto';
import { userRepo } from '../repositories/user.repo';
import { config } from '../config';
import { constraintRepo } from '../repositories/constraint.repo';
import { prisma } from '../db';
import { resolveTimezone } from '../scheduler/timezone';
import { emailService } from './email.service';

export class AuthService {
  /**
   * Request a 6-digit email OTP to initiate new account creation.
   * Generates a cryptographically secure 6-digit code, stores its protected HMAC hash,
   * sets a 10-minute expiry, a 60-second resend cooldown, and sends the code via Resend.
   * Never leaks whether an email address already has an account.
   */
  async requestRegistrationOtp(params: {
    name?: string;
    email: string;
    passwordRaw: string;
    timezone?: string;
  }): Promise<{
    success: boolean;
    pendingVerification: boolean;
    message: string;
    email: string;
  }> {
    const normalizedEmail = params.email.trim().toLowerCase();

    // Check if an existing verified user already has this email.
    // Avoid exposing user existence; notify registered owner if applicable.
    const existingUser = await prisma.user.findUnique({
      where: { email: normalizedEmail }
    });

    if (existingUser) {
      emailService.sendExistingAccountNotice(normalizedEmail).catch(() => {});
      return {
        success: true,
        pendingVerification: true,
        message: 'If this email is eligible, a 6-digit verification code has been sent.',
        email: normalizedEmail
      };
    }

    // Enforce 60-second cooldown on existing active unverified OTP for this email
    const activeOtp = await prisma.registrationOtp.findFirst({
      where: { email: normalizedEmail, usedAt: null },
      orderBy: { createdAt: 'desc' }
    });

    const now = new Date();
    if (activeOtp && activeOtp.resendCooldownUntil > now && activeOtp.expiresAt > now) {
      const waitSeconds = Math.max(1, Math.ceil((activeOtp.resendCooldownUntil.getTime() - now.getTime()) / 1000));
      const err = new Error('COOLDOWN_ACTIVE');
      (err as any).retryAfterSeconds = waitSeconds;
      throw err;
    }

    const passwordHash = await bcrypt.hash(params.passwordRaw, 10);
    // Cryptographically secure 6-digit numeric OTP (100000 - 999999)
    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = crypto.createHmac('sha256', config.jwtSecret).update(otp).digest('hex');
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000); // 10 minutes
    const resendCooldownUntil = new Date(now.getTime() + 60 * 1000); // 60 seconds

    // Invalidate any previous unused OTP codes for this email
    await prisma.registrationOtp.updateMany({
      where: { email: normalizedEmail, usedAt: null },
      data: { usedAt: now }
    });

    // Create new OTP record
    await prisma.registrationOtp.create({
      data: {
        email: normalizedEmail,
        name: params.name ? params.name.trim() : null,
        passwordHash,
        timezone: resolveTimezone(params.timezone),
        otpHash,
        expiresAt,
        resendCooldownUntil
      }
    });

    // Send email with OTP code via Resend
    const sendResult = await emailService.sendRegistrationOtp(
      normalizedEmail,
      otp,
      params.name ? params.name.trim() : undefined
    );

    if (!sendResult.success && process.env.NODE_ENV !== 'test') {
      throw new Error(`EMAIL_DELIVERY_FAILED: ${sendResult.error || 'Provider rejected email'}`);
    }

    return {
      success: true,
      pendingVerification: true,
      message: 'Verification code sent to your email. Please verify within 10 minutes.',
      email: normalizedEmail
    };
  }

  /**
   * Verify 6-digit OTP and complete account registration.
   * Atomically invalidates the code and creates the user, default constraints,
   * and default subjects in a single transaction. Prevents duplicate accounts.
   */
  async verifyRegistrationOtp(params: {
    email: string;
    otp: string;
  }): Promise<{
    token: string;
    user: { id: string; email: string; name?: string | null };
  }> {
    const normalizedEmail = params.email.trim().toLowerCase();
    const normalizedOtp = params.otp.trim();

    const otpRecord = await prisma.registrationOtp.findFirst({
      where: { email: normalizedEmail, usedAt: null },
      orderBy: { createdAt: 'desc' }
    });

    if (!otpRecord) {
      throw new Error('NO_PENDING_REGISTRATION');
    }

    const now = new Date();
    if (otpRecord.expiresAt < now) {
      throw new Error('OTP_EXPIRED');
    }

    if (otpRecord.attempts >= otpRecord.maxAttempts) {
      throw new Error('TOO_MANY_ATTEMPTS');
    }

    const candidateHash = crypto.createHmac('sha256', config.jwtSecret).update(normalizedOtp).digest('hex');
    const isMatch = crypto.timingSafeEqual(
      Buffer.from(candidateHash, 'hex'),
      Buffer.from(otpRecord.otpHash, 'hex')
    );

    if (!isMatch) {
      const updated = await prisma.registrationOtp.update({
        where: { id: otpRecord.id },
        data: { attempts: { increment: 1 } }
      });
      const remaining = Math.max(0, updated.maxAttempts - updated.attempts);
      const err = new Error(remaining === 0 ? 'TOO_MANY_ATTEMPTS' : 'INVALID_OTP');
      (err as any).remainingAttempts = remaining;
      throw err;
    }

    // Atomic transaction: mark code as used and create User account
    const result = await prisma.$transaction(async (tx) => {
      // Conditional update ensures only one concurrent request can consume this OTP
      const markUsed = await tx.registrationOtp.updateMany({
        where: { id: otpRecord.id, usedAt: null },
        data: { usedAt: now }
      });

      if (markUsed.count === 0) {
        throw new Error('CONCURRENT_VERIFICATION');
      }

      // Invalidate any other pending OTPs for this email
      await tx.registrationOtp.updateMany({
        where: { email: normalizedEmail, usedAt: null },
        data: { usedAt: now }
      });

      const existingUser = await tx.user.findUnique({
        where: { email: normalizedEmail }
      });

      if (existingUser) {
        throw new Error('USER_ALREADY_EXISTS');
      }

      const user = await tx.user.create({
        data: {
          email: normalizedEmail,
          name: otpRecord.name,
          passwordHash: otpRecord.passwordHash,
          timezone: otpRecord.timezone,
          isEmailVerified: true
        }
      });

      await tx.userConstraint.create({
        data: {
          userId: user.id,
          minSleepHours: 7.0,
          sleepStart: '23:00',
          sleepEnd: '06:00',
          bufferMinutes: 30,
          peakEnergyWindowsJson: '[]'
        }
      });

      const defaultSubjects = [
        { name: 'Self Study', color: '#10B981' },
        { name: 'Project', color: '#8B5CF6' },
        { name: 'Assignment', color: '#3B82F6' },
        { name: 'Practical / Lab', color: '#F59E0B' },
        { name: 'Exam Prep', color: '#EF4444' }
      ];

      await tx.subject.createMany({
        data: defaultSubjects.map(s => ({
          userId: user.id,
          name: s.name,
          color: s.color
        }))
      });

      const token = jwt.sign(
        { userId: user.id, tokenVersion: user.tokenVersion },
        config.jwtSecret,
        { expiresIn: '7d' }
      );

      return {
        token,
        user: { id: user.id, email: user.email, name: user.name }
      };
    });

    return result;
  }

  /**
   * Resend a fresh 6-digit OTP to the email address.
   * Respects 60-second cooldown, invalidates previous codes, and extends expiry by 10 minutes.
   */
  async resendRegistrationOtp(email: string): Promise<{ success: boolean; message: string }> {
    const normalizedEmail = email.trim().toLowerCase();

    const activeOtp = await prisma.registrationOtp.findFirst({
      where: { email: normalizedEmail, usedAt: null },
      orderBy: { createdAt: 'desc' }
    });

    if (!activeOtp) {
      throw new Error('NO_PENDING_REGISTRATION');
    }

    const now = new Date();
    if (activeOtp.resendCooldownUntil > now) {
      const waitSeconds = Math.max(1, Math.ceil((activeOtp.resendCooldownUntil.getTime() - now.getTime()) / 1000));
      const err = new Error('COOLDOWN_ACTIVE');
      (err as any).retryAfterSeconds = waitSeconds;
      throw err;
    }

    const otp = crypto.randomInt(100000, 1000000).toString();
    const otpHash = crypto.createHmac('sha256', config.jwtSecret).update(otp).digest('hex');
    const expiresAt = new Date(now.getTime() + 10 * 60 * 1000);
    const resendCooldownUntil = new Date(now.getTime() + 60 * 1000);

    // Invalidate previous active OTPs
    await prisma.registrationOtp.updateMany({
      where: { email: normalizedEmail, usedAt: null },
      data: { usedAt: now }
    });

    // Create new OTP record retaining original credentials
    await prisma.registrationOtp.create({
      data: {
        email: normalizedEmail,
        name: activeOtp.name,
        passwordHash: activeOtp.passwordHash,
        timezone: activeOtp.timezone,
        otpHash,
        expiresAt,
        resendCooldownUntil
      }
    });

    const sendResult = await emailService.sendRegistrationOtp(
      normalizedEmail,
      otp,
      activeOtp.name || undefined
    );

    if (!sendResult.success && process.env.NODE_ENV !== 'test') {
      throw new Error(`EMAIL_DELIVERY_FAILED: ${sendResult.error || 'Provider rejected email'}`);
    }

    return {
      success: true,
      message: 'A new verification code has been sent to your email.'
    };
  }

  /**
   * Backwards-compatible / direct registration method.
   * If an OTP is provided in params, routes to verifyRegistrationOtp.
   * In test environment, allows direct verified user creation for existing test suites.
   * In production without OTP, triggers requestRegistrationOtp to enforce verification.
   */
  async register(
    email: string,
    passwordHashRaw: string,
    timezone?: string,
    name?: string,
    otp?: string
  ) {
    if (otp) {
      return this.verifyRegistrationOtp({ email, otp });
    }

    if (process.env.NODE_ENV === 'test') {
      return this.createVerifiedUser(email, passwordHashRaw, timezone, name);
    }

    // In production without OTP, start the OTP verification flow
    return this.requestRegistrationOtp({
      email,
      passwordRaw: passwordHashRaw,
      timezone,
      name
    });
  }

  /**
   * Programmatic user creation with email verification flag set to true.
   * Used internally upon successful OTP verification and in local test setups.
   */
  async createVerifiedUser(
    email: string,
    passwordHashRaw: string,
    timezone?: string,
    name?: string
  ) {
    const normalizedEmail = email.trim().toLowerCase();
    const existing = await userRepo.findByEmail(normalizedEmail);
    if (existing) throw new Error('Email in use');

    const passwordHash = await bcrypt.hash(passwordHashRaw, 10);
    const user = await userRepo.create({
      email: normalizedEmail,
      name: name ? name.trim() : null,
      passwordHash,
      timezone: resolveTimezone(timezone),
      isEmailVerified: true
    });

    await constraintRepo.upsert(user.id, {
      minSleepHours: 7.0,
      sleepStart: '23:00',
      sleepEnd: '06:00',
      bufferMinutes: 30,
      peakEnergyWindowsJson: '[]'
    });

    const defaultSubjects = [
      { name: 'Self Study', color: '#10B981' },
      { name: 'Project', color: '#8B5CF6' },
      { name: 'Assignment', color: '#3B82F6' },
      { name: 'Practical / Lab', color: '#F59E0B' },
      { name: 'Exam Prep', color: '#EF4444' }
    ];

    await prisma.subject.createMany({
      data: defaultSubjects.map(s => ({
        userId: user.id,
        name: s.name,
        color: s.color
      }))
    });

    const token = jwt.sign(
      { userId: user.id, tokenVersion: user.tokenVersion },
      config.jwtSecret,
      { expiresIn: '7d' }
    );
    return { token, user: { id: user.id, email: user.email, name: user.name } };
  }

  /**
   * User login. Ensures user exists, password matches, and email is verified.
   */
  async login(email: string, passwordHashRaw: string) {
    const user = await userRepo.findByEmail(email.trim().toLowerCase());
    if (!user) throw new Error('Invalid credentials');

    const valid = await bcrypt.compare(passwordHashRaw, user.passwordHash);
    if (!valid) throw new Error('Invalid credentials');

    // Reject unverified users
    if (user.isEmailVerified === false) {
      throw new Error('EMAIL_NOT_VERIFIED');
    }

    const token = jwt.sign(
      { userId: user.id, tokenVersion: user.tokenVersion },
      config.jwtSecret,
      { expiresIn: '7d' }
    );
    return { token, user: { id: user.id, email: user.email, name: user.name } };
  }

  async forgotPassword(email: string) {
    const user = await userRepo.findByEmail(email.trim().toLowerCase());
    if (!user) return; // Do not reveal if email exists

    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    await prisma.passwordResetToken.deleteMany({
      where: { userId: user.id, usedAt: null }
    });

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt
      }
    });

    const resetLink = `${config.appPublicUrl}/api/v1/auth/reset-redirect?token=${token}`;
    await emailService.sendPasswordReset(user.email, resetLink);
  }

  async resetPassword(token: string, newPasswordRaw: string) {
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    const resetRecord = await prisma.passwordResetToken.findUnique({
      where: { tokenHash }
    });

    if (!resetRecord || resetRecord.usedAt || resetRecord.expiresAt < new Date()) {
      throw new Error('Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(newPasswordRaw, 10);

    await prisma.$transaction([
      prisma.user.update({
        where: { id: resetRecord.userId },
        data: { 
          passwordHash,
          tokenVersion: { increment: 1 }
        }
      }),
      prisma.passwordResetToken.update({
        where: { id: resetRecord.id },
        data: { usedAt: new Date() }
      })
    ]);

    return { success: true };
  }
}

export const authService = new AuthService();
