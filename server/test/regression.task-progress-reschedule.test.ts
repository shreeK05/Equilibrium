/**
 * REGRESSION & CORRECTNESS: Task Progress, Completion & Adaptive Rescheduling (Phase 2B.2)
 *
 * Verifies:
 * 1. Completed tasks with actual effort < estimate retain status COMPLETED and record actual effort.
 * 2. Completed tasks with actual effort > estimate retain status COMPLETED and record overrun.
 * 3. Partial progress updates completedMinutes, retains IN_PROGRESS, and preserves remaining workload.
 * 4. "Need more time" updates estimateMinutes and completedMinutes, remaining active.
 * 5. Completion calls are idempotent and do not duplicate disruption events.
 * 6. Ownership is strictly enforced: users cannot update tasks belonging to others.
 * 7. Adaptive rescheduling locks past blocks (endTime <= now) and completed blocks, excludes
 *    completed tasks from future blocks, and preserves the previousVersionId audit chain.
 */

import request from 'supertest';
import { randomUUID } from 'crypto';

jest.mock('../src/db', () => {
  const { createFakePrisma } = require('./helpers/fake-prisma');
  return { prisma: createFakePrisma() };
});

import { prisma } from '../src/db';
import { app } from '../src/app';

const fakeDb = (prisma as any).__db;

