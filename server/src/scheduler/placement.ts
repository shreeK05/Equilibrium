import { Slot } from './capacity';
import { TaskInput, ScheduleBlock, DecisionLog } from './types';

export const MIN_CHUNK_SLOTS = 1; // 30 min
export const MAX_CHUNK_SLOTS = 8; // 4 hours

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
        // Ensure the slot is valid for this task
        const canUse = slot.available && (!energyRequired || slot.energyBonus) && slot.start >= now && slot.end <= task.deadline;

        if (canUse) {
          currentChunk.push(slot);
          if (currentChunk.length === MAX_CHUNK_SLOTS || currentChunk.length === remainingSlots) {
            // Commit chunk
            commitChunk(currentChunk, task, blocks);
            currentChunk.forEach(s => s.available = false);
            placedSlots += currentChunk.length;
            remainingSlots -= currentChunk.length;
            currentChunk = [];
          }
        } else {
          // Break in availability
          if (currentChunk.length >= MIN_CHUNK_SLOTS) {
            commitChunk(currentChunk, task, blocks);
            currentChunk.forEach(s => s.available = false);
            placedSlots += currentChunk.length;
            remainingSlots -= currentChunk.length;
          }
          currentChunk = [];
        }
      }
      
      // End of slots cleanup
      if (currentChunk.length >= MIN_CHUNK_SLOTS) {
        commitChunk(currentChunk, task, blocks);
        currentChunk.forEach(s => s.available = false);
        placedSlots += currentChunk.length;
        remainingSlots -= currentChunk.length;
      }
    }

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
        reasonCode: 'FRAGMENTED_CAPACITY'
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
