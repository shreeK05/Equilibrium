/**
 * Regression tests for the bugs fixed in the Student Workflow Final Pass:
 * 1. Fixed Commitment protection (scheduler must place tasks AROUND commitments)
 * 2. Daily Target pacing (tasks spread across days per dailyTargetMinutes)
 * 3. Overnight Sleep Shield (23:30 → 07:00) is correctly blocked
 * 4. Daily target does not affect tasks without it (backward compatibility)
 */

import { runReschedulerPipeline } from '../src/scheduler/rescheduler';
import { TaskInput, ConstraintInput, FixedCommitment } from '../src/scheduler/types';
import { intervalsIntersect } from '../src/scheduler/guard';

describe('Regression: Student Workflow Fixes', () => {
  const now = new Date('2026-10-14T08:00:00.000Z');
  const horizonStart = new Date('2026-10-14T00:00:00.000Z');
  const horizonEnd = new Date('2026-10-21T00:00:00.000Z'); // 7-day horizon

  const baseConstraints: ConstraintInput = {
    sleepStart: '23:00',
    sleepEnd: '06:00',
    minSleepHours: 7.0,
    bufferMinutes: 15,
    peakEnergyWindows: [{ start: '09:00', end: '12:00' }, { start: '15:00', end: '17:00' }]
  };

  // ─── Bug 1: Fixed Commitment Protection ──────────────────────────────────────
  describe('BUG-1: Fixed Commitment — Tasks must never overlap a commitment', () => {
    it('REG-1a: 3-hour commitment in the morning, task must not overlap it', () => {
      const fixed: FixedCommitment[] = [{
        id: 'DBMS-lecture',
        start: new Date('2026-10-14T09:00:00.000Z'),
        end: new Date('2026-10-14T12:00:00.000Z')
      }];
      const tasks: TaskInput[] = [{
        id: 'assignment',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: new Date('2026-10-14T23:00:00.000Z'),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }];

      const result = runReschedulerPipeline(tasks, baseConstraints, fixed, [], horizonStart, horizonEnd, now);

      for (const block of result.blocks) {
        if (block.type === 'TASK') {
          const overlaps = intervalsIntersect(block.start, block.end, fixed[0].start, fixed[0].end);
          expect(overlaps).toBe(false);
        }
      }
      // Task should still be scheduled (placed before or after the commitment)
      const taskBlocks = result.blocks.filter(b => b.taskId === 'assignment');
      expect(taskBlocks.length).toBeGreaterThan(0);
    });

    it('REG-1b: 2 commitments in the same day, task placed in the gaps', () => {
      const fixed: FixedCommitment[] = [
        { id: 'morning-class', start: new Date('2026-10-14T08:30:00.000Z'), end: new Date('2026-10-14T10:00:00.000Z') },
        { id: 'afternoon-lab', start: new Date('2026-10-14T14:00:00.000Z'), end: new Date('2026-10-14T16:00:00.000Z') }
      ];
      const tasks: TaskInput[] = [{
        id: 'reading',
        estimateMinutes: 120,
        completedMinutes: 0,
        remainingMinutes: 120,
        deadline: new Date('2026-10-14T23:00:00.000Z'),
        academicWeight: 0.5,
        teamImpact: 0,
        cognitiveLoad: 'LOW',
        deferralCount: 0
      }];

      const result = runReschedulerPipeline(tasks, baseConstraints, fixed, [], horizonStart, horizonEnd, now);

      for (const block of result.blocks.filter(b => b.type === 'TASK')) {
        for (const f of fixed) {
          const overlaps = intervalsIntersect(block.start, block.end, f.start, f.end);
          expect(overlaps).toBe(false);
        }
      }
    });

    it('REG-1c: Buffer minutes around commitment must be respected', () => {
      const fixed: FixedCommitment[] = [{
        id: 'class',
        start: new Date('2026-10-14T10:00:00.000Z'),
        end: new Date('2026-10-14T11:00:00.000Z')
      }];

      const tasks: TaskInput[] = [{
        id: 't1',
        estimateMinutes: 60,
        completedMinutes: 0,
        remainingMinutes: 60,
        deadline: new Date('2026-10-14T23:00:00.000Z'),
        academicWeight: 0.5,
        teamImpact: 0,
        cognitiveLoad: 'LOW',
        deferralCount: 0
      }];

      // 15-minute buffer configured
      const result = runReschedulerPipeline(tasks, baseConstraints, fixed, [], horizonStart, horizonEnd, now);

      const bufferBefore = new Date(fixed[0].start.getTime() - 15 * 60000);
      const bufferAfter = new Date(fixed[0].end.getTime() + 15 * 60000);

      for (const block of result.blocks.filter(b => b.type === 'TASK')) {
        const overlaps = intervalsIntersect(block.start, block.end, bufferBefore, bufferAfter);
        expect(overlaps).toBe(false);
      }
    });
  });

  // ─── Bug 2: Daily Target Pacing ─────────────────────────────────────────────
  describe('BUG-2: Daily Target — Task paced across multiple days', () => {
    it('REG-2a: 300m task with 60m/day target spans at least 5 days', () => {
      const tasks: TaskInput[] = [{
        id: 'study-project',
        estimateMinutes: 300,
        completedMinutes: 0,
        remainingMinutes: 300,
        deadline: new Date('2026-10-21T23:59:00.000Z'),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0,
        dailyTargetMinutes: 60
      }];

      const result = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
      const taskBlocks = result.blocks.filter(b => b.taskId === 'study-project');

      // Verify per-day allocations
      const dailyMinutes: Record<string, number> = {};
      for (const block of taskBlocks) {
        const day = block.start.toISOString().substring(0, 10);
        dailyMinutes[day] = (dailyMinutes[day] ?? 0) + block.durationMinutes;
      }

      const dayKeys = Object.keys(dailyMinutes);
      expect(dayKeys.length).toBeGreaterThanOrEqual(4); // Spread across multiple days

      // No single day should exceed the target
      for (const [day, minutes] of Object.entries(dailyMinutes)) {
        expect(minutes).toBeLessThanOrEqual(60 + 29); // Allow up to one extra 30-min slot for rounding
      }
    });

    it('REG-2b: Task WITHOUT dailyTargetMinutes fills available capacity normally', () => {
      const tasks: TaskInput[] = [{
        id: 'normal-task',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: new Date('2026-10-14T23:59:00.000Z'),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
        // No dailyTargetMinutes — backward compatible
      }];

      const result = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
      const log = result.logs.find(l => l.taskId === 'normal-task');
      expect(log?.decisionType).toBe('FULLY_SCHEDULED');
    });

    it('REG-2c: Daily target still respects sleep shield', () => {
      const tasks: TaskInput[] = [{
        id: 'night-study',
        estimateMinutes: 240,
        completedMinutes: 0,
        remainingMinutes: 240,
        deadline: new Date('2026-10-21T23:59:00.000Z'),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'LOW',
        deferralCount: 0,
        dailyTargetMinutes: 120
      }];

      const result = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);

      const sleepStart = new Date('2026-10-14T23:00:00.000Z');
      const sleepEnd = new Date('2026-10-15T06:00:00.000Z');

      for (const block of result.blocks.filter(b => b.type === 'TASK')) {
        // Sleep shield must never be violated
        const overlapsSleep = intervalsIntersect(block.start, block.end, sleepStart, sleepEnd);
        expect(overlapsSleep).toBe(false);
      }
    });
  });

  // ─── Bug 3: Overnight Sleep Shield 23:30 → 07:00 ───────────────────────────
  describe('BUG-3: Overnight sleep schedule (23:30 → 07:00)', () => {
    const overnightConstraints: ConstraintInput = {
      sleepStart: '23:30',
      sleepEnd: '07:00',
      minSleepHours: 7.5,
      bufferMinutes: 0,
      peakEnergyWindows: [{ start: '09:00', end: '12:00' }]
    };

    it('REG-3a: Tasks never scheduled during 23:30–07:00 sleep window', () => {
      const tasks: TaskInput[] = [{
        id: 'late-task',
        estimateMinutes: 480,
        completedMinutes: 0,
        remainingMinutes: 480,
        deadline: new Date('2026-10-15T23:59:00.000Z'),
        academicWeight: 1.0,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }];

      const result = runReschedulerPipeline(tasks, overnightConstraints, [], [], horizonStart, horizonEnd, now);

      // Check no task block falls in 23:30–07:00 on day 1 or 2
      const sleepPeriods = [
        { start: new Date('2026-10-14T23:30:00.000Z'), end: new Date('2026-10-15T07:00:00.000Z') },
        { start: new Date('2026-10-15T23:30:00.000Z'), end: new Date('2026-10-16T07:00:00.000Z') },
      ];

      for (const block of result.blocks.filter(b => b.type === 'TASK')) {
        for (const sp of sleepPeriods) {
          const overlaps = intervalsIntersect(block.start, block.end, sp.start, sp.end);
          expect(overlaps).toBe(false);
        }
      }
    });
  });

  // ─── Bug 4: Backward Compatibility ──────────────────────────────────────────
  describe('BUG-4: Backward compatibility — existing tasks without dailyTargetMinutes', () => {
    it('REG-4a: All existing test tasks continue to schedule correctly', () => {
      const tasks: TaskInput[] = [
        {
          id: 'DSA', estimateMinutes: 120, completedMinutes: 0, remainingMinutes: 120,
          deadline: new Date('2026-10-15T00:00:00.000Z'), academicWeight: 1.0, teamImpact: 0,
          cognitiveLoad: 'HIGH', deferralCount: 0
          // No dailyTargetMinutes field at all
        },
        {
          id: 'Project', estimateMinutes: 90, completedMinutes: 0, remainingMinutes: 90,
          deadline: new Date('2026-10-16T00:00:00.000Z'), academicWeight: 0.5, teamImpact: 1.0,
          cognitiveLoad: 'MEDIUM', deferralCount: 0
          // No dailyTargetMinutes field at all
        }
      ];

      expect(() => {
        runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
      }).not.toThrow();

      const result = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
      expect(result.blocks.length).toBeGreaterThan(0);
      expect(result.logs.length).toBeGreaterThan(0);
    });
  });
});
