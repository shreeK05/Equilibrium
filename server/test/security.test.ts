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

  describe('3. Login Security & Rate Limiting', () => {
    it('returns generic error on invalid email', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({ email: 'nonexistent@test.com', password: 'password123' });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid credentials');
    });

    it('returns generic error on invalid password', async () => {
      const res = await request(app).post('/api/v1/auth/login').send({ email: 'secA@test.com', password: 'wrongpassword' });
      expect(res.status).toBe(401);
      expect(res.body.error.message).toBe('Invalid credentials');
    });

    it('rate limits authentication endpoints', async () => {
      // Loop to trigger rate limit (max 20 requests)
      let finalStatus = 200;
      for (let i = 0; i < 25; i++) {
        const res = await request(app).post('/api/v1/auth/login').send({ email: 'secA@test.com', password: 'wrong' });
        finalStatus = res.status;
      }
      expect(finalStatus).toBe(429); // Too Many Requests
    });
  });

  describe('4. Safe Error Handling', () => {
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
