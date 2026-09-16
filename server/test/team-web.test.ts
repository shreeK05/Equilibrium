import request from 'supertest';
import { app } from '../src/app';
import { prisma } from '../src/db';
import crypto from 'crypto';

describe('Equilibrium Web Share Tests', () => {
  let userToken: string;
  let userId: string;
  let shareTokenUrl: string;

  beforeAll(async () => {
    // Clean up
    await prisma.user.deleteMany({ where: { email: 'shareWeb@test.com' } });
    
    // Register
    const res = await request(app).post('/api/v1/auth/register').send({ email: 'shareWeb@test.com', password: 'password123' });
    userToken = res.body.token;
    userId = res.body.user.id;

    // Create a task with malicious HTML via Prisma directly
    const task = await prisma.task.create({
      data: {
        userId,
        title: '<script>alert("XSS")</script> & <b>Bold</b>',
        description: 'Test',
        deadline: new Date(Date.now() + 48 * 3600000),
        estimateMinutes: 60,
        status: 'PENDING',
        cognitiveLoad: 'HIGH'
      }
    });

    // Insert a schedule version directly so we don't rely on the algorithm's constraints
    const scheduleVersion = await prisma.scheduleVersion.create({
      data: {
        userId,
        capacityMinutes: 60,
        algorithmVersion: '1.0',
        triggerType: 'MANUAL',
        blocks: {
          create: [{
            taskId: task.id,
            startTime: new Date(),
            endTime: new Date(Date.now() + 3600000),
            durationMinutes: 60,
            blockType: 'TASK'
          }]
        }
      }
    });

    // Generate share link
    const shareRes = await request(app).post('/api/v1/team/shares').set('Authorization', `Bearer ${userToken}`).send({ expiresInHours: 24 });
    shareTokenUrl = shareRes.body.token;
  });

  afterAll(async () => {
    await prisma.user.deleteMany({ where: { email: 'shareWeb@test.com' } });
  });

  it('valid share token -> 200 HTML', async () => {
    const res = await request(app).get(`/team/${shareTokenUrl}`);
    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.text).toContain('Shared Schedule - Equilibrium');
    expect(res.text).toContain('Read-Only View');
  });

  it('HTML escaping for malicious task/activity text', async () => {
    const res = await request(app).get(`/team/${shareTokenUrl}`);
    expect(res.status).toBe(200);
    // The script tags and bold tags should be escaped
    expect(res.text).toContain('&lt;script&gt;alert(&quot;XSS&quot;)&lt;/script&gt; &amp; &lt;b&gt;Bold&lt;/b&gt;');
    expect(res.text).not.toContain('<script>alert("XSS")</script>');
  });

  it('read-only page does not expose editing functionality', async () => {
    const res = await request(app).get(`/team/${shareTokenUrl}`);
    expect(res.status).toBe(200);
    // Basic heuristics: no edit buttons, no input forms, etc.
    expect(res.text).not.toContain('<form');
    expect(res.text).not.toContain('<input');
    expect(res.text).not.toContain('Edit');
    expect(res.text).not.toContain('Delete');
  });

  it('invalid token -> 404', async () => {
    const res = await request(app).get('/team/invalid_fake_token_123');
    expect(res.status).toBe(404);
    expect(res.text).toContain('Link Expired or Invalid');
  });

  it('expired token -> appropriate non-success response', async () => {
    // We can simulate expiration by directly inserting into DB
    const expiredToken = crypto.randomBytes(32).toString('base64url');
    const expiredHash = crypto.createHash('sha256').update(expiredToken).digest('hex');
    await prisma.teamShare.create({
      data: {
        userId,
        tokenHash: expiredHash,
        expiresAt: new Date(Date.now() - 3600000) // 1 hour ago
      }
    });

    const res = await request(app).get(`/team/${expiredToken}`);
    expect(res.status).toBe(404);
    expect(res.text).toContain('Link Expired or Invalid');
  });
});
