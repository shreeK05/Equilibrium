import { scheduleRepo } from '../repositories/schedule.repo';
import { taskRepo } from '../repositories/task.repo';
import { constraintRepo } from '../repositories/constraint.repo';
import { FixedCommitmentRepository } from '../repositories/commitment.repo';
import { runReschedulerPipeline } from '../scheduler/rescheduler';
import { TaskInput, ConstraintInput, ScheduleBlock, FixedCommitment } from '../scheduler/types';

export class ScheduleService {
  async generateSchedule(userId: string, triggerType: string = 'MANUAL', now = new Date()) {
    const constraintsData = await constraintRepo.findByUserId(userId);
    if (!constraintsData) throw new Error('Constraints not found');

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      peakEnergyWindows: JSON.parse(constraintsData.peakEnergyWindowsJson)
    };

    const tasksData = await taskRepo.findActiveTasks(userId);
    const tasks: TaskInput[] = tasksData.map(t => ({
      id: t.id,
      estimateMinutes: t.estimateMinutes,
      completedMinutes: t.completedMinutes,
      remainingMinutes: Math.max(0, t.estimateMinutes - t.completedMinutes),
      deadline: t.deadline,
      academicWeight: t.academicWeight,
      teamImpact: t.teamImpactWeight,
      cognitiveLoad: t.cognitiveLoad as any,
      deferralCount: t.deferralCount
    }));

    // Calculate horizon (next 7 days)
    const horizonStart = new Date(now);
    horizonStart.setUTCHours(0,0,0,0);
    const horizonEnd = new Date(horizonStart.getTime() + 7 * 24 * 3600000);

    // Call mathematical scheduler
    const fixedData = await new FixedCommitmentRepository().findActive(userId, horizonStart, horizonEnd);
    const fixed: FixedCommitment[] = fixedData.map(f => ({
      id: f.id,
      start: f.startTime,
      end: f.endTime
    }));

    const result = runReschedulerPipeline(
      tasks,
      constraints,
      fixed,
      [], // No locked blocks for a fresh generation
      horizonStart,
      horizonEnd,
      now
    );

    const totalScheduled = result.logs.reduce((acc, l) => acc + l.scheduledMinutes, 0);

    return scheduleRepo.createSchedule(
      userId,
      triggerType,
      totalScheduled, // using total scheduled as a proxy for used capacity
      result.blocks,
      result.logs,
      undefined // No previous version for base generate
    );
  }

  async reschedule(userId: string, versionId: string, now = new Date()) {
    const oldVersion = await scheduleRepo.getVersion(versionId, userId);
    if (!oldVersion) throw new Error('Schedule version not found');

    const lockedBlocksData = await scheduleRepo.getLockedBlocks(versionId);
    
    // Convert to scheduler types
    const lockedBlocks: ScheduleBlock[] = lockedBlocksData.map(b => ({
      taskId: b.taskId || undefined,
      type: b.blockType as any,
      start: b.startTime,
      end: b.endTime,
      durationMinutes: b.durationMinutes,
      isLocked: true
    }));

    const constraintsData = await constraintRepo.findByUserId(userId);
    if (!constraintsData) throw new Error('Constraints not found');

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      peakEnergyWindows: JSON.parse(constraintsData.peakEnergyWindowsJson)
    };

    const tasksData = await taskRepo.findActiveTasks(userId);
    const tasks: TaskInput[] = tasksData.map(t => ({
      id: t.id,
      estimateMinutes: t.estimateMinutes,
      completedMinutes: t.completedMinutes,
      remainingMinutes: Math.max(0, t.estimateMinutes - t.completedMinutes),
      deadline: t.deadline,
      academicWeight: t.academicWeight,
      teamImpact: t.teamImpactWeight,
      cognitiveLoad: t.cognitiveLoad as any,
      deferralCount: t.deferralCount
    }));

    const horizonStart = new Date(now);
    horizonStart.setUTCHours(0,0,0,0);
    const horizonEnd = new Date(horizonStart.getTime() + 7 * 24 * 3600000);

    const fixedData = await new FixedCommitmentRepository().findActive(userId, horizonStart, horizonEnd);
    const fixed: FixedCommitment[] = fixedData.map(f => ({
      id: f.id,
      start: f.startTime,
      end: f.endTime
    }));

    const result = runReschedulerPipeline(
      tasks,
      constraints,
      fixed,
      lockedBlocks,
      horizonStart,
      horizonEnd,
      now
    );

    const totalScheduled = result.logs.reduce((acc, l) => acc + l.scheduledMinutes, 0);

    return scheduleRepo.createSchedule(
      userId,
      'DISRUPTION',
      totalScheduled,
      result.blocks,
      result.logs,
      versionId // Passes as previousVersionId to preserve history
    );
  }
}

export const scheduleService = new ScheduleService();
