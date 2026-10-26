import { formatInTimeZone } from 'date-fns-tz';
import { TaskInput, ConstraintInput, FixedCommitment, ScheduleBlock, DecisionLog } from './types';
import { generateSlots, applyConstraints, Slot } from './capacity';
import { calculatePriority } from './priority';
import { solveKnapsack, KnapsackItem } from './knapsack';
import { placeTasks } from './placement';
import { validateSchedule } from './validator';

/**
 * Computes:
 * 1. deadlineCapacity: count of genuinely available 30-minute slots ending by task deadline,
 *    independent of task-specific daily targets. Used for chronological EDF ordering and joint prefix constraint.
 * 2. maxAllocatableSlots: maximum number of slots this task may receive after accounting for
 *    remaining duration and optional dailyTargetMinutes across eligible days.
 */
function computeTaskSlotLimits(
  availableSlots: Slot[],
  deadline: Date,
  remainingMinutes: number,
  dailyTargetMinutes?: number | null,
  tz: string = 'Asia/Kolkata'
): { deadlineCapacity: number; maxAllocatableSlots: number } {
  const slotsBeforeDeadline = availableSlots.filter(s => s.end <= deadline);
  const deadlineCapacity = slotsBeforeDeadline.length;

  const neededSlots = Math.ceil(remainingMinutes / 30);
  if (!dailyTargetMinutes) {
    const maxAllocatableSlots = Math.min(neededSlots, deadlineCapacity);
    return { deadlineCapacity, maxAllocatableSlots };
  }

  const maxDailySlots = Math.ceil(dailyTargetMinutes / 30);
  const slotsPerDay = new Map<string, number>();
  for (const s of slotsBeforeDeadline) {
    const day = formatInTimeZone(s.start, tz, 'yyyy-MM-dd');
    slotsPerDay.set(day, (slotsPerDay.get(day) || 0) + 1);
  }
  let pacedSlots = 0;
  for (const count of slotsPerDay.values()) {
    pacedSlots += Math.min(count, maxDailySlots);
  }
  const maxAllocatableSlots = Math.min(neededSlots, pacedSlots);
  return { deadlineCapacity, maxAllocatableSlots };
}