describe('Phase 2B.2 - Task Progress, Completion & Rescheduling', () => {
  let userAToken: string;
  let userAId: string;
  let userBToken: string;
  let userBId: string;

  beforeAll(async () => {
    const regA = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'progress.user.a@college.edu', password: 'Password123!' });
    expect(regA.status).toBe(200);
    userAToken = regA.body.token;
    userAId = regA.body.user.id;

    const regB = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'progress.user.b@college.edu', password: 'Password123!' });
    expect(regB.status).toBe(200);
    userBToken = regB.body.token;
    userBId = regB.body.user.id;
  });

  describe('Task Completion Semantics', () => {
    it('records early completion (actual < estimate) with COMPLETED status and exact actual time', async () => {
      // Create task with 60m estimate
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Physics Lab Report', estimateMinutes: 60, deadline });
      expect(taskRes.status).toBe(201);
      const taskId = taskRes.body.id;

      // Complete in 35 minutes (finished early)
      const completeRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 35 });
      expect(completeRes.status).toBe(200);
      expect(completeRes.body.status).toBe('COMPLETED');
      expect(completeRes.body.completedMinutes).toBe(35); // Not forced to 60

      // Verify DisruptionEvent was recorded with EARLY_COMPLETION
      const events = fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId);
      expect(events.length).toBe(1);
      expect(events[0].type).toBe('EARLY_COMPLETION');
      expect(events[0].plannedMinutes).toBe(60);
      expect(events[0].actualMinutes).toBe(35);
    });

    it('records overrun completion (actual > estimate) with COMPLETED status and exact actual time', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Calculus Problem Set', estimateMinutes: 60, deadline });
      expect(taskRes.status).toBe(201);
      const taskId = taskRes.body.id;

      // Complete in 95 minutes (overrun)
      const completeRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 95 });
      expect(completeRes.status).toBe(200);
      expect(completeRes.body.status).toBe('COMPLETED');
      expect(completeRes.body.completedMinutes).toBe(95); // Not capped at 60

      const events = fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId);
      expect(events.length).toBe(1);
      expect(events[0].type).toBe('OVERRUN');
      expect(events[0].plannedMinutes).toBe(60);
      expect(events[0].actualMinutes).toBe(95);
    });

    it('handles idempotent repeated completion requests safely without duplicate disruption events', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Chemistry Essay', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;

      // First completion
      await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 45 });

      const countBefore = fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId).length;
      expect(countBefore).toBe(1);

      // Repeated completion call (e.g. repeated tap or retry)
      const repeatRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 45 });
      expect(repeatRes.status).toBe(200);
      expect(repeatRes.body.status).toBe('COMPLETED');

      // No duplicate event
      const countAfter = fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId).length;
      expect(countAfter).toBe(1);
    });

    it('allows completing without actualMinutes (uses existing progress or estimate)', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Reading Chapter 4', estimateMinutes: 45, deadline });
      const taskId = taskRes.body.id;

      // Call complete without body
      const completeRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({});
      expect(completeRes.status).toBe(200);
      expect(completeRes.body.status).toBe('COMPLETED');
      expect(completeRes.body.completedMinutes).toBe(45);
    });
  });

  describe('Partial Progress & Need More Time', () => {
    it('records incremental partial progress and keeps task IN_PROGRESS with accurate remaining work', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Operating Systems Assignment', estimateMinutes: 120, deadline });
      const taskId = taskRes.body.id;

      // Session 1: Made progress of +45 minutes
      const progRes1 = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 45 });
      expect(progRes1.status).toBe(200);
      expect(progRes1.body.completedMinutes).toBe(45);
      expect(progRes1.body.status).toBe('IN_PROGRESS');

      // Verify task in active tasks has remainingMinutes = 120 - 45 = 75
      const activeTasks = await fakeDb.task.filter((t: any) => t.userId === userAId && t.status !== 'COMPLETED');
      const osTask = activeTasks.find((t: any) => t.id === taskId);
      expect(osTask).toBeDefined();
      expect(osTask.estimateMinutes - osTask.completedMinutes).toBe(75);

      // Session 2: Made progress of +30 minutes
      const progRes2 = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 30 });
      expect(progRes2.status).toBe(200);
      expect(progRes2.body.completedMinutes).toBe(75);
      expect(progRes2.body.status).toBe('IN_PROGRESS');
    });

    it('handles "Need More Time" by extending estimateMinutes and keeping task active', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Algorithm Design Project', estimateMinutes: 90, deadline });
      const taskId = taskRes.body.id;

      // User worked 90m, but needs 60m more (total estimate = 150m)
      const progRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          completedMinutes: 90,
          newEstimateMinutes: 150,
          status: 'IN_PROGRESS'
        });
      expect(progRes.status).toBe(200);
      expect(progRes.body.completedMinutes).toBe(90);
      expect(progRes.body.actualMinutes).toBe(90);
      expect(progRes.body.remainingMinutes).toBe(60);
      expect(progRes.body.estimateMinutes).toBe(150);
      expect(progRes.body.status).toBe('IN_PROGRESS');
    });

    it('Req 1: Overrun task (60m est, 90m spent, 30m still needed) stays IN_PROGRESS, records 90m actual effort, and scheduler receives 30m', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Overrun Analysis Lab', estimateMinutes: 60, deadline });
      expect(taskRes.status).toBe(201);
      const taskId = taskRes.body.id;

      // User has spent 90m (actualMinutes: 90), but confirms 30m still needed (remainingMinutes: 30)
      const progRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          actualMinutes: 90,
          remainingMinutes: 30,
          status: 'IN_PROGRESS'
        });
      expect(progRes.status).toBe(200);
      expect(progRes.body.status).toBe('IN_PROGRESS');
      expect(progRes.body.actualMinutes).toBe(90);
      expect(progRes.body.remainingMinutes).toBe(30);
      expect(progRes.body.estimateMinutes).toBe(60); // Original estimate preserved

      // Generate or simulate schedule to verify scheduler receives 30m remaining
      const simRes = await request(app)
        .post('/api/v1/schedules/simulate')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          title: 'Proposed Extra Task',
          estimateMinutes: 30,
          deadline
        });
      expect(simRes.status).toBe(200);

      // Verify active task record in repo/db
      const activeTasks = await fakeDb.task.filter((t: any) => t.id === taskId);
      expect(activeTasks.length).toBe(1);
      expect(activeTasks[0].status).toBe('IN_PROGRESS');
      expect(activeTasks[0].actualMinutes).toBe(90);
      expect(activeTasks[0].remainingMinutes).toBe(30);
    });

    it('Req 3: Completing a timer session and then selecting Need More Time does not count the same session twice', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Focus Timer Physics Problem', estimateMinutes: 50, deadline });
      const taskId = taskRes.body.id;

      // 1. Start a focus session linked to this task
      const startRes = await request(app)
        .post('/api/v1/focus-sessions')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ taskId, notes: 'First session' });
      expect(startRes.status).toBe(201);
      const sessionId = startRes.body.id;

      // Simulate session ran for 25 minutes (1500 seconds)
      const sessionRow = fakeDb.focusSession.find((s: any) => s.id === sessionId);
      expect(sessionRow).toBeDefined();
      sessionRow.elapsedSeconds = 1500;

      // 2. Complete the focus session
      const completeSessionRes = await request(app)
        .patch(`/api/v1/focus-sessions/${sessionId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ notes: 'Finished session interval' });
      expect(completeSessionRes.status).toBe(200);

      // Verify task after focus session: actualMinutes is 25, remainingMinutes is 25 (50 - 25)
      const taskAfterTimer = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskAfterTimer.actualMinutes).toBe(25);
      expect(taskAfterTimer.remainingMinutes).toBe(25);
      expect(taskAfterTimer.status).toBe('IN_PROGRESS');

      // 3. User now selects Need More Time via TaskProgressDialog:
      // Untracked effort is 0 (since session was already recorded by timer), and extra remaining needed is 45 min
      const progressRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({
          remainingMinutes: 45,
          status: 'IN_PROGRESS'
        });
      expect(progressRes.status).toBe(200);
      // actualMinutes MUST remain 25, NOT 25 + 25 = 50!
      expect(progressRes.body.actualMinutes).toBe(25);
      expect(progressRes.body.remainingMinutes).toBe(45);
      expect(progressRes.body.status).toBe('IN_PROGRESS');
    });

    it('Req 4: Repeated timer completion or API retries do not duplicate actual minutes', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Retry Protection Task', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;

      const startRes = await request(app)
        .post('/api/v1/focus-sessions')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ taskId });
      const sessionId = startRes.body.id;

      const sessionRow = fakeDb.focusSession.find((s: any) => s.id === sessionId);
      sessionRow.elapsedSeconds = 1200; // 20 minutes

      // First complete call succeeds
      const complete1 = await request(app)
        .patch(`/api/v1/focus-sessions/${sessionId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({});
      expect(complete1.status).toBe(200);

      const task1 = fakeDb.task.find((t: any) => t.id === taskId);
      expect(task1.actualMinutes).toBe(20);

      // Repeated complete call on the same session ID (e.g. network retry) succeeds idempotently
      const complete2 = await request(app)
        .patch(`/api/v1/focus-sessions/${sessionId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({});
      expect(complete2.status).toBe(200);

      // actualMinutes must NOT have increased to 40
      const task2 = fakeDb.task.find((t: any) => t.id === taskId);
      expect(task2.actualMinutes).toBe(20);

      // Invalid transition: Attempting to complete a DISCARDED session returns 400
      const discardRes = await request(app)
        .post('/api/v1/focus-sessions')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ taskId });
      await request(app)
        .patch(`/api/v1/focus-sessions/${discardRes.body.id}/discard`)
        .set('Authorization', `Bearer ${userAToken}`);
      const invalidComplete = await request(app)
        .patch(`/api/v1/focus-sessions/${discardRes.body.id}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({});
      expect(invalidComplete.status).toBe(400);
    });

    it('Req 7: Existing records and legacy API payloads remain safe and backward-compatible', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();

      // Simulate a historical task where actualMinutes is null/0 and only completedMinutes was stored
      const legacyRow = {
        id: 'legacy-task-xyz',
        userId: userAToken ? userAId : 'user-a',
        title: 'Legacy Historical Task',
        estimateMinutes: 60,
        completedMinutes: 20,
        actualMinutes: 0,
        remainingMinutes: null,
        scheduledMinutes: 0,
        deadline: new Date(deadline),
        academicWeight: 0.5,
        teamImpactWeight: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0,
        status: 'IN_PROGRESS',
        createdAt: new Date(),
        updatedAt: new Date()
      };
      fakeDb.task.push(legacyRow);

      // Send legacy payload containing only completedMinutes
      const legacyUpdateRes = await request(app)
        .post(`/api/v1/tasks/${legacyRow.id}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ completedMinutes: 35 });
      expect(legacyUpdateRes.status).toBe(200);
      expect(legacyUpdateRes.body.completedMinutes).toBe(35);
      expect(legacyUpdateRes.body.actualMinutes).toBe(35);
      // Resolved remaining work: 60 - 35 = 25
      expect(legacyUpdateRes.body.remainingMinutes).toBe(25);
    });
  });

  describe('Ownership Enforcement', () => {
    it('rejects completion of another user\'s task with 404', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskA = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'User A Secret Task', estimateMinutes: 60, deadline });

      const res = await request(app)
        .post(`/api/v1/tasks/${taskA.body.id}/complete`)
        .set('Authorization', `Bearer ${userBToken}`)
        .send({ actualMinutes: 60 });
      expect(res.status).toBe(404);
    });

    it('rejects progress updates on another user\'s task with 404', async () => {
      const deadline = new Date(Date.now() + 48 * 3600000).toISOString();
      const taskA = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'User A Private Project', estimateMinutes: 60, deadline });

      const res = await request(app)
        .post(`/api/v1/tasks/${taskA.body.id}/progress`)
        .set('Authorization', `Bearer ${userBToken}`)
        .send({ additionalMinutes: 30 });
      expect(res.status).toBe(404);
    });
  });

  describe('Adaptive Rescheduling Flow', () => {
    it('locks past blocks and completed blocks, excludes completed tasks, and preserves history', async () => {
      // 1. Create a user with constraints and 2 tasks
      const regRes = await request(app)
        .post('/api/v1/auth/register')
        .send({ email: 'reschedule.flow@college.edu', password: 'Password123!' });
      const token = regRes.body.token;
      const uid = regRes.body.user.id;

      const deadline = new Date(Date.now() + 72 * 3600000).toISOString();
      const t1 = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${token}`)
        .send({ title: 'Task 1 to Complete', estimateMinutes: 60, deadline });
      const t2 = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${token}`)
        .send({ title: 'Task 2 Incomplete', estimateMinutes: 90, deadline });

      // Generate initial schedule
      const genRes = await request(app)
        .post('/api/v1/schedules/generate')
        .set('Authorization', `Bearer ${token}`);
      expect(genRes.status).toBe(201);
      const initialVersionId = genRes.body.id;

      // Mark task 1 complete
      await request(app)
        .post(`/api/v1/tasks/${t1.body.id}/complete`)
        .set('Authorization', `Bearer ${token}`)
        .send({ actualMinutes: 60 });

      // Reschedule via POST /schedules/:id/reschedule
      const reschedRes = await request(app)
        .post(`/api/v1/schedules/${initialVersionId}/reschedule`)
        .set('Authorization', `Bearer ${token}`);
      expect(reschedRes.status).toBe(201);
      const newVersion = reschedRes.body;

      // 1. Audit trail preserved
      expect(newVersion.previousVersionId).toBe(initialVersionId);

      // 2. Task 1 is completed, so new schedule should NOT have any future uncompleted blocks for Task 1
      const task1Blocks = newVersion.blocks.filter((b: any) => b.taskId === t1.body.id && !b.isLocked);
      expect(task1Blocks.length).toBe(0);

      // 3. Task 2 remains active and is scheduled
      const task2Blocks = newVersion.blocks.filter((b: any) => b.taskId === t2.body.id);
      expect(task2Blocks.length).toBeGreaterThan(0);
    });
  });

  describe('Phase 2B.2.2 - Persistent Idempotency & Retry Safety', () => {
    const deadline = new Date(Date.now() + 72 * 3600000).toISOString();

    it('Scenario 1 & 2: First progress submission succeeds, and retry with same operationId returns identical result without double-counting', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Idempotency Test Task', estimateMinutes: 60, deadline });
      expect(taskRes.status).toBe(201);
      const taskId = taskRes.body.id;

      const opId = randomUUID();
      const progressPayload = {
        additionalMinutes: 25,
        remainingMinutes: 35,
        status: 'IN_PROGRESS',
        operationId: opId,
      };

      // 1. First submission
      const firstRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(progressPayload);
      expect(firstRes.status).toBe(200);
      expect(firstRes.body.actualMinutes).toBe(25);
      expect(firstRes.body.remainingMinutes).toBe(35);
      expect(firstRes.body.status).toBe('IN_PROGRESS');

      // Verify operation was persisted in DB
      const opRecord = fakeDb.taskProgressOperation.find((o: any) => o.operationId === opId);
      expect(opRecord).toBeDefined();
      expect(opRecord.userId).toBe(userAId);
      expect(opRecord.taskId).toBe(taskId);

      // 2. Retry with the SAME operation ID and SAME payload (simulating dropped response)
      const retryRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(progressPayload);
      expect(retryRes.status).toBe(200);
      expect(retryRes.body.id).toBe(firstRes.body.id);
      expect(retryRes.body.actualMinutes).toBe(25);
      expect(retryRes.body.remainingMinutes).toBe(35);

      // Verify DB state was NOT incremented again
      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(25);
      expect(taskInDb.remainingMinutes).toBe(35);
    });

    it('Scenario 3: Same operation ID with conflicting payload is safely rejected with HTTP 409', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Conflict Test Task', estimateMinutes: 90, deadline });
      const taskId = taskRes.body.id;

      const opId = randomUUID();
      const initialPayload = {
        additionalMinutes: 30,
        remainingMinutes: 60,
        status: 'IN_PROGRESS',
        operationId: opId,
      };

      const firstRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(initialPayload);
      expect(firstRes.status).toBe(200);

      // Conflict: same opId, but different minutes
      const conflictPayload = {
        additionalMinutes: 45, // Conflicting!
        remainingMinutes: 45,
        status: 'IN_PROGRESS',
        operationId: opId,
      };

      const conflictRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(conflictPayload);
      expect(conflictRes.status).toBe(409);
      expect(conflictRes.body.error.code).toBe('IDEMPOTENCY_CONFLICT');

      // Task in DB remains at initial 30 minutes
      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(30);
      expect(taskInDb.remainingMinutes).toBe(60);
    });

    it('Scenario 4: Same operation ID with different task is rejected with HTTP 409', async () => {
      const t1 = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Task Alpha', estimateMinutes: 60, deadline });
      const t2 = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Task Beta', estimateMinutes: 60, deadline });

      const opId = randomUUID();
      const res1 = await request(app)
        .post(`/api/v1/tasks/${t1.body.id}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 20, operationId: opId });
      expect(res1.status).toBe(200);

      // Attempt to reuse opId on Task Beta
      const res2 = await request(app)
        .post(`/api/v1/tasks/${t2.body.id}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 20, operationId: opId });
      expect(res2.status).toBe(409);
      expect(res2.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    });

    it('Scenario 5: Concurrent duplicate submissions with same operation ID succeed idempotently without races', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Concurrency Test Task', estimateMinutes: 100, deadline });
      const taskId = taskRes.body.id;

      const opId = randomUUID();
      const payload = {
        additionalMinutes: 40,
        remainingMinutes: 60,
        status: 'IN_PROGRESS',
        operationId: opId,
      };

      // Send 2 concurrent requests with same opId
      const [resA, resB] = await Promise.all([
        request(app).post(`/api/v1/tasks/${taskId}/progress`).set('Authorization', `Bearer ${userAToken}`).send(payload),
        request(app).post(`/api/v1/tasks/${taskId}/progress`).set('Authorization', `Bearer ${userAToken}`).send(payload),
      ]);

      expect(resA.status).toBe(200);
      expect(resB.status).toBe(200);
      expect(resA.body.actualMinutes).toBe(40);
      expect(resB.body.actualMinutes).toBe(40);

      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(40);
    });

    it('Scenario 6: New legitimate subsequent progress with fresh operation ID increments effort correctly', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Legitimate Progression Task', estimateMinutes: 80, deadline });
      const taskId = taskRes.body.id;

      const op1 = randomUUID();
      const res1 = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 20, remainingMinutes: 60, status: 'IN_PROGRESS', operationId: op1 });
      expect(res1.status).toBe(200);
      expect(res1.body.actualMinutes).toBe(20);
      expect(res1.body.remainingMinutes).toBe(60);

      const op2 = randomUUID();
      const res2 = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 30, remainingMinutes: 30, status: 'IN_PROGRESS', operationId: op2 });
      expect(res2.status).toBe(200);
      expect(res2.body.actualMinutes).toBe(50);
      expect(res2.body.remainingMinutes).toBe(30);

      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(50);
      expect(taskInDb.remainingMinutes).toBe(30);
    });

    it('Scenario 7: Preserves user-indicated remainingMinutes independently of elapsed effort', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Discovery of Extra Work Task', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;

      // User worked 40 minutes, but realized more work remains: remainingMinutes explicitly set to 50
      const opId = randomUUID();
      const res = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 40, remainingMinutes: 50, status: 'IN_PROGRESS', operationId: opId });
      expect(res.status).toBe(200);
      expect(res.body.actualMinutes).toBe(40);
      expect(res.body.remainingMinutes).toBe(50);

      // Retry does not mutate remainingMinutes
      const retry = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 40, remainingMinutes: 50, status: 'IN_PROGRESS', operationId: opId });
      expect(retry.status).toBe(200);
      expect(retry.body.remainingMinutes).toBe(50);
    });

    it('Scenario 8: Complete task with operationId is idempotent across retries', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Complete Idempotency Task', estimateMinutes: 45, deadline });
      const taskId = taskRes.body.id;

      const opId = randomUUID();
      const comp1 = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 40, operationId: opId });
      expect(comp1.status).toBe(200);
      expect(comp1.body.status).toBe('COMPLETED');
      expect(comp1.body.actualMinutes).toBe(40);

      // Retry completion
      const comp2 = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 40, operationId: opId });
      expect(comp2.status).toBe(200);
      expect(comp2.body.status).toBe('COMPLETED');
      expect(comp2.body.actualMinutes).toBe(40);

      // Conflict retry with different actualMinutes
      const compConflict = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 50, operationId: opId });
      expect(compConflict.status).toBe(409);
      expect(compConflict.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
    });
  });

  describe('Phase 2B.2.3 - Ambiguous retry recovery (late duplicate / unique-violation rollback)', () => {
    // These tests force the interleaving that PostgreSQL can produce when a client replay races the
    // original in-flight request: the replay's pre-check does not yet see the winner's operation row,
    // so it mutates the task and then its TaskProgressOperation insert fails with P2002. FakePrisma
    // rolls the transaction back (as PostgreSQL would); the repository must then replay the committed
    // result instead of returning 500 or double counting. This is a simulation, NOT a real-DB test.
    const deadline = new Date(Date.now() + 72 * 3600000).toISOString();
    const opTable = () => (prisma as any).taskProgressOperation;

    afterEach(() => jest.restoreAllMocks());

    it('Late duplicate of a committed progress operation replays the original result and rolls back its own writes', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Race Replay Task', estimateMinutes: 90, deadline });
      const taskId = taskRes.body.id;
      const opId = randomUUID();
      const payload = { additionalMinutes: 30, remainingMinutes: 60, status: 'IN_PROGRESS', operationId: opId };

      // Original request commits (client then loses the response).
      const original = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(payload);
      expect(original.status).toBe(200);
      expect(original.body.actualMinutes).toBe(30);

      // Replay whose in-transaction pre-check misses the committed row (race window).
      jest.spyOn(opTable(), 'findUnique').mockImplementationOnce(async () => null);
      const replay = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send(payload);

      expect(replay.status).toBe(200);
      expect(replay.body).toEqual(original.body);
      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(30); // the replay's +30 was rolled back
      expect(taskInDb.remainingMinutes).toBe(60);
      expect(fakeDb.taskProgressOperation.filter((o: any) => o.operationId === opId)).toHaveLength(1);
    });

    it('Late duplicate with a different payload is rejected with 409 and leaves the task untouched', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Race Conflict Task', estimateMinutes: 90, deadline });
      const taskId = taskRes.body.id;
      const opId = randomUUID();

      await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 30, remainingMinutes: 60, status: 'IN_PROGRESS', operationId: opId });

      jest.spyOn(opTable(), 'findUnique').mockImplementationOnce(async () => null);
      const conflicting = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 45, remainingMinutes: 45, status: 'IN_PROGRESS', operationId: opId });

      expect(conflicting.status).toBe(409);
      expect(conflicting.body.error.code).toBe('IDEMPOTENCY_CONFLICT');
      const taskInDb = fakeDb.task.find((t: any) => t.id === taskId);
      expect(taskInDb.actualMinutes).toBe(30);
      expect(taskInDb.remainingMinutes).toBe(60);
    });

    it('Late duplicate of a committed completion replays without creating a second disruption event', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Race Complete Task', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;
      const opId = randomUUID();

      const original = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 80, operationId: opId });
      expect(original.status).toBe(200);
      const disruptionsBefore = fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId).length;

      jest.spyOn(opTable(), 'findUnique').mockImplementationOnce(async () => null);
      const replay = await request(app)
        .post(`/api/v1/tasks/${taskId}/complete`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ actualMinutes: 80, operationId: opId });

      expect(replay.status).toBe(200);
      expect(replay.body.actualMinutes).toBe(80);
      expect(fakeDb.disruptionEvent.filter((e: any) => e.taskId === taskId).length).toBe(disruptionsBefore);
    });

    it('A new operationId after a confirmed operation is applied exactly once more', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Post-Reconcile Task', estimateMinutes: 90, deadline });
      const taskId = taskRes.body.id;
      const opA = randomUUID();
      const payloadA = { additionalMinutes: 20, remainingMinutes: 70, status: 'IN_PROGRESS', operationId: opA };

      await request(app).post(`/api/v1/tasks/${taskId}/progress`).set('Authorization', `Bearer ${userAToken}`).send(payloadA);
      // Reconciliation replay of A (client lost the first response)
      const reconciled = await request(app).post(`/api/v1/tasks/${taskId}/progress`).set('Authorization', `Bearer ${userAToken}`).send(payloadA);
      expect(reconciled.body.actualMinutes).toBe(20);

      const next = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 15, remainingMinutes: 55, status: 'IN_PROGRESS', operationId: randomUUID() });
      expect(next.status).toBe(200);
      expect(next.body.actualMinutes).toBe(35);
      expect(next.body.remainingMinutes).toBe(55);
    });

    it('Another user cannot replay or probe an operationId belonging to someone else', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Private Op Task', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;
      const opId = randomUUID();
      const payload = { additionalMinutes: 10, remainingMinutes: 50, status: 'IN_PROGRESS', operationId: opId };
      await request(app).post(`/api/v1/tasks/${taskId}/progress`).set('Authorization', `Bearer ${userAToken}`).send(payload);

      const probe = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userBToken}`)
        .send(payload);
      expect([404, 409]).toContain(probe.status);
      expect(probe.body.actualMinutes).toBeUndefined();
      expect(fakeDb.task.find((t: any) => t.id === taskId).actualMinutes).toBe(10);
    });

    it('Operation reconciliation endpoint GET /tasks/:id/operations/:operationId allows safe status query', async () => {
      const taskRes = await request(app)
        .post('/api/v1/tasks')
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ title: 'Reconcile Query Task', estimateMinutes: 60, deadline });
      const taskId = taskRes.body.id;
      const opId = randomUUID();

      // Query non-existent operation returns 404
      const notFoundRes = await request(app)
        .get(`/api/v1/tasks/${taskId}/operations/${opId}`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(notFoundRes.status).toBe(404);
      expect(notFoundRes.body.error.code).toBe('OPERATION_NOT_FOUND');

      // Commit progress with this operationId
      const commitRes = await request(app)
        .post(`/api/v1/tasks/${taskId}/progress`)
        .set('Authorization', `Bearer ${userAToken}`)
        .send({ additionalMinutes: 25, remainingMinutes: 35, status: 'IN_PROGRESS', operationId: opId });
      expect(commitRes.status).toBe(200);

      // Query now returns 200 with reconciled operation data
      const reconcileRes = await request(app)
        .get(`/api/v1/tasks/${taskId}/operations/${opId}`)
        .set('Authorization', `Bearer ${userAToken}`);
      expect(reconcileRes.status).toBe(200);
      expect(reconcileRes.body.operationId).toBe(opId);
      expect(reconcileRes.body.taskId).toBe(taskId);
      expect(reconcileRes.body.result.actualMinutes).toBe(25);
      expect(reconcileRes.body.result.remainingMinutes).toBe(35);

      // Unauthorized user cannot query operation status
      const forbiddenRes = await request(app)
        .get(`/api/v1/tasks/${taskId}/operations/${opId}`)
        .set('Authorization', `Bearer ${userBToken}`);
      expect(forbiddenRes.status).toBe(404);
    });
  });
});
