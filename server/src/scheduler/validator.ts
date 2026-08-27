import { ScheduleBlock, ConstraintInput, FixedCommitment, TaskInput } from './types';
import { intervalsIntersect, parseTimeStrToDate } from './guard';

export function validateSchedule(
  blocks: ScheduleBlock[],
  constraints: ConstraintInput,
  fixed: FixedCommitment[],
  tasks: TaskInput[]
): boolean {
  const taskMap = new Map(tasks.map(t => [t.id, t]));
  const durationMap = new Map<string, number>();

  for (const block of blocks) {
    if (block.type !== 'TASK') continue;
    if (block.durationMinutes <= 0) return false;
    
    if (block.taskId) {
      const task = taskMap.get(block.taskId);
      if (!block.isLocked) {
        if (!task) return false;
        if (block.end > task.deadline) return false;
        durationMap.set(block.taskId, (durationMap.get(block.taskId) || 0) + block.durationMinutes);
      }
    }

    // Check Sleep Overlap for the day of the block
    const baseDate = new Date(block.start);
    baseDate.setUTCHours(0, 0, 0, 0);

    let sleepStart = parseTimeStrToDate(baseDate, constraints.sleepStart);
    let sleepEnd = parseTimeStrToDate(baseDate, constraints.sleepEnd);
    if (sleepEnd <= sleepStart) {
      sleepEnd = new Date(sleepEnd.getTime() + 24 * 60 * 60000);
    }
    
    // Also check previous day's crossing sleep
    let prevSleepStart = new Date(sleepStart.getTime() - 24 * 60 * 60000);
    let prevSleepEnd = new Date(sleepEnd.getTime() - 24 * 60 * 60000);

    if (intervalsIntersect(block.start, block.end, sleepStart, sleepEnd)) return false;
    if (intervalsIntersect(block.start, block.end, prevSleepStart, prevSleepEnd)) return false;

    // Check Fixed Overlap
    for (const f of fixed) {
      if (intervalsIntersect(block.start, block.end, f.start, f.end)) return false;
    }
  }

  // Check scheduled <= remaining
  for (const [taskId, scheduled] of durationMap.entries()) {
    const task = taskMap.get(taskId);
    if (task && scheduled > task.remainingMinutes) return false;
  }

  // Check self overlap
  for (let i = 0; i < blocks.length; i++) {
    for (let j = i + 1; j < blocks.length; j++) {
      // Allow edge touching (end == start)
      if (blocks[i].end <= blocks[j].start || blocks[i].start >= blocks[j].end) continue;
      
      if (intervalsIntersect(blocks[i].start, blocks[i].end, blocks[j].start, blocks[j].end)) {
        return false;
      }
    }
  }
  return true;
}
