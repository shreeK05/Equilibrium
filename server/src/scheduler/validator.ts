import { ScheduleBlock, ConstraintInput, FixedCommitment, TaskInput } from './types';
import { intervalsIntersect, parseTimeStrToDate } from './guard';
import { format } from 'date-fns-tz';

export function validateSchedule(
  blocks: ScheduleBlock[],
  constraints: ConstraintInput,
  fixed: FixedCommitment[],
  tasks: TaskInput[]
): boolean {
  const taskMap = new Map(tasks.map(t => [t.id, t]));
  const durationMap = new Map<string, number>();
  const bufferMinutes = constraints.bufferMinutes ?? 0;

  for (const block of blocks) {
    if (block.type !== 'TASK') continue;
    if (block.durationMinutes <= 0) return false;
    
    if (block.taskId) {
      const task = taskMap.get(block.taskId);
      if (!block.isLocked) {
        if (!task) { console.log('Validation failed: task not found', block.taskId); return false; }
        if (block.end > task.deadline) { console.log('Validation failed: past deadline', block); return false; }
        durationMap.set(block.taskId, (durationMap.get(block.taskId) || 0) + block.durationMinutes);
      }
    }

    // Check Sleep Overlap for the day of the block
    const tz = constraints.timezone || 'Asia/Kolkata';
    const dayStr = format(block.start, 'yyyy-MM-dd', { timeZone: tz });

    let sleepStart = parseTimeStrToDate(dayStr, constraints.sleepStart, tz);
    let sleepEnd = parseTimeStrToDate(dayStr, constraints.sleepEnd, tz);
    if (sleepEnd <= sleepStart) {
      sleepEnd = new Date(sleepEnd.getTime() + 24 * 60 * 60000);
    }
    
    // Also check previous day's crossing sleep
    let prevSleepStart = new Date(sleepStart.getTime() - 24 * 60 * 60000);
    let prevSleepEnd = new Date(sleepEnd.getTime() - 24 * 60 * 60000);

    if (intervalsIntersect(block.start, block.end, sleepStart, sleepEnd)) { console.log('Validation failed: sleep overlap 1', block); return false; }
    if (intervalsIntersect(block.start, block.end, prevSleepStart, prevSleepEnd)) { console.log('Validation failed: sleep overlap 2', block); return false; }

    // Check Fixed Overlap
    for (const f of fixed) {
        const bufferBefore = new Date(f.start.getTime() - bufferMinutes * 60000);
        const bufferAfter = new Date(f.end.getTime() + bufferMinutes * 60000);
        if (intervalsIntersect(block.start, block.end, bufferBefore, bufferAfter)) { console.log('Validation failed: fixed overlap', block, f); return false; }
    }
  }

  // Check scheduled <= remaining (allowing rounding up to 30 min block)
  for (const [taskId, scheduled] of durationMap.entries()) {
    const task = taskMap.get(taskId);
    if (task) {
      const allowedScheduled = Math.ceil(task.remainingMinutes / 30) * 30;
      if (scheduled > allowedScheduled) {
        console.log('Validation failed: scheduled > remaining for', taskId);
        return false;
      }
    }
  }

  // Check self overlap
  for (let i = 0; i < blocks.length; i++) {
    for (let j = i + 1; j < blocks.length; j++) {
      // Allow edge touching (end == start)
      if (blocks[i].end <= blocks[j].start || blocks[i].start >= blocks[j].end) continue;
      
      if (intervalsIntersect(blocks[i].start, blocks[i].end, blocks[j].start, blocks[j].end)) {
        console.log('Validation failed: self overlap between', blocks[i], 'and', blocks[j]);
        return false;
      }
    }
  }
  return true;
}
