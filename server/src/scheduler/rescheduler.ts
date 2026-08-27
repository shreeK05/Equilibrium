import { TaskInput, ConstraintInput, FixedCommitment, ScheduleBlock, DecisionLog } from './types';
import { generateSlots, applyConstraints } from './capacity';
import { calculatePriority } from './priority';
import { solveKnapsack, KnapsackItem } from './knapsack';
import { placeTasks } from './placement';
import { validateSchedule } from './validator';

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
  const slots = generateSlots(horizonStart, horizonEnd);
  applyConstraints(slots, constraints, fixed, lockedBlocks);
  const availableSlots = slots.filter(s => s.available && s.start >= now).length;

  // 2. Priority
  const knapsackItems: KnapsackItem[] = [];
  const priorities: Record<string, {score: number, components: any}> = {};
  
  for (const task of tasks) {
    if (task.remainingMinutes <= 0) continue;
    const p = calculatePriority(task, now);
    priorities[task.id] = p;
    knapsackItems.push({
      task,
      priority: p.score,
      weightSlots: Math.min(Math.ceil(task.remainingMinutes / 30), availableSlots)
    });
  }

  // 3. Knapsack
  const selectedIds = solveKnapsack(knapsackItems, availableSlots);
  const selectedTasks = tasks.filter(t => selectedIds.has(t.id));

  // Log deferred tasks
  const logs: DecisionLog[] = [];
  tasks.filter(t => !selectedIds.has(t.id) && t.remainingMinutes > 0).forEach(t => {
    logs.push({
      taskId: t.id,
      decisionType: 'DEFERRED',
      priorityScore: priorities[t.id].score,
      priorityComponents: priorities[t.id].components,
      scheduledMinutes: 0,
      deferredMinutes: t.remainingMinutes,
      reasonCode: 'CAPACITY_EXCEEDED'
    });
  });

  // 4. Placement & Splitting
  const placementResult = placeTasks(slots, selectedTasks, priorities, now);
  const finalBlocks = [...lockedBlocks, ...placementResult.blocks];
  const finalLogs = [...logs, ...placementResult.logs];

  // 5. Validate
  const isValid = validateSchedule(finalBlocks, constraints, fixed, tasks);
  if (!isValid) {
    throw new Error('FATAL: Scheduler generated an invalid schedule violating hard constraints.');
  }

  return { blocks: finalBlocks, logs: finalLogs };
}
