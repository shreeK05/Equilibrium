import { scheduleRepo } from '../repositories/schedule.repo';
import { taskRepo } from '../repositories/task.repo';
import { constraintRepo } from '../repositories/constraint.repo';
import { FixedCommitmentRepository } from '../repositories/commitment.repo';
import { runReschedulerPipeline } from '../scheduler/rescheduler';
import { TaskInput, ConstraintInput, ScheduleBlock, FixedCommitment } from '../scheduler/types';

export class ScheduleService {
  async simulateSchedule(userId: string, proposedTask: {
    title: string;
    estimateMinutes: number;
    deadline: string;
    academicWeight?: number;
    teamImpactWeight?: number;
    cognitiveLoad?: string;
  }, now = new Date()) {
    const constraintsData = await constraintRepo.findByUserId(userId);
    if (!constraintsData) throw new Error('Constraints not found');

    let peakEnergyWindows: ConstraintInput['peakEnergyWindows'];
    try {
      peakEnergyWindows = JSON.parse(constraintsData.peakEnergyWindowsJson);
      if (!Array.isArray(peakEnergyWindows)) throw new Error('must be an array');
    } catch {
      throw new Error('Stored peak energy windows are invalid; update constraints before simulating a schedule');
    }

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      bufferMinutes: constraintsData.bufferMinutes,
      peakEnergyWindows
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
    tasks.push({
      id: 'simulation-task',
      estimateMinutes: proposedTask.estimateMinutes,
      completedMinutes: 0,
      remainingMinutes: proposedTask.estimateMinutes,
      deadline: new Date(proposedTask.deadline),
      academicWeight: proposedTask.academicWeight ?? 0.5,
      teamImpact: proposedTask.teamImpactWeight ?? 0,
      cognitiveLoad: (proposedTask.cognitiveLoad ?? 'MEDIUM') as any,
      deferralCount: 0
    });

    const horizonStart = new Date(now);
    horizonStart.setUTCHours(0, 0, 0, 0);
    const horizonEnd = new Date(horizonStart.getTime() + 7 * 24 * 3600000);
    const fixedData = await new FixedCommitmentRepository().findActive(userId, horizonStart, horizonEnd);
    const fixed: FixedCommitment[] = fixedData.map(f => ({ id: f.id, start: f.startTime, end: f.endTime }));
    const result = runReschedulerPipeline(tasks, constraints, fixed, [], horizonStart, horizonEnd, now);
    const proposedLog = result.logs.find(log => log.taskId === 'simulation-task');

    return {
      fits: proposedLog?.decisionType === 'FULLY_SCHEDULED',
      decisionType: proposedLog?.decisionType ?? 'DEFERRED',
      reasonCode: proposedLog?.reasonCode ?? 'CAPACITY_EXCEEDED',
      scheduledMinutes: proposedLog?.scheduledMinutes ?? 0,
      deferredMinutes: proposedLog?.deferredMinutes ?? proposedTask.estimateMinutes,
      scheduledMinutesTotal: result.logs.reduce((total, log) => total + log.scheduledMinutes, 0),
      deferredTaskCount: result.logs.filter(log => log.decisionType === 'DEFERRED').length,
      blocks: result.blocks.filter(block => block.taskId === 'simulation-task').map(block => ({
        startTime: block.start.toISOString(),
        endTime: block.end.toISOString(),
        durationMinutes: block.durationMinutes
      }))
    };
  }

  async generateSchedule(userId: string, triggerType: string = 'MANUAL', now = new Date()) {
    const constraintsData = await constraintRepo.findByUserId(userId);
    if (!constraintsData) throw new Error('Constraints not found');

    let peakEnergyWindows: ConstraintInput['peakEnergyWindows'];
    try {
      peakEnergyWindows = JSON.parse(constraintsData.peakEnergyWindowsJson);
      if (!Array.isArray(peakEnergyWindows)) throw new Error('must be an array');
    } catch {
      throw new Error('Stored peak energy windows are invalid; update constraints before generating a schedule');
    }

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      bufferMinutes: constraintsData.bufferMinutes,
      peakEnergyWindows
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

    let peakEnergyWindows: ConstraintInput['peakEnergyWindows'];
    try {
      peakEnergyWindows = JSON.parse(constraintsData.peakEnergyWindowsJson);
      if (!Array.isArray(peakEnergyWindows)) throw new Error('must be an array');
    } catch {
      throw new Error('Stored peak energy windows are invalid; update constraints before rescheduling');
    }

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      bufferMinutes: constraintsData.bufferMinutes,
      peakEnergyWindows
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
