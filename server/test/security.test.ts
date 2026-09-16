import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';
import jwt from 'jsonwebtoken';
import { config } from '../src/config';

describe('Equilibrium Security Tests', () => {
  let userAToken: string;
  let userBToken: string;
  let userBId: string;
  let taskAId: string;
  let versionAId: string;

  beforeAll(async () => {
    // Clean up specific users to avoid parallel test state leakage
    await prisma.user.deleteMany({
      where: { email: { in: ['secA@test.com', 'secB@test.com'] } }
    });
    
    // Register User A
    const resA = await request(app).post('/api/v1/auth/register').send({ email: 'secA@test.com', password: 'password123' });
    userAToken = resA.body.token;

    // Register User B
    const resB = await request(app).post('/api/v1/auth/register').send({ email: 'secB@test.com', password: 'password123' });
    userBToken = resB.body.token;
    userBId = resB.body.user.id;

    // Create Task for User A
    const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
    const taskRes = await request(app).post('/api/v1/tasks').set('Authorization', `Bearer ${userAToken}`).send({
      title: 'A Task', estimateMinutes: 60, deadline
    });
    taskAId = taskRes.body.id;

    // Generate Schedule for User A
    const schedRes = await request(app).post('/api/v1/schedules/generate').set('Authorization', `Bearer ${userAToken}`);
    versionAId = schedRes.body.id;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({
      where: { email: { in: ['secA@test.com', 'secB@test.com'] } }
    });
    await prisma.$disconnect();
  });

  describe('1. Authentication Edge Cases', () => {
    it('rejects missing Authorization header', async () => {
      const res = await request(app).get('/api/v1/tasks');
      expect(res.status).toBe(401);
      expect(res.body.error.message).toMatch(/Missing or malformed/);
    });

    it('rejects missing Bearer prefix', async () => {
      const res = await request(app).get('/api/v1/tasks').set('Authorization', userAToken);
      expect(res.status).toBe(401);
    });

    it('rejects invalid JWT signature', async () => {
      const res = await request(app).get('/api/v1/tasks').set('Authorization', `Bearer ${userAToken}invalid`);
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid token');
    });

    it('rejects expired JWT', async () => {
      const expiredToken = jwt.sign({ userId: userBId }, config.jwtSecret, { expiresIn: '-1h' });
      const res = await request(app).get('/api/v1/tasks').set('Authorization', `Bearer ${expiredToken}`);
      expect(res.status).toBe(401);
      expect(res.body.error.code).toBe('TOKEN_EXPIRED');
    });
  });

  describe('2. Authorization (IDOR)', () => {
    it('prevents User B from reading User A task', async () => {
      const res = await request(app).get(`/api/v1/tasks/${taskAId}`).set('Authorization', `Bearer ${userBToken}`);
      expect(res.status).toBe(404);
    });

    it('prevents User B from updating User A task', async () => {
      const res = await request(app).patch(`/api/v1/tasks/${taskAId}`).set('Authorization', `Bearer ${userBToken}`).send({ title: 'Hacked' });
      expect(res.status).toBe(404);
    });

    it('prevents User B from deleting User A task', async () => {
      const res = await request(app).delete(`/api/v1/tasks/${taskAId}`).set('Authorization', `Bearer ${userBToken}`);
      expect(res.status).toBe(404);
    });

    it('prevents User B from viewing User A schedule version', async () => {
      const res = await request(app).get(`/api/v1/schedules/${versionAId}`).set('Authorization', `Bearer ${userBToken}`);
      expect(res.status).toBe(404);
    });

    it('prevents User B from viewing User A decision logs', async () => {
      const res = await request(app).get(`/api/v1/schedules/${versionAId}/decisions`).set('Authorization', `Bearer ${userBToken}`);
      expect(res.status).toBe(404);
    });

    it('prevents User B from rescheduling User A schedule', async () => {
      const res = await request(app).post(`/api/v1/schedules/${versionAId}/reschedule`).set('Authorization', `Bearer ${userBToken}`);
      expect(res.status).toBe(404);
    });
  });

  describe('3. Password Recovery Flow', () => {
    it('returns generic response for forgot-password on non-existent email', async () => {
      const res = await request(app).post('/api/v1/auth/forgot-password').send({ email: 'nobody@test.com' });
      expect(res.status).toBe(200);
      expect(res.body.message).toMatch(/If an account exists/);
    });

    it('generates a reset token for existing user', async () => {
      const res = await request(app).post('/api/v1/auth/forgot-password').send({ email: 'secA@test.com' });
      expect(res.status).toBe(200);
      expect(res.body.message).toMatch(/If an account exists/);

      // Verify token exists in database
      const user = await prisma.user.findUnique({ where: { email: 'seca@test.com' } });
      const tokens = await prisma.passwordResetToken.findMany({ where: { userId: user!.id } });
      expect(tokens.length).toBe(1);
      expect(tokens[0].usedAt).toBeNull();
    });

    it('serves a safe reset-redirect page with a manual button and escapes XSS', async () => {
      const xssToken = 'fakeToken" onclick="alert(1)';
      const res = await request(app).get(`/api/v1/auth/reset-redirect?token=${xssToken}`);
      expect(res.status).toBe(200);

      const html = res.text;
      // HTML contains the Open Equilibrium button
      expect(html).toContain('Open Equilibrium');
      // Button uses equilibrium://reset-password
      expect(html).toContain('href="equilibrium://reset-password?token=');
      // Token is HTML escaped
      expect(html).toContain('fakeToken&quot; onclick=&quot;alert(1)');
      // JavaScript automatic redirect is NOT present
      expect(html).not.toContain('<script>');
      expect(html).not.toContain('window.location.href');
    });

    it('rejects invalid or expired reset token', async () => {
      const res = await request(app).post('/api/v1/auth/reset-password').send({ token: 'invalid_token', newPassword: 'newpassword123' });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('INVALID_TOKEN');
    });
  });

  describe('4. Login Security & Rate Limiting', () => {
    it('returns generic error on invalid email', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({ email: 'nonexistent@test.com', password: 'password123' });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid email or password.');
    });

    it('returns generic error on invalid password', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({ email: 'secA@test.com', password: 'wrongpassword' });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid email or password.');
    });

    it('rate limits authentication endpoints', async () => {
      // Loop to trigger rate limit (max 100 requests in test mode)
      let finalStatus = 200;
      for (let i = 0; i < 105; i++) {
        const res = await request(app).post('/api/v1/auth/login').send({ email: 'secA@test.com', password: 'wrong' });
        finalStatus = res.status;
      }
      expect(finalStatus).toBe(429); // Too Many Requests
    });
  });

  describe('5. Safe Error Handling', () => {
    it('masks internal Prisma or Server errors', async () => {
      // Force a Zod error by sending malformed body to a route expecting it
      const res = await request(app).post('/api/v1/tasks').set('Authorization', `Bearer ${userAToken}`).send({
        title: '', // Too short
        estimateMinutes: -10, // Invalid
        deadline: 'not-a-date'
      });
      expect(res.status).toBe(400);
      expect(res.body.error.code).toBe('VALIDATION_ERROR');
      expect(res.body.error.details).toBeDefined();
    });
  });
});
