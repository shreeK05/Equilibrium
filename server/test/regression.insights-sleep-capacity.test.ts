/**
 * REGRESSION & CORRECTNESS: Workload Insights Sleep-Duration Capacity (Phase 2B.1.3)
 *
 * Verifies that:
 * 1. Actual daily sleep duration is calculated from [sleepStart, sleepEnd] with correct overnight logic.
 * 2. 22:00–07:00 produces 9 hours of sleep (540m) even when minSleepHours is 7.0 (420m).
 * 3. 23:00–07:00 produces 8 hours of sleep (480m).
 * 4. Daytime sleep windows (e.g. 08:00–17:00) produce correct durations.
 * 5. Safe daily capacity responds to actual sleep duration, not the minimum floor.
 * 6. Missing constraints, invalid times, and equal start/end times fall back safely according
 *    to the existing API contract.
 * 7. End-to-end GET /api/v1/insights route returns accurate capacity, utilization, and risk levels.
 */

import request from 'supertest';

jest.mock('../src/db', () => {
  const { createFakePrisma } = require('./helpers/fake-prisma');
  return { prisma: createFakePrisma() };
});

import { prisma } from '../src/db';
import { app } from '../src/app';
import {
  parseTimeToMinutes,
  calculateSleepDurationMinutes,
  computeSafeDailyMinutes,
} from '../src/utils/workload.helper';

const fakeDb = (prisma as any).__db;

