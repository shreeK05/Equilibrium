import { formatInTimeZone } from 'date-fns-tz';
import { Slot } from './capacity';
import { TaskInput, ScheduleBlock, DecisionLog } from './types';

export const MIN_CHUNK_SLOTS = 1; // 30 min
export const MAX_CHUNK_SLOTS = 8; // 4 hours

/**
 * Returns the localized day key "YYYY-MM-DD" for a given date, used to bucket per-day allocation.
 */
function dayKey(d: Date, tz: string = 'Asia/Kolkata'): string {
  return formatInTimeZone(d, tz, 'yyyy-MM-dd');
}

export function placeTasks(
  slots: Slot[],
  tasks: TaskInput[], // Array of tasks that knapsack selected
  priorities: Record<string, {score: number, components: any}>,
  now: Date,
  constraints?: import('./types').ConstraintInput
): { blocks: ScheduleBlock[], logs: DecisionLog[] } {
  const tz = constraints?.timezone || 'Asia/Kolkata';
  const blocks: ScheduleBlock[] = [];
  const logs: DecisionLog[] = [];

  const maxChunkSlots = constraints?.maxFocusSessionMinutes
    ? Math.max(1, Math.min(MAX_CHUNK_SLOTS, Math.ceil(constraints.maxFocusSessionMinutes / 30)))
    : MAX_CHUNK_SLOTS;

  const maxDailyTotalSlots = constraints?.maxDailyStudyMinutes
    ? Math.ceil(constraints.maxDailyStudyMinutes / 30)
    : Infinity;

  // Track global daily allocation across all tasks
  const dailyTotalAllocatedSlots: Record<string, number> = {};

  // Sort selected tasks deterministically in Earliest Deadline First (EDF) order
  // to prevent later-deadline tasks from consuming early slots needed by earlier deadlines
  const sortedTasks = [...tasks].sort((a, b) => {
    if (a.deadline.getTime() !== b.deadline.getTime()) {
      return a.deadline.getTime() - b.deadline.getTime();
    }
    if (Math.abs(priorities[b.id].score - priorities[a.id].score) > 0.0001) {
      return priorities[b.id].score - priorities[a.id].score;
    }
    return a.id.localeCompare(b.id);
  });

  for (const task of sortedTasks) {
    let remainingSlots = Math.ceil(task.remainingMinutes / 30);
    if (remainingSlots <= 0) continue;
    const originalSlots = remainingSlots;
    let placedSlots = 0;

    // Energy matching preference for HIGH cognitive load
    const requiresEnergyMatch = task.cognitiveLoad === 'HIGH';

    // Per-day allocated slot count for this task (enforces dailyTargetMinutes)
    const dailyAllocatedSlots: Record<string, number> = {};
    const maxDailySlotsForTask = task.dailyTargetMinutes
      ? Math.ceil(task.dailyTargetMinutes / 30)
      : Infinity;

    // We do multiple passes.
    // Pass 1: Try to fit in energy windows if required
    // Pass 2: Try to fit anywhere
    const passes = requiresEnergyMatch ? [true, false] : [false];

    for (const energyRequired of passes) {
      if (remainingSlots <= 0) break;
      
      let currentChunk: Slot[] = [];
      for (let i = 0; i < slots.length; i++) {
        if (remainingSlots <= 0) break;

        const slot = slots[i];
        const key = dayKey(slot.start, tz);

        // Check per-day quota and global day quota
        const allocatedToday = dailyAllocatedSlots[key] ?? 0;
        const totalAllocatedToday = dailyTotalAllocatedSlots[key] ?? 0;
        const dayQuotaReached = allocatedToday >= maxDailySlotsForTask;
        const globalDayQuotaReached = totalAllocatedToday >= maxDailyTotalSlots;

        // Ensure the slot is valid for this task
        const canUse = slot.available
          && (!energyRequired || slot.energyBonus)
          && slot.start >= now
          && slot.end <= task.deadline
          && !dayQuotaReached
          && !globalDayQuotaReached;

        if (canUse) {
          currentChunk.push(slot);
          if (currentChunk.length === maxChunkSlots || currentChunk.length === remainingSlots) {
            // Check if committing this chunk would violate daily quota
            const chunkDayKey = dayKey(currentChunk[0].start, tz);
            const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
            const totalThisDay = dailyTotalAllocatedSlots[chunkDayKey] ?? 0;
            const remainingTaskQuota = maxDailySlotsForTask !== Infinity ? Math.max(0, maxDailySlotsForTask - allocatedThisDay) : currentChunk.length;
            const remainingGlobalQuota = maxDailyTotalSlots !== Infinity ? Math.max(0, maxDailyTotalSlots - totalThisDay) : currentChunk.length;
            const allowed = Math.min(
              currentChunk.length,
              remainingTaskQuota,
              remainingGlobalQuota
            );

            if (allowed < currentChunk.length && (maxDailySlotsForTask !== Infinity || maxDailyTotalSlots !== Infinity)) {
              if (allowed > 0) {
                const trimmedChunk = currentChunk.slice(0, allowed);
                commitChunk(trimmedChunk, task, blocks);
                trimmedChunk.forEach(s => s.available = false);
                placedSlots += trimmedChunk.length;
                remainingSlots -= trimmedChunk.length;
                dailyAllocatedSlots[chunkDayKey] = (dailyAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
                dailyTotalAllocatedSlots[chunkDayKey] = (dailyTotalAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
              }
              currentChunk = [];
            } else {
              // Commit full chunk
              commitChunk(currentChunk, task, blocks);
              currentChunk.forEach(s => s.available = false);
              placedSlots += currentChunk.length;
              remainingSlots -= currentChunk.length;
              const ck = dayKey(currentChunk[0].start, tz);
              dailyAllocatedSlots[ck] = (dailyAllocatedSlots[ck] ?? 0) + currentChunk.length;
              dailyTotalAllocatedSlots[ck] = (dailyTotalAllocatedSlots[ck] ?? 0) + currentChunk.length;
              currentChunk = [];
            }
          }
        } else {
          // Break in availability — commit any partial chunk we've built
          if (currentChunk.length >= MIN_CHUNK_SLOTS) {
            const chunkDayKey = dayKey(currentChunk[0].start, tz);
            const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
            const totalThisDay = dailyTotalAllocatedSlots[chunkDayKey] ?? 0;
            const allowedTask = maxDailySlotsForTask !== Infinity ? maxDailySlotsForTask - allocatedThisDay : currentChunk.length;
            const allowedGlobal = maxDailyTotalSlots !== Infinity ? maxDailyTotalSlots - totalThisDay : currentChunk.length;
            const allowedInChunk = Math.min(currentChunk.length, Math.max(0, allowedTask), Math.max(0, allowedGlobal));
            
            if (allowedInChunk > 0) {
              const trimmedChunk = currentChunk.slice(0, allowedInChunk);
              commitChunk(trimmedChunk, task, blocks);
              trimmedChunk.forEach(s => s.available = false);
              placedSlots += trimmedChunk.length;
              remainingSlots -= trimmedChunk.length;
              dailyAllocatedSlots[chunkDayKey] = (dailyAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
              dailyTotalAllocatedSlots[chunkDayKey] = (dailyTotalAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
            }
          }
          currentChunk = [];
        }
      }
      
      // End of slots cleanup
      if (currentChunk.length >= MIN_CHUNK_SLOTS) {
        const chunkDayKey = dayKey(currentChunk[0].start, tz);
        const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
        const totalThisDay = dailyTotalAllocatedSlots[chunkDayKey] ?? 0;
        const allowedTask = maxDailySlotsForTask !== Infinity ? maxDailySlotsForTask - allocatedThisDay : currentChunk.length;
        const allowedGlobal = maxDailyTotalSlots !== Infinity ? maxDailyTotalSlots - totalThisDay : currentChunk.length;
        const allowedInChunk = Math.min(currentChunk.length, Math.max(0, allowedTask), Math.max(0, allowedGlobal));
        
        if (allowedInChunk > 0) {
          const trimmedChunk = currentChunk.slice(0, allowedInChunk);
          commitChunk(trimmedChunk, task, blocks);
          trimmedChunk.forEach(s => s.available = false);
          placedSlots += trimmedChunk.length;
          remainingSlots -= trimmedChunk.length;
          dailyAllocatedSlots[chunkDayKey] = (dailyAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
          dailyTotalAllocatedSlots[chunkDayKey] = (dailyTotalAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
        }
      }
    }

    // Determine reason code for logs
    const isLimitedByDailyTarget = task.dailyTargetMinutes != null
      && placedSlots < originalSlots
      && remainingSlots > 0;

    // Check if slots before deadline were blocked by meals or routines
    const slotsBeforeDeadline = slots.filter(s => s.start >= now && s.end <= task.deadline);
    const hasMealOrRoutineBlocks = slotsBeforeDeadline.some(s => s.blockedReason === 'MEAL' || s.blockedReason === 'BREAK' || s.blockedReason === 'ROUTINE');

    // Generate decision log
    if (placedSlots === originalSlots) {
      logs.push({
        taskId: task.id,
        decisionType: 'FULLY_SCHEDULED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: placedSlots * 30,
        deferredMinutes: 0,
        reasonCode: 'SUCCESS',
        humanReadable: `Fully scheduled '${task.title}' because its priority score (${priorities[task.id].score.toFixed(2)}) secured enough capacity.`
      });
    } else if (placedSlots > 0) {
      logs.push({
        taskId: task.id,
        decisionType: 'PARTIALLY_SCHEDULED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: placedSlots * 30,
        deferredMinutes: remainingSlots * 30,
        reasonCode: isLimitedByDailyTarget ? 'DAILY_TARGET_PACING' : 'FRAGMENTED_CAPACITY',
        humanReadable: isLimitedByDailyTarget 
          ? `Partially scheduled '${task.title}' to respect its daily workload limit. Deferred ${remainingSlots * 30}m to future days.`
          : `Partially scheduled '${task.title}'. Deferred ${remainingSlots * 30}m because protected sleep, meals, and fixed commitments left insufficient contiguous capacity.`
      });
    } else {
      let reasonCode: any = 'NO_AVAILABLE_SLOTS';
      let humanReadable = `Deferred '${task.title}' entirely. No valid time slots were available after accommodating higher priority tasks and fixed commitments.`;

      if (task.deadline < now) {
        reasonCode = 'DEADLINE_IN_PAST';
        humanReadable = `Deferred '${task.title}'. The deadline has already passed. Please update the deadline to reschedule.`;
      } else if (isLimitedByDailyTarget || (constraints?.maxDailyStudyMinutes && (dailyTotalAllocatedSlots[dayKey(now, tz)] ?? 0) >= maxDailyTotalSlots)) {
        reasonCode = 'DAILY_TARGET_PACING';
        humanReadable = `Deferred '${task.title}' to respect daily workload pacing limits. Work will be planned on upcoming available days.`;
      } else if (hasMealOrRoutineBlocks && slotsBeforeDeadline.filter(s => s.available).length === 0) {
        reasonCode = 'MEAL_ROUTINE_CONFLICT';
        humanReadable = `Deferred '${task.title}'. Available hours before deadline conflicted with protected meal or personal routine hours.`;
      }

      logs.push({
        taskId: task.id,
        decisionType: 'DEFERRED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: 0,
        deferredMinutes: originalSlots * 30,
        reasonCode,
        humanReadable
      });
    }
  }

  return { blocks, logs };
}

function commitChunk(slots: Slot[], task: TaskInput, blocks: ScheduleBlock[]) {
  blocks.push({
    taskId: task.id,
    type: 'TASK',
    start: slots[0].start,
    end: slots[slots.length - 1].end,
    durationMinutes: slots.length * 30,
    isLocked: false
  });
}