export function runReschedulerPipeline(
  tasks: TaskInput[],
  constraints: ConstraintInput,
  fixed: FixedCommitment[],
  lockedBlocks: ScheduleBlock[],
  horizonStart: Date,
  horizonEnd: Date,
  now: Date
): { blocks: ScheduleBlock[], logs: DecisionLog[] } {
  // 1. Capacity
  const tz = constraints.timezone || 'Asia/Kolkata';
  const slots = generateSlots(horizonStart, horizonEnd);
  applyConstraints(slots, constraints, fixed, lockedBlocks);
  const availableSlotsList = slots.filter(s => s.available && s.start >= now);
  const availableSlots = availableSlotsList.length;

  // 2. Priority & Deadline Capacity Evaluation
  const knapsackItems: KnapsackItem[] = [];
  const priorities: Record<string, {score: number, components: any}> = {};
  const infeasibleLogs: DecisionLog[] = [];

  for (const task of tasks) {
    if (task.remainingMinutes <= 0) continue;
    const p = calculatePriority(task, now);
    priorities[task.id] = p;

    // 1. deadlineCapacity: actual chronological available slots ending by deadline (for EDF & prefix constraint)
    // 2. maxAllocatableSlots: task-specific allocation limit (capped by dailyTargetMinutes and neededSlots)
    const { deadlineCapacity, maxAllocatableSlots } = computeTaskSlotLimits(
      availableSlotsList,
      task.deadline,
      task.remainingMinutes,
      task.dailyTargetMinutes,
      tz
    );

    if (deadlineCapacity === 0) {
      // Zero genuinely available slots before deadline
      const isPast = task.deadline.getTime() <= now.getTime();
      const slotsBeforeDeadline = slots.filter(s => s.start >= now && s.end <= task.deadline);
      const blockedByRoutines = slotsBeforeDeadline.some(s => s.blockedReason === 'MEAL' || s.blockedReason === 'ROUTINE');

      let reasonCode: any = 'NO_AVAILABLE_SLOTS';
      let humanReadable = `Deferred '${task.title}' entirely. No valid time slots were available prior to the deadline after accommodating sleep and fixed commitments.`;

      if (isPast) {
        reasonCode = 'DEADLINE_IN_PAST';
        humanReadable = `Deferred '${task.title}'. The deadline (${task.deadline.toISOString()}) has already passed.`;
      } else if (blockedByRoutines && slotsBeforeDeadline.filter(s => s.available).length === 0) {
        reasonCode = 'MEAL_ROUTINE_CONFLICT';
        humanReadable = `Deferred '${task.title}'. Remaining free time before deadline conflicted with protected meal or routine hours.`;
      }

      infeasibleLogs.push({
        taskId: task.id,
        decisionType: 'DEFERRED',
        priorityScore: p.score,
        priorityComponents: p.components,
        scheduledMinutes: 0,
        deferredMinutes: task.remainingMinutes,
        reasonCode,
        humanReadable
      });
    } else if (maxAllocatableSlots === 0) {
      // Slots exist before deadline, but task-specific pacing restricts allocation to 0
      infeasibleLogs.push({
        taskId: task.id,
        decisionType: 'DEFERRED',
        priorityScore: p.score,
        priorityComponents: p.components,
        scheduledMinutes: 0,
        deferredMinutes: task.remainingMinutes,
        reasonCode: 'DAILY_TARGET_PACING',
        humanReadable: `Deferred '${task.title}' entirely due to daily workload target limit.`
      });
    } else {
      const neededSlots = Math.ceil(task.remainingMinutes / 30);
      const weightSlots = maxAllocatableSlots;
      // Objective: Total Weighted Academic Progress over Capped Task Bundles
      // When a task can only be partially completed before its deadline, its effective knapsack priority
      // is scaled proportionally to the progress achievable: p.score * (weightSlots / neededSlots).
      // This prevents a large partial task from claiming full completion value and crowding out completable tasks.
      const progressFraction = weightSlots / neededSlots;
      const effectivePriority = p.score * progressFraction;

      knapsackItems.push({
        task,
        priority: effectivePriority,
        weightSlots,
        deadlineCapacity,
        deadlineSlots: deadlineCapacity
      });
    }
  }

  // 3. Deadline-Constrained Knapsack Selection
  const selectedIds = solveKnapsack(knapsackItems, availableSlots);
  const selectedTasks = tasks.filter(t => selectedIds.has(t.id));

  // Log tasks that had available slots but were out-prioritized in Knapsack
  const deferredOutprioritizedLogs: DecisionLog[] = [];
  knapsackItems.filter(item => !selectedIds.has(item.task.id)).forEach(item => {
    const t = item.task;
    deferredOutprioritizedLogs.push({
      taskId: t.id,
      decisionType: 'DEFERRED',
      priorityScore: priorities[t.id].score,
      priorityComponents: priorities[t.id].components,
      scheduledMinutes: 0,
      deferredMinutes: t.remainingMinutes,
      reasonCode: 'CAPACITY_EXCEEDED',
      humanReadable: `Deferred '${t.title}'. The schedule reached maximum capacity. This task was out-prioritized by others with higher academic weight, team impact, or closer deadlines.`
    });
  });

  // 4. Placement & Splitting
  const placementResult = placeTasks(slots, selectedTasks, priorities, now, constraints);
  const finalBlocks = [...lockedBlocks, ...placementResult.blocks];

  // Combine logs deterministically in input task order
  const logMap = new Map<string, DecisionLog>();
  for (const log of [...infeasibleLogs, ...deferredOutprioritizedLogs, ...placementResult.logs]) {
    logMap.set(log.taskId, log);
  }
  const finalLogs = tasks
    .filter(t => t.remainingMinutes > 0 && logMap.has(t.id))
    .map(t => logMap.get(t.id)!);

  // 5. Validate
  const isValid = validateSchedule(finalBlocks, constraints, fixed, tasks);
  if (!isValid) {
    throw new Error('FATAL: Scheduler generated an invalid schedule violating hard constraints.');
  }

  return { blocks: finalBlocks, logs: finalLogs };
}