describe('Phase 2B.1.3 - Unit Tests: Workload Helper & Sleep Duration Math', () => {
  describe('parseTimeToMinutes', () => {
    it('parses valid 24-hour time strings correctly', () => {
      expect(parseTimeToMinutes('00:00')).toBe(0);
      expect(parseTimeToMinutes('07:00')).toBe(420);
      expect(parseTimeToMinutes('07:30')).toBe(450);
      expect(parseTimeToMinutes('22:00')).toBe(1320);
      expect(parseTimeToMinutes('23:00')).toBe(1380);
      expect(parseTimeToMinutes('23:59')).toBe(1439);
    });

    it('rejects invalid or malformed times', () => {
      expect(parseTimeToMinutes('24:00')).toBeNull();
      expect(parseTimeToMinutes('12:60')).toBeNull();
      expect(parseTimeToMinutes('invalid')).toBeNull();
      expect(parseTimeToMinutes('')).toBeNull();
      expect(parseTimeToMinutes(null)).toBeNull();
      expect(parseTimeToMinutes(undefined)).toBeNull();
    });
  });

  describe('calculateSleepDurationMinutes', () => {
    it('calculates 9 hours (540m) for overnight 22:00 -> 07:00', () => {
      const minutes = calculateSleepDurationMinutes('22:00', '07:00');
      expect(minutes).toBe(540);
    });

    it('calculates 8 hours (480m) for overnight 23:00 -> 07:00', () => {
      const minutes = calculateSleepDurationMinutes('23:00', '07:00');
      expect(minutes).toBe(480);
    });

    it('calculates 7 hours (420m) for overnight 23:00 -> 06:00', () => {
      const minutes = calculateSleepDurationMinutes('23:00', '06:00');
      expect(minutes).toBe(420);
    });

    it('calculates daytime sleep window durations correctly', () => {
      // 08:00 to 17:00 = 9 hours (540m)
      expect(calculateSleepDurationMinutes('08:00', '17:00')).toBe(540);
      // 01:00 to 09:00 = 8 hours (480m)
      expect(calculateSleepDurationMinutes('01:00', '09:00')).toBe(480);
      // 13:00 to 21:00 = 8 hours (480m)
      expect(calculateSleepDurationMinutes('13:00', '21:00')).toBe(480);
    });

    it('returns null for equal start and end times (degenerate zero/24h interval)', () => {
      expect(calculateSleepDurationMinutes('07:00', '07:00')).toBeNull();
      expect(calculateSleepDurationMinutes('23:00', '23:00')).toBeNull();
    });

    it('returns null for intervals strictly exceeding 16 hours', () => {
      // 08:00 to 07:00 wraps to 23 hours (1380m) -> invalid per schema
      expect(calculateSleepDurationMinutes('08:00', '07:00')).toBeNull();
    });

    it('returns null for missing or invalid parameters', () => {
      expect(calculateSleepDurationMinutes(null, '07:00')).toBeNull();
      expect(calculateSleepDurationMinutes('23:00', null)).toBeNull();
      expect(calculateSleepDurationMinutes('bad', '07:00')).toBeNull();
      expect(calculateSleepDurationMinutes('23:00', 'bad')).toBeNull();
    });
  });

  describe('computeSafeDailyMinutes', () => {
    it('uses actual sleep duration (9h = 540m) instead of minSleepHours floor (7.0h = 420m)', () => {
      const constraints = {
        sleepStart: '22:00',
        sleepEnd: '07:00',
        minSleepHours: 7.0, // Minimum floor is 7h, but actual window is 9h
        bufferMinutes: 30,
      };
      // 1440 - 540 (actual sleep) - 30 (buffer) = 870
      // Previous buggy code used minSleepHours: 1440 - 420 - 30 = 990 (overestimated by 120m)
      expect(computeSafeDailyMinutes(constraints)).toBe(870);
    });

    it('uses actual sleep duration (8h = 480m) for 23:00 -> 07:00', () => {
      const constraints = {
        sleepStart: '23:00',
        sleepEnd: '07:00',
        minSleepHours: 7.0,
        bufferMinutes: 30,
      };
      // 1440 - 480 - 30 = 930
      expect(computeSafeDailyMinutes(constraints)).toBe(930);
    });

    it('varies safe capacity dynamically as actual sleep duration changes', () => {
      const base = { minSleepHours: 7.0, bufferMinutes: 30 };

      const cap7h = computeSafeDailyMinutes({ ...base, sleepStart: '23:00', sleepEnd: '06:00' });
      const cap8h = computeSafeDailyMinutes({ ...base, sleepStart: '23:00', sleepEnd: '07:00' });
      const cap9h = computeSafeDailyMinutes({ ...base, sleepStart: '22:00', sleepEnd: '07:00' });
      const cap10h = computeSafeDailyMinutes({ ...base, sleepStart: '21:00', sleepEnd: '07:00' });

      expect(cap7h).toBe(990); // 1440 - 420 - 30
      expect(cap8h).toBe(930); // 1440 - 480 - 30
      expect(cap9h).toBe(870); // 1440 - 540 - 30
      expect(cap10h).toBe(810); // 1440 - 600 - 30
    });

    it('handles missing constraints with contract fallback (420m sleep, 30m buffer)', () => {
      expect(computeSafeDailyMinutes(null)).toBe(990);
      expect(computeSafeDailyMinutes(undefined)).toBe(990);
    });

    it('handles equal start and end times by falling back to minSleepHours contract', () => {
      const constraints7 = {
        sleepStart: '07:00',
        sleepEnd: '07:00',
        minSleepHours: 7.0,
        bufferMinutes: 30,
      };
      // Fallback: 1440 - (7.0 * 60) - 30 = 990
      expect(computeSafeDailyMinutes(constraints7)).toBe(990);

      const constraints8 = {
        sleepStart: '07:00',
        sleepEnd: '07:00',
        minSleepHours: 8.0,
        bufferMinutes: 30,
      };
      // Fallback: 1440 - (8.0 * 60) - 30 = 930
      expect(computeSafeDailyMinutes(constraints8)).toBe(930);
    });

    it('handles malformed time strings by falling back to minSleepHours contract', () => {
      const malformed = {
        sleepStart: 'bad:time',
        sleepEnd: '07:00',
        minSleepHours: 7.0,
        bufferMinutes: 30,
      };
      expect(computeSafeDailyMinutes(malformed)).toBe(990);
    });

    it('handles custom bufferMinutes accurately', () => {
      const with15mBuffer = {
        sleepStart: '23:00',
        sleepEnd: '07:00', // 480 min
        minSleepHours: 7.0,
        bufferMinutes: 15,
      };
      // 1440 - 480 - 15 = 945
      expect(computeSafeDailyMinutes(with15mBuffer)).toBe(945);
    });
  });
});

