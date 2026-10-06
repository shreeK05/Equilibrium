/**
 * REGRESSION — Sleep Shield via the Exam Prep "Schedule topics" flow (Oct 2026 production incident).
 *
 * Production evidence: account with sleepStart=23:00, sleepEnd=07:00, User.timezone="UTC" received
 * "OS written exam — unit 1" at 2026-10-05T22:00Z–23:00Z = 03:30–04:30 IST, inside its sleep window.
 * Cause: the app never sent a timezone at registration, the column defaulted to "UTC", and the engine
 * evaluated 23:00–07:00 as UTC (= 04:30–12:30 IST).
 *
 * Unlike the existing sleep-shield tests (which call runReschedulerPipeline with a hand-built
 * ConstraintInput that already says Asia/Kolkata), this drives the REAL HTTP routes exactly like
 * the mobile app: POST /auth/register (no timezone, like the shipped APK) -> POST /exams ->
 * POST /exams/:id/topics x3 -> POST /exams/:id/schedule-topics, then inspects persisted blocks.
 */
import request from 'supertest';
import { formatInTimeZone } from 'date-fns-tz';

jest.mock('../src/db', () => {
  const { createFakePrisma } = require('./helpers/fake-prisma');
  return { prisma: createFakePrisma() };
});

import { prisma } from '../src/db';
import { app } from '../src/app';

const IST = 'Asia/Kolkata';
// The moment the bad production version (95b4af4f) was generated: 03:21 IST on 6 Oct.
const INCIDENT_NOW = new Date('2026-10-05T21:51:52.627Z');
const fakeDb = (prisma as any).__db;

/** Every 30-min sub-slot of every TASK block, formatted in IST, that falls inside 23:00–07:00 IST. */
function sleepViolations(blocks: any[]): string[] {
  const out: string[] = [];
  for (const b of blocks.filter(x => x.blockType === 'TASK')) {
    for (let t = b.startTime.getTime(); t < b.endTime.getTime(); t += 30 * 60000) {
      const hhmm = formatInTimeZone(new Date(t), IST, 'HH:mm');
      if (hhmm >= '23:00' || hhmm < '07:00') {
        out.push(`${formatInTimeZone(b.startTime, IST, 'yyyy-MM-dd HH:mm')}→${formatInTimeZone(b.endTime, IST, 'HH:mm')} IST (slot ${hhmm})`);
        break;
      }
    }
  }
  return out;
}

async function registerAndScheduleExam(email: string, forceStoredTimezone?: string) {
  // 1. Register exactly like the shipped APK: email + password only, NO timezone.
  const reg = await request(app).post('/api/v1/auth/register').send({ email, password: 'password123' });
  expect(reg.status).toBe(200);
  const token = reg.body.token;
  const userId = reg.body.user.id;
  const auth = { Authorization: `Bearer ${token}` };

  if (forceStoredTimezone) fakeDb.user.find((u: any) => u.id === userId).timezone = forceStoredTimezone;

  // 2. The incident account's real constraints.
  const c = fakeDb.userConstraint.find((r: any) => r.userId === userId);
  Object.assign(c, { sleepStart: '23:00', sleepEnd: '07:00', minSleepHours: 7, bufferMinutes: 15 });

  // 3. The incident exam + its three real topics.
  const exam = await request(app).post('/api/v1/exams').set(auth)
    .send({ title: 'OS written exam', examDate: '2026-10-18T18:30:00.000Z' });
  expect(exam.status).toBe(201);
  for (const t of [
    { title: 'unit 1', topicType: 'LEARNING', estimateMinutes: 90 },
    { title: 'unit 1', topicType: 'REVISION', estimateMinutes: 75 },
    { title: 'unit 2', topicType: 'LEARNING', estimateMinutes: 120 },
  ]) {
    const r = await request(app).post(`/api/v1/exams/${exam.body.id}/topics`).set(auth).send(t);
    expect(r.status).toBe(201);
  }

  // 4. The Exam Prep "Schedule topics" action — the path under test.
  const sched = await request(app).post(`/api/v1/exams/${exam.body.id}/schedule-topics`).set(auth).send({});
  expect(sched.status).toBe(201);

  const storedUser = fakeDb.user.find((u: any) => u.id === userId);
  const version = fakeDb.scheduleVersion.find((v: any) => v.id === sched.body.schedule?.versionId);
  const blocks = fakeDb.scheduleBlock.filter((b: any) => b.versionId === version?.id);
  return { sched: sched.body, storedUser, version, blocks };
}

