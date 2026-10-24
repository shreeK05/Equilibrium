import { runReschedulerPipeline } from '../src/scheduler/rescheduler';
import { validateSchedule } from '../src/scheduler/validator';
import { solveKnapsack, KnapsackItem } from '../src/scheduler/knapsack';
import { TaskInput, ConstraintInput, FixedCommitment, ScheduleBlock } from '../src/scheduler/types';
import { intervalsIntersect } from '../src/scheduler/guard';

describe('Equilibrium Phase 2A: Deadline-Feasibility Scheduling Regression Suite', () => {
  const baseNow = new Date('2026-10-14T08:00:00.000Z');
  const horizonStart = new Date('2026-10-14T00:00:00.000Z');
  const horizonEnd = new Date('2026-10-17T00:00:00.000Z'); // 3 days

  const baseConstraints: ConstraintInput = {
    sleepStart: '23:00',
    sleepEnd: '06:00',
    minSleepHours: 7.0,
    bufferMinutes: 0,
    peakEnergyWindows: [{ start: '09:00', end: '12:00' }],
    timezone: 'UTC'
  };

  const createTask = (
    id: string,
    title: string,
    remainingMinutes: number,
    deadline: Date,
    academicWeight = 0.5,
    teamImpact = 0,
    deferralCount = 0
  ): TaskInput => ({
    id,
    title,
    estimateMinutes: remainingMinutes,
    completedMinutes: 0,
    remainingMinutes,
    deadline,
    academicWeight,
    teamImpact,
    cognitiveLoad: 'LOW',
    deferralCount
  });

  // ─── 1. Primary Regression: Impossible Urgent Task vs Feasible Later Task ────
  describe('1. PRIMARY REGRESSION: Urgent Infeasible Task Crowding Out Feasible Task', () => {
    it('Task A (urgent, 0 slots before deadline) must not crowd out Task B (later deadline, feasible)', () => {
      // Scenario:
      // Now is 08:00 UTC.
      // Fixed commitment blocks 08:00 to 10:00 UTC.
      // Available slots in morning: 10:00 to 11:00 UTC (2 slots, 60 minutes).
      // Task A has deadline at 09:30 UTC (during the commitment, so 0 usable slots before deadline).
      // Task A has high priority (academicWeight: 1.0, urgency multiplier).
      // Task B has deadline at 11:00 UTC (2 usable slots before deadline).
      // Task B has moderate priority (academicWeight: 0.5).
      const fixed: FixedCommitment[] = [{
        id: 'exam-block',
        start: new Date('2026-10-14T08:00:00.000Z'),
        end: new Date('2026-10-14T10:00:00.000Z')
      }];

      const taskA = createTask(
        'task-A-impossible-urgent',
        'Urgent Lab Report Due 09:30',
        60, // 2 slots needed
        new Date('2026-10-14T09:30:00.000Z'),
        1.0, // High academic weight
        0.5
      );

      const taskB = createTask(
        'task-B-feasible-later',
        'Feasible Problem Set Due 11:00',
        60, // 2 slots needed
        new Date('2026-10-14T11:00:00.000Z'),
        0.5,
        0
      );

      // Run scheduler pipeline up to 11:00 UTC
      const planningEnd = new Date('2026-10-14T11:00:00.000Z');
      const result = runReschedulerPipeline(
        [taskA, taskB],
        baseConstraints,
        fixed,
        [],
        horizonStart,
        planningEnd,
        baseNow
      );

      // Task B must be scheduled in the 10:00-11:00 window
      const taskBBlocks = result.blocks.filter(b => b.taskId === 'task-B-feasible-later');
      expect(taskBBlocks.length).toBeGreaterThan(0);
      const totalBMinutes = taskBBlocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(totalBMinutes).toBe(60);
      expect(taskBBlocks[0].start.toISOString()).toBe('2026-10-14T10:00:00.000Z');
      expect(taskBBlocks[taskBBlocks.length - 1].end.toISOString()).toBe('2026-10-14T11:00:00.000Z');

      // Task A must NOT be scheduled past its deadline
      const taskABlocks = result.blocks.filter(b => b.taskId === 'task-A-impossible-urgent');
      expect(taskABlocks.length).toBe(0);

      // Explainability: verify decision logs
      const logA = result.logs.find(l => l.taskId === 'task-A-impossible-urgent');
      expect(logA).toBeDefined();
      expect(logA?.decisionType).toBe('DEFERRED');
      expect(logA?.reasonCode).toBe('NO_AVAILABLE_SLOTS');
      expect(logA?.scheduledMinutes).toBe(0);
      expect(logA?.deferredMinutes).toBe(60);

      const logB = result.logs.find(l => l.taskId === 'task-B-feasible-later');
      expect(logB).toBeDefined();
      expect(logB?.decisionType).toBe('FULLY_SCHEDULED');
      expect(logB?.reasonCode).toBe('SUCCESS');
      expect(logB?.scheduledMinutes).toBe(60);
      expect(logB?.deferredMinutes).toBe(0);

      // Hard-constraint validation
      expect(validateSchedule(result.blocks, baseConstraints, fixed, [taskA, taskB])).toBe(true);
    });
  });

  // ─── 2. Competing Tasks with the Same Deadline ──────────────────────────────
  describe('2. COMPETING TASKS WITH THE SAME DEADLINE', () => {
    it('Enforces capacity limit among tasks sharing identical deadline; out-prioritized task is deferred', () => {
      // 08:00 to 09:00: 2 available slots (60 mins total).
      // Task 1 needs 60 mins (academicWeight: 0.8).
      // Task 2 needs 60 mins (academicWeight: 0.3).
      // Both have deadline at 09:00.
      const deadline = new Date('2026-10-14T09:00:00.000Z');
      const task1 = createTask('t1-higher', 'Task 1 Higher Priority', 60, deadline, 0.8);
      const task2 = createTask('t2-lower', 'Task 2 Lower Priority', 60, deadline, 0.3);

      const result = runReschedulerPipeline(
        [task1, task2],
        baseConstraints,
        [],
        [],
        horizonStart,
        deadline,
        baseNow
      );

      // Only Task 1 should be scheduled; Task 2 cannot fit before 09:00
      const scheduledIds = result.blocks.map(b => b.taskId);
      expect(scheduledIds).toContain('t1-higher');
      expect(scheduledIds).not.toContain('t2-lower');

      const log1 = result.logs.find(l => l.taskId === 't1-higher');
      expect(log1?.decisionType).toBe('FULLY_SCHEDULED');
      expect(log1?.reasonCode).toBe('SUCCESS');

      const log2 = result.logs.find(l => l.taskId === 't2-lower');
      expect(log2?.decisionType).toBe('DEFERRED');
      expect(log2?.reasonCode).toBe('CAPACITY_EXCEEDED');

      expect(validateSchedule(result.blocks, baseConstraints, [], [task1, task2])).toBe(true);
    });
  });

  // ─── 3. Multiple Deadlines Competing for Early Slots (Joint Feasibility) ────
  describe('3. MULTIPLE DEADLINES COMPETING FOR EARLY SLOTS', () => {
    it('Enforces prefix capacity constraints across staged deadlines (EDF joint feasibility)', () => {
      // Available slots: 08:00 to 10:00 (4 slots = 120 mins).
      // Slot 1 (08:00-08:30), Slot 2 (08:30-09:00) -> before 09:00 deadline (2 slots available)
      // Slot 3 (09:00-09:30), Slot 4 (09:30-10:00) -> before 10:00 deadline (4 slots available)
      //
      // Task Early 1: needs 60m (2 slots), deadline 09:00, priority 4.0
      // Task Early 2: needs 60m (2 slots), deadline 09:00, priority 3.5
      // Task Later:   needs 60m (2 slots), deadline 10:00, priority 3.0
      //
      // If scheduler independently checked capacity:
      // Early 1 sees 2 slots (fits).
      // Early 2 sees 2 slots (fits).
      // Total early demand = 4 slots, but only 2 slots exist before 09:00!
      // Joint prefix feasibility allows at most 2 slots before 09:00.
      // Thus, Knapsack must select Early 1 (2 slots) + Later (2 slots) = 4 slots.
      // Early 2 must be deferred due to capacity.
      const dEarly = new Date('2026-10-14T09:00:00.000Z');
      const dLater = new Date('2026-10-14T10:00:00.000Z');

      const early1 = createTask('early-1', 'Early 1', 60, dEarly, 0.8);
      const early2 = createTask('early-2', 'Early 2', 60, dEarly, 0.6);
      const later = createTask('later-3', 'Later 3', 60, dLater, 0.4);

      const result = runReschedulerPipeline(
        [early1, early2, later],
        baseConstraints,
        [],
        [],
        horizonStart,
        dLater,
        baseNow
      );

      const scheduledTaskIds = new Set(result.blocks.map(b => b.taskId));
      expect(scheduledTaskIds.has('early-1')).toBe(true);
      expect(scheduledTaskIds.has('later-3')).toBe(true);
      expect(scheduledTaskIds.has('early-2')).toBe(false);

      // Both scheduled tasks must meet their respective deadlines
      const blockEarly = result.blocks.filter(b => b.taskId === 'early-1');
      const blockLater = result.blocks.filter(b => b.taskId === 'later-3');
      expect(blockEarly[blockEarly.length - 1].end.getTime()).toBeLessThanOrEqual(dEarly.getTime());
      expect(blockLater[blockLater.length - 1].end.getTime()).toBeLessThanOrEqual(dLater.getTime());

      expect(validateSchedule(result.blocks, baseConstraints, [], [early1, early2, later])).toBe(true);
    });
  });

  // ─── 4. Overnight Sleep and Fixed Commitments with Deadlines ────────────────
  describe('4. OVERNIGHT SLEEP AND FIXED COMMITMENTS WITH DEADLINES', () => {
    it('Preserves sleep shield and fixed buffers without violating task deadlines across days', () => {
      // Sleep from 23:00 to 07:00 (8 hours).
      // Fixed commitment: 09:00 to 10:00 next day, with 30m buffer (08:30 to 10:30 blocked).
      // Task Night: needs 120m, deadline 23:00 (must finish before sleep).
      // Task Morning: needs 90m, deadline 12:00 next day (placed after sleep & fixed buffer).
      const sleepConstraints: ConstraintInput = {
        ...baseConstraints,
        sleepStart: '23:00',
        sleepEnd: '07:00',
        bufferMinutes: 30
      };

      const fixed: FixedCommitment[] = [{
        id: 'morning-seminar',
        start: new Date('2026-10-15T09:00:00.000Z'),
        end: new Date('2026-10-15T10:00:00.000Z')
      }];

      const nightTask = createTask(
        'night-prep',
        'Night Study',
        120,
        new Date('2026-10-14T23:00:00.000Z'),
        0.8
      );

      const morningTask = createTask(
        'morning-lab',
        'Morning Lab Work',
        90,
        new Date('2026-10-15T12:00:00.000Z'),
        0.6
      );

      const runNow = new Date('2026-10-14T20:00:00.000Z'); // 3 hours before sleep
      const horizon36h = new Date('2026-10-15T18:00:00.000Z');

      const result = runReschedulerPipeline(
        [nightTask, morningTask],
        sleepConstraints,
        fixed,
        [],
        horizonStart,
        horizon36h,
        runNow
      );

      // Night task must finish before 23:00 (zero overlap with 23:00-07:00 sleep)
      const sleepStart = new Date('2026-10-14T23:00:00.000Z');
      const sleepEnd = new Date('2026-10-15T07:00:00.000Z');
      const bufferedFixedStart = new Date('2026-10-15T08:30:00.000Z');
      const bufferedFixedEnd = new Date('2026-10-15T10:30:00.000Z');

      for (const block of result.blocks.filter(b => b.type === 'TASK')) {
        expect(intervalsIntersect(block.start, block.end, sleepStart, sleepEnd)).toBe(false);
        expect(intervalsIntersect(block.start, block.end, bufferedFixedStart, bufferedFixedEnd)).toBe(false);
      }

      const nightBlocks = result.blocks.filter(b => b.taskId === 'night-prep');
      expect(nightBlocks.reduce((acc, b) => acc + b.durationMinutes, 0)).toBe(120);
      expect(nightBlocks[nightBlocks.length - 1].end.getTime()).toBeLessThanOrEqual(nightTask.deadline.getTime());

      const morningBlocks = result.blocks.filter(b => b.taskId === 'morning-lab');
      expect(morningBlocks.reduce((acc, b) => acc + b.durationMinutes, 0)).toBe(90);
      expect(morningBlocks[morningBlocks.length - 1].end.getTime()).toBeLessThanOrEqual(morningTask.deadline.getTime());

      expect(validateSchedule(result.blocks, sleepConstraints, fixed, [nightTask, morningTask])).toBe(true);
    });
  });

  // ─── 5. Over-Capacity Periods ───────────────────────────────────────────────
  describe('5. OVER-CAPACITY PERIODS', () => {
    it('Schedules highest-priority feasible subset and accurately logs deferred overflow tasks', () => {
      // 3 hours available (08:00 to 11:00 = 6 slots).
      // 5 tasks of 60 mins each (10 slots total requested).
      // Available capacity = 6 slots.
      // Knapsack must select exactly 3 tasks (6 slots), and defer 2 tasks with CAPACITY_EXCEEDED.
      const deadline = new Date('2026-10-14T11:00:00.000Z');
      const tasks: TaskInput[] = [
        createTask('task-1', 'Task 1', 60, deadline, 1.0), // high
        createTask('task-2', 'Task 2', 60, deadline, 0.8), // high
        createTask('task-3', 'Task 3', 60, deadline, 0.6), // medium
        createTask('task-4', 'Task 4', 60, deadline, 0.3), // low
        createTask('task-5', 'Task 5', 60, deadline, 0.1)  // lowest
      ];

      const result = runReschedulerPipeline(
        tasks,
        baseConstraints,
        [],
        [],
        horizonStart,
        deadline,
        baseNow
      );

      const scheduledIds = result.blocks.map(b => b.taskId);
      expect(scheduledIds).toContain('task-1');
      expect(scheduledIds).toContain('task-2');
      expect(scheduledIds).toContain('task-3');
      expect(scheduledIds).not.toContain('task-4');
      expect(scheduledIds).not.toContain('task-5');

      const log4 = result.logs.find(l => l.taskId === 'task-4');
      expect(log4?.decisionType).toBe('DEFERRED');
      expect(log4?.reasonCode).toBe('CAPACITY_EXCEEDED');

      const log5 = result.logs.find(l => l.taskId === 'task-5');
      expect(log5?.decisionType).toBe('DEFERRED');
      expect(log5?.reasonCode).toBe('CAPACITY_EXCEEDED');

      const totalScheduled = result.blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(totalScheduled).toBe(180); // 3 * 60m

      expect(validateSchedule(result.blocks, baseConstraints, [], tasks)).toBe(true);
    });
  });

  // ─── 6. Partially Placeable Tasks ───────────────────────────────────────────
  describe('6. PARTIALLY PLACEABLE TASKS', () => {
    it('Schedules usable prefix and explains deferred remainder when deadline constrains demand', () => {
      // 2 hours available before deadline (08:00 to 10:00 = 4 slots).
      // Task requires 180 minutes (6 slots).
      // Scheduler must schedule 120 minutes (4 slots) and log 60 minutes deferred.
      const deadline = new Date('2026-10-14T10:00:00.000Z');
      const task = createTask('partial-task', 'Large Essay', 180, deadline, 0.7);

      const result = runReschedulerPipeline(
        [task],
        baseConstraints,
        [],
        [],
        horizonStart,
        deadline,
        baseNow
      );

      const placedMinutes = result.blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(placedMinutes).toBe(120);

      const log = result.logs.find(l => l.taskId === 'partial-task');
      expect(log).toBeDefined();
      expect(log?.decisionType).toBe('PARTIALLY_SCHEDULED');
      expect(log?.scheduledMinutes).toBe(120);
      expect(log?.deferredMinutes).toBe(60);

      expect(validateSchedule(result.blocks, baseConstraints, [], [task])).toBe(true);
    });
  });

  // ─── 7. Deterministic Results Across Repeated Runs ─────────────────────────
  describe('7. DETERMINISTIC EXECUTION ACROSS REPEATED RUNS', () => {
    it('Produces 100% bit-exact blocks and decision logs across 100 repeated runs', () => {
      const d1 = new Date('2026-10-14T12:00:00.000Z');
      const d2 = new Date('2026-10-14T16:00:00.000Z');
      const d3 = new Date('2026-10-15T12:00:00.000Z');

      const fixed: FixedCommitment[] = [
        { id: 'f1', start: new Date('2026-10-14T10:00:00.000Z'), end: new Date('2026-10-14T11:00:00.000Z') },
        { id: 'f2', start: new Date('2026-10-14T14:00:00.000Z'), end: new Date('2026-10-14T15:00:00.000Z') }
      ];

      const tasks: TaskInput[] = [
        createTask('det-1', 'Assignment 1', 90, d1, 0.9, 0.2),
        createTask('det-2', 'Impossible Task', 120, new Date('2026-10-14T08:30:00.000Z'), 1.0, 0.5), // impossible
        createTask('det-3', 'Assignment 2', 120, d2, 0.6, 0.0),
        createTask('det-4', 'Project Work', 180, d3, 0.8, 0.8),
        createTask('det-5', 'Reading', 60, d1, 0.4, 0.0)
      ];

      const firstRun = runReschedulerPipeline(
        tasks,
        baseConstraints,
        fixed,
        [],
        horizonStart,
        horizonEnd,
        baseNow
      );
      const firstBlocksJSON = JSON.stringify(firstRun.blocks);
      const firstLogsJSON = JSON.stringify(firstRun.logs);

      for (let run = 0; run < 100; run++) {
        const currentRun = runReschedulerPipeline(
          tasks,
          baseConstraints,
          fixed,
          [],
          horizonStart,
          horizonEnd,
          baseNow
        );
        expect(JSON.stringify(currentRun.blocks)).toBe(firstBlocksJSON);
        expect(JSON.stringify(currentRun.logs)).toBe(firstLogsJSON);
      }
    });
  });

  // ─── 8. Direct Knapsack Unit Feasibility ────────────────────────────────────
  describe('8. DIRECT KNAPSACK PREFIX CAPACITY FEASIBILITY', () => {
    it('Directly respects deadlineSlots prefix constraints in solveKnapsack', () => {
      // 4 slots available.
      // Task A: needs 2 slots, deadlineSlots: 2, priority: 10
      // Task B: needs 2 slots, deadlineSlots: 2, priority: 9
      // Task C: needs 2 slots, deadlineSlots: 4, priority: 8
      const dummyDate = new Date('2026-10-14T12:00:00.000Z');
      const items: KnapsackItem[] = [
        { task: createTask('A', 'A', 60, dummyDate), priority: 10, weightSlots: 2, deadlineSlots: 2 },
        { task: createTask('B', 'B', 60, dummyDate), priority: 9, weightSlots: 2, deadlineSlots: 2 },
        { task: createTask('C', 'C', 60, dummyDate), priority: 8, weightSlots: 2, deadlineSlots: 4 }
      ];

      // Total capacity 4 slots. If deadlines were ignored, A (10) and B (9) would be picked (total 19).
      // But A and B cannot both fit in the first 2 slots!
      // A (2 slots by slot 2) + C (2 slots by slot 4) is jointly feasible (total 18).
      const selected = solveKnapsack(items, 4);
      expect(selected.has('A')).toBe(true);
      expect(selected.has('C')).toBe(true);
      expect(selected.has('B')).toBe(false);
    });
  });

  // ─── 9. Partial-Work Scoring: Massive Task with 1 Slot vs Completable Task ───
  describe('9. PARTIAL-WORK SCORING (Objective Correctness)', () => {
    it('Large high-priority task with 1 slot available must not crowd out a short completable task', () => {
      // Scenario from Review Question 1 & 5:
      // Available window: 08:00 to 08:30 (1 slot, 30 minutes).
      // Task A requires 16 slots (480 minutes). Academic weight 1.0 (high priority ~4.0).
      // Task B requires 1 slot (30 minutes). Academic weight 0.6 (priority ~2.7).
      // Both are due at 08:30 (1 usable slot before deadline).
      //
      // Under proportional academic progress scoring:
      // Task A yields: 4.0 * (1 / 16) = 0.25 progress value.
      // Task B yields: 2.7 * (1 / 1)  = 2.70 completion value.
      //
      // Result: Task B must be selected and fully scheduled for 30 minutes.
      // Task A must be deferred with CAPACITY_EXCEEDED (its partial sliver was out-prioritized).
      const slotEnd = new Date('2026-10-14T08:30:00.000Z');
      const taskA = createTask(
        'task-A-massive-16slots',
        '8-Hour Thesis Draft Due 08:30',
        480, // 16 slots needed
        slotEnd,
        1.0, // High academic weight
        0.5
      );

      const taskB = createTask(
        'task-B-short-1slot',
        '30-Min Quiz Due 08:30',
        30, // 1 slot needed
        slotEnd,
        0.6, // Moderate academic weight
        0.0
      );

      const result = runReschedulerPipeline(
        [taskA, taskB],
        baseConstraints,
        [],
        [],
        horizonStart,
        slotEnd,
        baseNow
      );

      // Verify final generated blocks
      const bBlocks = result.blocks.filter(b => b.taskId === 'task-B-short-1slot');
      expect(bBlocks.length).toBe(1);
      expect(bBlocks[0].durationMinutes).toBe(30);
      expect(bBlocks[0].start.toISOString()).toBe('2026-10-14T08:00:00.000Z');
      expect(bBlocks[0].end.toISOString()).toBe('2026-10-14T08:30:00.000Z');

      const aBlocks = result.blocks.filter(b => b.taskId === 'task-A-massive-16slots');
      expect(aBlocks.length).toBe(0);

      // Verify DecisionLogs
      const logB = result.logs.find(l => l.taskId === 'task-B-short-1slot');
      expect(logB).toBeDefined();
      expect(logB?.decisionType).toBe('FULLY_SCHEDULED');
      expect(logB?.reasonCode).toBe('SUCCESS');
      expect(logB?.scheduledMinutes).toBe(30);
      expect(logB?.deferredMinutes).toBe(0);

      const logA = result.logs.find(l => l.taskId === 'task-A-massive-16slots');
      expect(logA).toBeDefined();
      expect(logA?.decisionType).toBe('DEFERRED');
      expect(logA?.reasonCode).toBe('CAPACITY_EXCEEDED');
      expect(logA?.scheduledMinutes).toBe(0);
      expect(logA?.deferredMinutes).toBe(480);

      expect(validateSchedule(result.blocks, baseConstraints, [], [taskA, taskB])).toBe(true);
    });

    it('High-priority partial work still wins when its partial progress value exceeds low-priority full work', () => {
      // Scenario:
      // Available window: 08:00 to 08:30 (1 slot, 30 minutes).
      // Task Urgent: needs 2 slots (60 mins), academicWeight 1.0, team 1.0 (priority ~5.0).
      // Effective 1-slot progress value = 5.0 * (1 / 2) = 2.50.
      // Task Chore: needs 1 slot (30 mins), academicWeight 0.1, team 0 (priority ~1.2).
      // Effective 1-slot completion value = 1.2 * (1 / 1) = 1.20.
      //
      // Because 2.50 > 1.20, spending the slot on the urgent major exam still out-values the low-priority chore!
      const slotEnd = new Date('2026-10-14T08:30:00.000Z');
      const taskUrgent = createTask('urgent-exam', 'Urgent Midterm Study', 60, slotEnd, 1.0, 1.0);
      const taskChore = createTask('minor-chore', 'Organize Desk Notes', 30, slotEnd, 0.1, 0.0);

      const result = runReschedulerPipeline(
        [taskUrgent, taskChore],
        baseConstraints,
        [],
        [],
        horizonStart,
        slotEnd,
        baseNow
      );

      // Verify final blocks
      const urgentBlocks = result.blocks.filter(b => b.taskId === 'urgent-exam');
      expect(urgentBlocks.length).toBe(1);
      expect(urgentBlocks[0].durationMinutes).toBe(30);

      const choreBlocks = result.blocks.filter(b => b.taskId === 'minor-chore');
      expect(choreBlocks.length).toBe(0);

      // Verify DecisionLogs
      const logUrgent = result.logs.find(l => l.taskId === 'urgent-exam');
      expect(logUrgent?.decisionType).toBe('PARTIALLY_SCHEDULED');
      expect(logUrgent?.scheduledMinutes).toBe(30);
      expect(logUrgent?.deferredMinutes).toBe(30);

      const logChore = result.logs.find(l => l.taskId === 'minor-chore');
      expect(logChore?.decisionType).toBe('DEFERRED');
      expect(logChore?.reasonCode).toBe('CAPACITY_EXCEEDED');

      expect(validateSchedule(result.blocks, baseConstraints, [], [taskUrgent, taskChore])).toBe(true);
    });
  });

  // ─── 10. Exhaustive Brute-Force Mathematical Equivalence Validation ─────────
  describe('10. EXHAUSTIVE BRUTE-FORCE MATHEMATICAL EQUIVALENCE', () => {
    /**
     * Exact exhaustive combinatorial solver for verification.
     * Evaluates all 2^n subsets under prefix deadline constraints and returns the maximum objective score.
     */
    function solveKnapsackBruteForce(items: KnapsackItem[], capacitySlots: number): { maxScore: number, selectedIds: Set<string> } {
      const n = items.length;
      let maxScore = -1;
      let bestSubset = new Set<string>();

      for (let mask = 0; mask < (1 << n); mask++) {
        const subset: KnapsackItem[] = [];
        let totalWeight = 0;
        let totalScore = 0;

        for (let i = 0; i < n; i++) {
          if ((mask & (1 << i)) !== 0) {
            subset.push(items[i]);
            totalWeight += items[i].weightSlots;
            totalScore += items[i].priority;
          }
        }

        if (totalWeight > capacitySlots) continue;

        // Verify joint prefix feasibility:
        // When subset items are sorted by deadlineSlots ascending,
        // cumulative weight at each step cannot exceed its deadlineSlots
        subset.sort((a, b) => {
          const dA = a.deadlineSlots ?? capacitySlots;
          const dB = b.deadlineSlots ?? capacitySlots;
          return dA - dB;
        });

        let prefixFeasible = true;
        let cumulative = 0;
        for (const item of subset) {
          cumulative += item.weightSlots;
          const limit = Math.min(item.deadlineSlots ?? capacitySlots, capacitySlots);
          if (cumulative > limit) {
            prefixFeasible = false;
            break;
          }
        }

        if (prefixFeasible && totalScore > maxScore + 0.000001) {
          maxScore = totalScore;
          bestSubset = new Set(subset.map(s => s.task.id));
        }
      }

      return { maxScore: Math.max(0, maxScore), selectedIds: bestSubset };
    }

    it('Achieves exact global optimality matching exhaustive search on diverse multi-deadline instances', () => {
      const dummyDate = new Date('2026-10-14T12:00:00.000Z');

      // 3 diverse test instances testing different combinations of deadlines, weights, and values
      const testCases: Array<{ items: KnapsackItem[], capacity: number }> = [
        // Instance 1: Same deadline, tight capacity
        {
          capacity: 4,
          items: [
            { task: createTask('T1', 'T1', 30, dummyDate), priority: 5.0, weightSlots: 1, deadlineSlots: 2 },
            { task: createTask('T2', 'T2', 60, dummyDate), priority: 8.0, weightSlots: 2, deadlineSlots: 2 },
            { task: createTask('T3', 'T3', 60, dummyDate), priority: 7.0, weightSlots: 2, deadlineSlots: 2 },
            { task: createTask('T4', 'T4', 30, dummyDate), priority: 4.0, weightSlots: 1, deadlineSlots: 4 }
          ]
        },
        // Instance 2: Scarce early capacity with multiple deadline stages (2, 4, 6)
        {
          capacity: 6,
          items: [
            { task: createTask('A', 'A', 60, dummyDate), priority: 6.0, weightSlots: 2, deadlineSlots: 2 },
            { task: createTask('B', 'B', 30, dummyDate), priority: 4.5, weightSlots: 1, deadlineSlots: 2 },
            { task: createTask('C', 'C', 90, dummyDate), priority: 9.0, weightSlots: 3, deadlineSlots: 4 },
            { task: createTask('D', 'D', 60, dummyDate), priority: 5.0, weightSlots: 2, deadlineSlots: 4 },
            { task: createTask('E', 'E', 60, dummyDate), priority: 7.0, weightSlots: 2, deadlineSlots: 6 },
            { task: createTask('F', 'F', 30, dummyDate), priority: 3.0, weightSlots: 1, deadlineSlots: 6 }
          ]
        },
        // Instance 3: Mixed weights and tight staggered deadlines
        {
          capacity: 5,
          items: [
            { task: createTask('X1', 'X1', 90, dummyDate), priority: 7.5, weightSlots: 3, deadlineSlots: 3 },
            { task: createTask('X2', 'X2', 60, dummyDate), priority: 6.0, weightSlots: 2, deadlineSlots: 3 },
            { task: createTask('X3', 'X3', 30, dummyDate), priority: 3.5, weightSlots: 1, deadlineSlots: 4 },
            { task: createTask('X4', 'X4', 60, dummyDate), priority: 5.5, weightSlots: 2, deadlineSlots: 5 },
            { task: createTask('X5', 'X5', 30, dummyDate), priority: 2.0, weightSlots: 1, deadlineSlots: 5 }
          ]
        }
      ];

      for (const { items, capacity } of testCases) {
        const bruteResult = solveKnapsackBruteForce(items, capacity);
        const dpSelectedIds = solveKnapsack([...items], capacity);

        // Compute total score achieved by solveKnapsack
        const dpScore = items
          .filter(it => dpSelectedIds.has(it.task.id))
          .reduce((sum, it) => sum + it.priority, 0);

        // Assert that DP achieves the exact optimal score found by exhaustive brute force
        expect(dpScore).toBeCloseTo(bruteResult.maxScore, 4);

        // Verify that solveKnapsack selection satisfies the joint prefix feasibility condition
        const selectedItems = items
          .filter(it => dpSelectedIds.has(it.task.id))
          .sort((a, b) => (a.deadlineSlots ?? capacity) - (b.deadlineSlots ?? capacity));

        let cumW = 0;
        for (const item of selectedItems) {
          cumW += item.weightSlots;
          const limit = Math.min(item.deadlineSlots ?? capacity, capacity);
          expect(cumW).toBeLessThanOrEqual(limit);
        }
        expect(cumW).toBeLessThanOrEqual(capacity);
      }
    });
  });

  // ─── 11. Selection-Placement Consistency: Daily Targets & Bounded Chunks ────
  describe('11. SELECTION-PLACEMENT CONSISTENCY (Daily Targets & Bounded Chunks)', () => {
    it('Accurately bounds Knapsack weight by dailyTargetMinutes across days', () => {
      // 2 days available (16 hours per day = 32 slots per day).
      // Task A: needs 480 mins (16 slots). dailyTargetMinutes = 60 mins (2 slots/day).
      // Over 2 days, at most 2 * 2 = 4 slots can be placed.
      // Knapsack must budget at most 4 slots, not 16 slots!
      // Task B: needs 60 mins (2 slots). No daily target. Due day 2.
      // Total capacity allows both.
      const day2End = new Date('2026-10-15T23:00:00.000Z');
      const taskDaily = createTask('task-daily', 'Paced Study Project', 480, day2End, 0.8);
      taskDaily.dailyTargetMinutes = 60; // 2 slots/day

      const taskNormal = createTask('task-normal', 'Quick Exercise', 60, day2End, 0.5);

      const result = runReschedulerPipeline(
        [taskDaily, taskNormal],
        baseConstraints,
        [],
        [],
        horizonStart,
        day2End,
        baseNow
      );

      // Verify task-daily is scheduled across days respecting daily target
      const dailyBlocks = result.blocks.filter(b => b.taskId === 'task-daily');
      const day1Blocks = dailyBlocks.filter(b => b.start.toISOString().startsWith('2026-10-14'));
      const day2Blocks = dailyBlocks.filter(b => b.start.toISOString().startsWith('2026-10-15'));

      const day1Minutes = day1Blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      const day2Minutes = day2Blocks.reduce((acc, b) => acc + b.durationMinutes, 0);

      expect(day1Minutes).toBeLessThanOrEqual(60);
      expect(day2Minutes).toBeLessThanOrEqual(60);

      // Verify normal task was also placed
      const normalBlocks = result.blocks.filter(b => b.taskId === 'task-normal');
      expect(normalBlocks.reduce((acc, b) => acc + b.durationMinutes, 0)).toBe(60);

      // Verify DecisionLog reports actual scheduled vs deferred work accurately
      const logDaily = result.logs.find(l => l.taskId === 'task-daily');
      expect(logDaily).toBeDefined();
      expect(logDaily?.decisionType).toBe('PARTIALLY_SCHEDULED');
      expect(logDaily?.reasonCode).toBe('DAILY_TARGET_PACING');
      expect(logDaily?.scheduledMinutes).toBe(day1Minutes + day2Minutes);
      expect(logDaily?.deferredMinutes).toBe(480 - (day1Minutes + day2Minutes));

      const logNormal = result.logs.find(l => l.taskId === 'task-normal');
      expect(logNormal?.decisionType).toBe('FULLY_SCHEDULED');
      expect(logNormal?.reasonCode).toBe('SUCCESS');
      expect(logNormal?.scheduledMinutes).toBe(60);

      expect(validateSchedule(result.blocks, baseConstraints, [], [taskDaily, taskNormal])).toBe(true);
    });
  });

  // ─── 12. Deadline Order vs Daily-Target-Capped Slots Conflict ──────────────
  describe('12. DEADLINE ORDER VS DAILY TARGET ALLOCATION LIMITS', () => {
    it('Respects chronological deadline capacity over daily-target allocation limits when early capacity is scarce', () => {
      // Setup:
      // Day 1 (2026-10-14): 08:00 to 11:00 UTC available (6 slots = 180 min).
      // Fixed commitment blocks 11:00 to 23:00 on Day 1.
      // Day 2 (2026-10-15): 08:00 to 16:00 UTC available (16 slots = 480 min).
      //
      // Task 1: Deadline Day 1 11:00 (chronological available slots = 6).
      //   Needs 180 min (6 slots). Academic weight 0.8.
      //   Needs ALL 6 available slots on Day 1.
      //
      // Task 2: Deadline Day 2 16:00 (chronological available slots = 22).
      //   dailyTargetMinutes = 60 (at most 2 slots/day).
      //   Needs 240 min (8 slots). Academic weight 1.0 (higher academic weight!).
      //   maxAllocatableSlots = 2 on Day 1 + 2 on Day 2 = 4 slots (120 min).
      //   Notice: Task 2 has a smaller allocatable slot count (4) than Task 1 (6),
      //   but Task 2 has a LATER deadline (Day 2 vs Day 1).
      //
      // Task 3: Deadline Day 2 16:00 (common deadline with Task 2).
      //   dailyTargetMinutes = 120 (4 slots/day).
      //   Needs 120 min (4 slots). Academic weight 0.6.
      //   maxAllocatableSlots = 4 slots.
      //
      // If deadline order were confused with daily-target allocation limit (4 vs 6):
      // Task 2 would be treated as if it has a tighter deadline limit than Task 1,
      // and would steal early slots on Day 1, starving Task 1 and causing Task 1 to miss its Day 1 deadline.
      //
      // Correct behavior:
      // Chronological deadline capacity is 6 for Task 1, 22 for Task 2 and Task 3.
      // Task 1 gets all 6 slots on Day 1 (180 mins) and meets its Day 1 deadline.
      // Task 2 gets 0 slots on Day 1, 2 slots on Day 2 (60 mins, respecting daily target).
      // Task 3 gets 0 slots on Day 1, 4 slots on Day 2 (120 mins, fully scheduled).
      const fixedDay1: FixedCommitment = {
        id: 'block-day1-afternoon',
        start: new Date('2026-10-14T11:00:00.000Z'),
        end: new Date('2026-10-14T23:00:00.000Z')
      };

      const dDay1 = new Date('2026-10-14T11:00:00.000Z');
      const dDay2 = new Date('2026-10-15T16:00:00.000Z');

      const task1 = createTask('task-1-urgent-day1', 'Urgent Day 1 Exam Review', 180, dDay1, 0.8);

      const task2 = createTask('task-2-paced-day2', 'Paced Project (60m/day)', 240, dDay2, 1.0);
      task2.dailyTargetMinutes = 60; // 2 slots/day

      const task3 = createTask('task-3-common-day2', 'Common Deadline (120m/day)', 120, dDay2, 0.6);
      task3.dailyTargetMinutes = 120; // 4 slots/day

      const result = runReschedulerPipeline(
        [task1, task2, task3],
        baseConstraints,
        [fixedDay1],
        [],
        horizonStart,
        dDay2,
        baseNow
      );

      // Verify Task 1 allocations: all 6 slots must be on Day 1 before 11:00
      const t1Blocks = result.blocks.filter(b => b.taskId === 'task-1-urgent-day1');
      expect(t1Blocks.length).toBeGreaterThan(0);
      const t1Minutes = t1Blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(t1Minutes).toBe(180);
      for (const b of t1Blocks) {
        expect(b.end.getTime()).toBeLessThanOrEqual(dDay1.getTime());
      }

      // Verify Task 2 allocations: zero on Day 1 (no capacity left on Day 1), placed on Day 2
      const t2Blocks = result.blocks.filter(b => b.taskId === 'task-2-paced-day2');
      const t2Day1 = t2Blocks.filter(b => b.start.toISOString().startsWith('2026-10-14'));
      const t2Day2 = t2Blocks.filter(b => b.start.toISOString().startsWith('2026-10-15'));
      expect(t2Day1.length).toBe(0);
      const t2Day2Minutes = t2Day2.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(t2Day2Minutes).toBe(60); // exactly 1 day's target on Day 2

      // Verify Task 3 allocations: placed on Day 2
      const t3Blocks = result.blocks.filter(b => b.taskId === 'task-3-common-day2');
      const t3Day2Minutes = t3Blocks.reduce((acc, b) => acc + b.durationMinutes, 0);
      expect(t3Day2Minutes).toBe(120); // full 120 mins placed on Day 2

      // Verify DecisionLogs
      const log1 = result.logs.find(l => l.taskId === 'task-1-urgent-day1');
      expect(log1?.decisionType).toBe('FULLY_SCHEDULED');
      expect(log1?.reasonCode).toBe('SUCCESS');
      expect(log1?.scheduledMinutes).toBe(180);

      const log2 = result.logs.find(l => l.taskId === 'task-2-paced-day2');
      expect(log2?.decisionType).toBe('PARTIALLY_SCHEDULED');
      expect(log2?.reasonCode).toBe('DAILY_TARGET_PACING');
      expect(log2?.scheduledMinutes).toBe(60);
      expect(log2?.deferredMinutes).toBe(180);

      const log3 = result.logs.find(l => l.taskId === 'task-3-common-day2');
      expect(log3?.decisionType).toBe('FULLY_SCHEDULED');
      expect(log3?.reasonCode).toBe('SUCCESS');
      expect(log3?.scheduledMinutes).toBe(120);

      // Hard constraint validator check
      expect(validateSchedule(result.blocks, baseConstraints, [fixedDay1], [task1, task2, task3])).toBe(true);
    });
  });
});