describe('Phase 2B.1.3 - HTTP Integration: GET /api/v1/insights', () => {
  let authToken: string;
  let userId: string;

  beforeAll(async () => {
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'insights.student@college.edu', password: 'Password123!' });

    expect(regRes.status).toBe(200);
    authToken = regRes.body.token;
    userId = regRes.body.user.id;
  });

  it('calculates safeDailyMinutes from 8-hour sleep window (23:00 -> 07:00) with 15m buffer', async () => {
    // Update constraints to 23:00–07:00, minSleepHours: 7.0, bufferMinutes: 15
    const constraintRow = fakeDb.userConstraint.find((c: any) => c.userId === userId);
    Object.assign(constraintRow, {
      sleepStart: '23:00',
      sleepEnd: '07:00',
      minSleepHours: 7.0,
      bufferMinutes: 15,
    });

    const res = await request(app)
      .get('/api/v1/insights')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    // 1440 - 480 (8h sleep) - 15 (buffer) = 945
    expect(res.body.safeDailyMinutes).toBe(945);
    expect(res.body.scheduledMinutes).toBe(0);
    expect(res.body.utilization).toBe(0);
    expect(res.body.riskLevel).toBe('LOW');
  });

  it('adjusts safeDailyMinutes when user expands sleep to 9 hours (22:00 -> 07:00)', async () => {
    // User extends sleep by 1 hour (22:00 to 07:00 = 9h = 540m)
    const constraintRow = fakeDb.userConstraint.find((c: any) => c.userId === userId);
    Object.assign(constraintRow, {
      sleepStart: '22:00',
      sleepEnd: '07:00',
      minSleepHours: 7.0, // Floor unchanged
      bufferMinutes: 15,
    });

    const res = await request(app)
      .get('/api/v1/insights')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    // 1440 - 540 (9h sleep) - 15 (buffer) = 885
    expect(res.body.safeDailyMinutes).toBe(885);
  });

  it('correctly calculates utilization and burnout risk with scheduled tasks under actual capacity', async () => {
    // safeDailyMinutes = 885, safeTotalMinutes = 885 * 7 = 6195
    // Add a schedule version with scheduled task blocks totaling 5000 minutes (> 80% of 6195 = 4956m -> MEDIUM risk)
    const versionId = 'v-insights-test-1';
    fakeDb.scheduleVersion.push({
      id: versionId,
      userId,
      triggerType: 'MANUAL',
      generatedAt: new Date(),
      createdAt: new Date(),
    });
    fakeDb.scheduleBlock.push({
      id: 'b1',
      versionId,
      blockType: 'TASK',
      startTime: new Date('2026-10-25T04:00:00Z'),
      endTime: new Date('2026-10-25T09:00:00Z'),
      durationMinutes: 5000,
      createdAt: new Date(),
    });

    const res = await request(app)
      .get('/api/v1/insights')
      .set('Authorization', `Bearer ${authToken}`);

    expect(res.status).toBe(200);
    expect(res.body.safeDailyMinutes).toBe(885);
    expect(res.body.scheduledMinutes).toBe(5000);

    const safeTotalMinutes = 885 * 7; // 6195
    const expectedUtil = 5000 / safeTotalMinutes;
    expect(res.body.utilization).toBeCloseTo(expectedUtil, 4);
    // 5000 > 6195 * 0.8 (4956) -> MEDIUM risk
    expect(res.body.riskLevel).toBe('MEDIUM');
  });

  it('falls back to default safeDailyMinutes (990) when constraint row is absent', async () => {
    // Create new user without constraint row in fakeDb
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'no.constraints@college.edu', password: 'Password123!' });

    const newUserId = regRes.body.user.id;
    const newToken = regRes.body.token;

    // Delete constraint row from fakeDb
    const idx = fakeDb.userConstraint.findIndex((c: any) => c.userId === newUserId);
    if (idx !== -1) fakeDb.userConstraint.splice(idx, 1);

    const res = await request(app)
      .get('/api/v1/insights')
      .set('Authorization', `Bearer ${newToken}`);

    expect(res.status).toBe(200);
    // Missing constraints fallback: 1440 - 420 - 30 = 990
    expect(res.body.safeDailyMinutes).toBe(990);
  });

  it('falls back to minSleepHours contract when constraint row contains equal start/end times', async () => {
    const regRes = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: 'equal.times@college.edu', password: 'Password123!' });

    const newUserId = regRes.body.user.id;
    const newToken = regRes.body.token;

    const constraintRow = fakeDb.userConstraint.find((c: any) => c.userId === newUserId);
    Object.assign(constraintRow, {
      sleepStart: '07:00',
      sleepEnd: '07:00',
      minSleepHours: 7.0,
      bufferMinutes: 30,
    });

    const res = await request(app)
      .get('/api/v1/insights')
      .set('Authorization', `Bearer ${newToken}`);

    expect(res.status).toBe(200);
    // Equal times fallback: 1440 - 420 - 30 = 990
    expect(res.body.safeDailyMinutes).toBe(990);
  });
});
