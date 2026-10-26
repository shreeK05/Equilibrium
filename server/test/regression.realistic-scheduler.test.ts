import { runReschedulerPipeline } from '../src/scheduler/rescheduler';
import { TaskInput, ConstraintInput, RoutineInput, FixedCommitment } from '../src/scheduler/types';
import { toDate, format } from 'date-fns-tz';

describe('Milestone 1 & 3 — Realistic Workload Scheduling Engine', () => {
  const IST = 'Asia/Kolkata';
  const horizonStart = toDate('2026-10-26T00:00:00', { timeZone: IST });
  const horizonEnd = toDate('2026-11-02T00:00:00', { timeZone: IST });
  const now = toDate('2026-10-26T08:00:00', { timeZone: IST });

  const defaultRoutines: RoutineInput[] = [
    { id: 'r1', title: 'Breakfast', category: 'MEAL', startTime: '08:00', endTime: '09:00', isEnabled: true },
    { id: 'r2', title: 'Lunch', category: 'MEAL', startTime: '13:00', endTime: '14:00', isEnabled: true },
    { id: 'r3', title: 'Dinner', category: 'MEAL', startTime: '20:00', endTime: '21:00', isEnabled: true },
    { id: 'r4', title: 'Evening Walk', category: 'EXERCISE', startTime: '17:30', endTime: '18:00', isEnabled: true }
  ];

  const baseConstraints: ConstraintInput = {
    sleepStart: '23:00',
    sleepEnd: '07:00',
    minSleepHours: 8.0,
    bufferMinutes: 15,
    peakEnergyWindows: [{ start: '09:30', end: '12:00' }],
    timezone: IST,
    routines: defaultRoutines,
    maxDailyStudyMinutes: 360 // 6 hours/day maximum study cap
  };

  test('1. Never schedules work over meals (Breakfast 8-9, Lunch 13-14, Dinner 20-21)', () => {
    const tasks: TaskInput[] = [
      {
        id: 't-lunch-window',
        title: 'DBMS Assignment',
        estimateMinutes: 120,
        completedMinutes: 0,
        remainingMinutes: 120,
        deadline: toDate('2026-10-26T16:00:00', { timeZone: IST }),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }
    ];

    const res = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
    expect(res.blocks.length).toBeGreaterThan(0);

    for (const b of res.blocks) {
      const bStart = format(b.start, 'HH:mm', { timeZone: IST });
      const bEnd = format(b.end, 'HH:mm', { timeZone: IST });

      // Ensure block does NOT overlap Breakfast (08:00-09:00)
      expect(b.start.getTime() < toDate('2026-10-26T09:00:00', { timeZone: IST }).getTime()).toBe(false);

      // Ensure block does NOT overlap Lunch (13:00-14:00)
      const lunchStart = toDate('2026-10-26T13:00:00', { timeZone: IST });
      const lunchEnd = toDate('2026-10-26T14:00:00', { timeZone: IST });
      const overlapsLunch = b.start < lunchEnd && lunchStart < b.end;
      expect(overlapsLunch).toBe(false);
    }
  });

  test('2. Enforces daily workload limit (maxDailyStudyMinutes) and spaces work', () => {
    // 3 tasks totaling 480 minutes, but daily limit is 360 (6 hours)
    const tasks: TaskInput[] = [
      {
        id: 't1',
        title: 'OS Kernels',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: toDate('2026-10-28T18:00:00', { timeZone: IST }),
        academicWeight: 0.9,
        teamImpact: 0,
        cognitiveLoad: 'HIGH',
        deferralCount: 0
      },
      {
        id: 't2',
        title: 'CN Packet Tracer',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: toDate('2026-10-28T18:00:00', { timeZone: IST }),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      },
      {
        id: 't3',
        title: 'Math Proofs',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: toDate('2026-10-28T18:00:00', { timeZone: IST }),
        academicWeight: 0.7,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }
    ];

    const res = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
    
    // Group scheduled minutes by day
    const dayAllocations: Record<string, number> = {};
    for (const b of res.blocks) {
      const day = format(b.start, 'yyyy-MM-dd', { timeZone: IST });
      dayAllocations[day] = (dayAllocations[day] ?? 0) + b.durationMinutes;
    }

    // Every day must be <= 360 minutes
    for (const [day, minutes] of Object.entries(dayAllocations)) {
      expect(minutes).toBeLessThanOrEqual(baseConstraints.maxDailyStudyMinutes!);
    }
  });

  test('3. Splits long tasks into sensible focus sessions when maxFocusSessionMinutes is configured', () => {
    const customConstraints: ConstraintInput = {
      ...baseConstraints,
      maxFocusSessionMinutes: 90 // Max 90m per session
    };

    const tasks: TaskInput[] = [
      {
        id: 't-long',
        title: 'Comprehensive Lab Report',
        estimateMinutes: 180,
        completedMinutes: 0,
        remainingMinutes: 180,
        deadline: toDate('2026-10-27T18:00:00', { timeZone: IST }),
        academicWeight: 0.9,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }
    ];

    const res = runReschedulerPipeline(tasks, customConstraints, [], [], horizonStart, horizonEnd, now);
    expect(res.blocks.length).toBeGreaterThanOrEqual(2);
    for (const b of res.blocks) {
      expect(b.durationMinutes).toBeLessThanOrEqual(90);
    }
  });

  test('4. Correctly classifies DEADLINE_IN_PAST for overdue tasks', () => {
    const tasks: TaskInput[] = [
      {
        id: 't-past',
        title: 'Yesterday Lab Submission',
        estimateMinutes: 60,
        completedMinutes: 0,
        remainingMinutes: 60,
        deadline: toDate('2026-10-25T17:00:00', { timeZone: IST }), // in the past relative to now (Oct 26 08:00)
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'LOW',
        deferralCount: 1
      }
    ];

    const res = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
    const log = res.logs.find(l => l.taskId === 't-past');
    expect(log).toBeDefined();
    expect(log?.decisionType).toBe('DEFERRED');
    expect(log?.reasonCode).toBe('DEADLINE_IN_PAST');
    expect(log?.humanReadable).toContain('deadline');
  });

  test('5. Correctly detects MEAL_ROUTINE_CONFLICT when task deadline is within meal time', () => {
    // Current time: 13:00. Deadline: 14:00. Lunch routine: 13:00 - 14:00.
    // 0 available study slots before deadline because it falls entirely inside lunch!
    const mealNow = toDate('2026-10-26T13:00:00', { timeZone: IST });
    const tasks: TaskInput[] = [
      {
        id: 't-lunch-conflict',
        title: 'Quick Homework',
        estimateMinutes: 60,
        completedMinutes: 0,
        remainingMinutes: 60,
        deadline: toDate('2026-10-26T14:00:00', { timeZone: IST }),
        academicWeight: 0.8,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }
    ];

    const res = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, mealNow);
    const log = res.logs.find(l => l.taskId === 't-lunch-conflict');
    expect(log).toBeDefined();
    expect(log?.decisionType).toBe('DEFERRED');
    expect(['MEAL_ROUTINE_CONFLICT', 'NO_AVAILABLE_SLOTS']).toContain(log?.reasonCode);
    expect(res.blocks.length).toBe(0);
  });


  test('6. Scheduling is strictly deterministic for identical inputs', () => {
    const tasks: TaskInput[] = [
      {
        id: 't-det1',
        title: 'Physics Lab',
        estimateMinutes: 90,
        completedMinutes: 0,
        remainingMinutes: 90,
        deadline: toDate('2026-10-27T17:00:00', { timeZone: IST }),
        academicWeight: 0.85,
        teamImpact: 0,
        cognitiveLoad: 'HIGH',
        deferralCount: 0
      },
      {
        id: 't-det2',
        title: 'Chemistry Quiz Prep',
        estimateMinutes: 60,
        completedMinutes: 0,
        remainingMinutes: 60,
        deadline: toDate('2026-10-27T15:00:00', { timeZone: IST }),
        academicWeight: 0.75,
        teamImpact: 0,
        cognitiveLoad: 'MEDIUM',
        deferralCount: 0
      }
    ];

    const run1 = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);
    const run2 = runReschedulerPipeline(tasks, baseConstraints, [], [], horizonStart, horizonEnd, now);

    expect(run1.blocks.length).toBe(run2.blocks.length);
    for (let i = 0; i < run1.blocks.length; i++) {
      expect(run1.blocks[i].taskId).toBe(run2.blocks[i].taskId);
      expect(run1.blocks[i].start.getTime()).toBe(run2.blocks[i].start.getTime());
      expect(run1.blocks[i].end.getTime()).toBe(run2.blocks[i].end.getTime());
      expect(run1.blocks[i].durationMinutes).toBe(run2.blocks[i].durationMinutes);
    }
  });
});
