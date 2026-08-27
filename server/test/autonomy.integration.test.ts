import { app } from '../src/app';
import { prisma } from '../src/db';
import request from 'supertest';

describe('Equilibrium Autonomy & Lifecycle', () => {
  let token: string;
  let userId: string;

  beforeAll(async () => {
    // 1. Setup Auth
    const email = `student_${Date.now()}@test.com`;
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ email, password: 'password123' });
    
    token = res.body.token;
    userId = res.body.user.id;
  });

  afterAll(async () => {
    await prisma.user.delete({ where: { id: userId } });
    await prisma.$disconnect();
  });

  it('completes the full autonomous scheduling lifecycle', async () => {
    // 2. Configure Constraints & Sleep
    await request(app)
      .patch('/api/v1/constraints')
      .set('Authorization', `Bearer ${token}`)
      .send({
        sleepStart: '23:00',
        sleepEnd: '07:00',
        minSleepHours: 7.5
      })
      .expect(200);

    // 3. Add Fixed Commitments
    // Add a class that happens today at 10:00 - 12:00
    const now = new Date();
    const classStart = new Date(now);
    classStart.setUTCHours(10, 0, 0, 0);
    const classEnd = new Date(now);
    classEnd.setUTCHours(12, 0, 0, 0);

    // Ensure class isn't in the past if now > 10am
    if (now > classStart) {
      classStart.setDate(classStart.getDate() + 1);
      classEnd.setDate(classEnd.getDate() + 1);
    }

    await request(app)
      .post('/api/v1/commitments')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: 'Physics Class',
        startTime: classStart.toISOString(),
        endTime: classEnd.toISOString(),
        type: 'CLASS'
      })
      .expect(201);

    // 4. Add Tasks
    const deadline = new Date(now);
    deadline.setDate(deadline.getDate() + 2);

    const task1 = await request(app)
      .post('/api/v1/tasks')
      .set('Authorization', `Bearer ${token}`)
      .send({
        title: 'Physics Homework',
        estimateMinutes: 180, // 3 hours
        deadline: deadline.toISOString(),
        cognitiveLoad: 'HIGH'
      })
      .expect(201);
      
    // 5. Generate Initial Schedule
    const gen1 = await request(app)
      .post('/api/v1/schedules/generate')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    expect(gen1.body.blocks.length).toBeGreaterThan(0);
    const v1Id = gen1.body.id;

    // Verify task does not overlap fixed commitment
    const physicsBlocks = gen1.body.blocks.filter((b: any) => b.taskId === task1.body.id);
    for (const pb of physicsBlocks) {
      const pbStart = new Date(pb.startTime).getTime();
      const pbEnd = new Date(pb.endTime).getTime();
      const fcStart = classStart.getTime();
      const fcEnd = classEnd.getTime();

      // No overlap logic: end <= fcStart OR start >= fcEnd
      const overlaps = pbStart < fcEnd && pbEnd > fcStart;
      expect(overlaps).toBe(false);
    }

    // 6. Complete part of task (Disruption)
    await request(app)
      .patch(`/api/v1/tasks/${task1.body.id}`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        completedMinutes: 60 // completed 1 hour early
      })
      .expect(200);

    // 7. Reschedule!
    const gen2 = await request(app)
      .post(`/api/v1/schedules/${v1Id}/reschedule`)
      .set('Authorization', `Bearer ${token}`)
      .expect(201);

    expect(gen2.body.id).not.toEqual(v1Id);
    expect(gen2.body.previousVersionId).toEqual(v1Id);
    expect(gen2.body.triggerType).toEqual('DISRUPTION');

    // 8. Verify DecisionLogs generated
    expect(gen2.body.decisionLogs.length).toBeGreaterThan(0);
  });
});
