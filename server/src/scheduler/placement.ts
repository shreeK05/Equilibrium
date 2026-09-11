import { Slot } from './capacity';
import { TaskInput, ScheduleBlock, DecisionLog } from './types';

export const MIN_CHUNK_SLOTS = 1; // 30 min
export const MAX_CHUNK_SLOTS = 8; // 4 hours

/**
 * Returns the UTC day key "YYYY-MM-DD" for a given date, used to bucket per-day allocation.
 */
function dayKey(d: Date): string {
  return d.toISOString().substring(0, 10);
}

export function placeTasks(
  slots: Slot[],
  tasks: TaskInput[], // Array of tasks that knapsack selected
  priorities: Record<string, {score: number, components: any}>,
  now: Date
): { blocks: ScheduleBlock[], logs: DecisionLog[] } {
  const blocks: ScheduleBlock[] = [];
  const logs: DecisionLog[] = [];

  // Sort tasks deterministically for placement priority
  const sortedTasks = [...tasks].sort((a, b) => {
    return priorities[b.id].score - priorities[a.id].score;
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
        const key = dayKey(slot.start);

        // Check per-day quota
        const allocatedToday = dailyAllocatedSlots[key] ?? 0;
        const dayQuotaReached = allocatedToday >= maxDailySlotsForTask;

        // Ensure the slot is valid for this task
        const canUse = slot.available
          && (!energyRequired || slot.energyBonus)
          && slot.start >= now
          && slot.end <= task.deadline
          && !dayQuotaReached;

        if (canUse) {
          currentChunk.push(slot);
          if (currentChunk.length === MAX_CHUNK_SLOTS || currentChunk.length === remainingSlots) {
            // Check if committing this chunk would violate daily quota
            const chunkDayKey = dayKey(currentChunk[0].start);
            const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
            const wouldExceedDailyQuota = currentChunk.length > (maxDailySlotsForTask - allocatedThisDay);
            
            if (wouldExceedDailyQuota && maxDailySlotsForTask !== Infinity) {
              // Trim the chunk to the remaining daily quota
              const allowed = maxDailySlotsForTask - allocatedThisDay;
              if (allowed > 0) {
                const trimmedChunk = currentChunk.slice(0, allowed);
                commitChunk(trimmedChunk, task, blocks);
                trimmedChunk.forEach(s => s.available = false);
                placedSlots += trimmedChunk.length;
                remainingSlots -= trimmedChunk.length;
                dailyAllocatedSlots[chunkDayKey] = maxDailySlotsForTask; // day is now full for this task
              }
              currentChunk = [];
            } else {
              // Commit full chunk
              commitChunk(currentChunk, task, blocks);
              currentChunk.forEach(s => s.available = false);
              placedSlots += currentChunk.length;
              remainingSlots -= currentChunk.length;
              const ck = dayKey(currentChunk[0].start);
              dailyAllocatedSlots[ck] = (dailyAllocatedSlots[ck] ?? 0) + currentChunk.length;
              currentChunk = [];
            }
          }
        } else {
          // Break in availability — commit any partial chunk we've built
          if (currentChunk.length >= MIN_CHUNK_SLOTS) {
            const chunkDayKey = dayKey(currentChunk[0].start);
            const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
            const allowedInChunk = maxDailySlotsForTask !== Infinity
              ? Math.min(currentChunk.length, maxDailySlotsForTask - allocatedThisDay)
              : currentChunk.length;
            
            if (allowedInChunk > 0) {
              const trimmedChunk = currentChunk.slice(0, allowedInChunk);
              commitChunk(trimmedChunk, task, blocks);
              trimmedChunk.forEach(s => s.available = false);
              placedSlots += trimmedChunk.length;
              remainingSlots -= trimmedChunk.length;
              dailyAllocatedSlots[chunkDayKey] = (dailyAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
            }
          }
          currentChunk = [];
        }
      }
      
      // End of slots cleanup
      if (currentChunk.length >= MIN_CHUNK_SLOTS) {
        const chunkDayKey = dayKey(currentChunk[0].start);
        const allocatedThisDay = dailyAllocatedSlots[chunkDayKey] ?? 0;
        const allowedInChunk = maxDailySlotsForTask !== Infinity
          ? Math.min(currentChunk.length, maxDailySlotsForTask - allocatedThisDay)
          : currentChunk.length;
        
        if (allowedInChunk > 0) {
          const trimmedChunk = currentChunk.slice(0, allowedInChunk);
          commitChunk(trimmedChunk, task, blocks);
          trimmedChunk.forEach(s => s.available = false);
          placedSlots += trimmedChunk.length;
          remainingSlots -= trimmedChunk.length;
          dailyAllocatedSlots[chunkDayKey] = (dailyAllocatedSlots[chunkDayKey] ?? 0) + trimmedChunk.length;
        }
      }
    }

    // Determine reason code for logs
    const isLimitedByDailyTarget = task.dailyTargetMinutes != null
      && placedSlots < originalSlots
      && remainingSlots > 0;

    // Generate decision log
    if (placedSlots === originalSlots) {
      logs.push({
        taskId: task.id,
        decisionType: 'FULLY_SCHEDULED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: placedSlots * 30,
        deferredMinutes: 0,
        reasonCode: 'SUCCESS'
      });
    } else if (placedSlots > 0) {
      logs.push({
        taskId: task.id,
        decisionType: 'PARTIALLY_SCHEDULED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: placedSlots * 30,
        deferredMinutes: remainingSlots * 30,
        reasonCode: isLimitedByDailyTarget ? 'DAILY_TARGET_PACING' : 'FRAGMENTED_CAPACITY'
      });
    } else {
      logs.push({
        taskId: task.id,
        decisionType: 'DEFERRED',
        priorityScore: priorities[task.id].score,
        priorityComponents: priorities[task.id].components,
        scheduledMinutes: 0,
        deferredMinutes: originalSlots * 30,
        reasonCode: 'NO_AVAILABLE_SLOTS'
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