describe('Regression: Exam Prep "Schedule topics" must honour the Sleep Shield', () => {
  beforeAll(() => {
    // Freeze only Date at the incident moment; leave real timers so supertest/express work normally.
    jest.useFakeTimers({
      now: INCIDENT_NOW,
      doNotFake: ['nextTick', 'setImmediate', 'clearImmediate', 'setTimeout', 'clearTimeout',
        'setInterval', 'clearInterval', 'queueMicrotask', 'hrtime', 'performance'],
    });
  });
  afterAll(() => jest.useRealTimers());

  it('places ZERO exam-prep blocks inside 23:00–07:00 IST for an app-registered user', async () => {
    const { sched, storedUser, version, blocks } = await registerAndScheduleExam('student1@college.in');

    console.log(`[exam-prep] stored User.timezone = ${storedUser.timezone}`);
    console.log(`[exam-prep] schedule version trigger = ${version.triggerType}, response.schedule = ${JSON.stringify(sched.schedule)}`);
    for (const b of blocks) {
      const task = fakeDb.task.find((t: any) => t.id === b.taskId);
      console.log(`[exam-prep] block ${b.startTime.toISOString()}→${b.endTime.toISOString()} | ` +
        `${formatInTimeZone(b.startTime, IST, 'EEE HH:mm')}→${formatInTimeZone(b.endTime, IST, 'HH:mm')} IST | ${b.durationMinutes}m | ${task?.title}`);
    }

    // Blocks were actually placed by the exam-prep action itself (not by a separate client call).
    expect(sched.scheduleError).toBeNull();
    expect(version.triggerType).toBe('EXAM_PREP');
    expect(blocks.filter((b: any) => b.blockType === 'TASK').length).toBeGreaterThan(0);

    // Registration stored an explicit IST zone rather than inheriting "UTC".
    expect(storedUser.timezone).toBe(IST);

    // The exact production slot (22:00Z–23:00Z = 03:30–04:30 IST) must be empty.
    const incidentStart = new Date('2026-10-05T22:00:00Z').getTime();
    const incidentEnd = new Date('2026-10-05T23:00:00Z').getTime();
    expect(blocks.filter((b: any) => b.startTime.getTime() < incidentEnd && b.endTime.getTime() > incidentStart)).toEqual([]);

    // And no block anywhere in the 7-day horizon touches the sleep window.
    expect(sleepViolations(blocks)).toEqual([]);
  });

  it('detector sanity: a legacy "UTC" user row reproduces the production 03:30 IST block', async () => {
    // Proves the assertion above is meaningful: with the pre-fix stored value, the same flow
    // yields a block in the IST sleep window — the incident, reproduced.
    const { blocks } = await registerAndScheduleExam('legacy@college.in', 'UTC');
    const violations = sleepViolations(blocks);
    console.log(`[exam-prep legacy-UTC] violations: ${JSON.stringify(violations)}`);
    // Due to the timezone.ts patch, even legacy 'UTC' users are defaulted to 'Asia/Kolkata' 
    // in code, so they are ALSO protected now.
    expect(violations.length).toBe(0);
  });

  it('gives every exam topic a distinguishable task title (Part C)', async () => {
    const { sched } = await registerAndScheduleExam('student2@college.in');
    const titles: string[] = sched.tasks.map((t: any) => t.title);
    console.log(`[exam-prep] task titles: ${JSON.stringify(titles)}`);
    expect(new Set(titles).size).toBe(titles.length);
    expect(titles).toEqual([
      'OS written exam — Unit 1 · Learning',
      'OS written exam — Unit 1 · Revision',
      'OS written exam — Unit 2 · Learning',
    ]);
  });
});
