import { scheduleRepo } from '../repositories/schedule.repo';
import { taskRepo } from '../repositories/task.repo';
import { constraintRepo } from '../repositories/constraint.repo';
import { FixedCommitmentRepository } from '../repositories/commitment.repo';
import { userRepo } from '../repositories/user.repo';
import { runReschedulerPipeline } from '../scheduler/rescheduler';
import { resolveTimezone } from '../scheduler/timezone';
import { TaskInput, ConstraintInput, ScheduleBlock, FixedCommitment } from '../scheduler/types';
import { toDate, format } from 'date-fns-tz';

/**
 * Everything the pipeline needs, built in exactly one place so no entry point can
 * construct its own (possibly wrong) constraints — e.g. a sleep window in the wrong timezone.
 */
interface SchedulingContext {
  constraints: ConstraintInput;
  tasks: TaskInput[];
  fixed: FixedCommitment[];
  horizonStart: Date;
  horizonEnd: Date;
}

export class ScheduleService {
  /** The ONLY place ConstraintInput / horizon / task inputs are assembled for the scheduler. */
  private async loadContext(userId: string, now: Date): Promise<SchedulingContext> {
    const constraintsData = await constraintRepo.findByUserId(userId);
    if (!constraintsData) throw new Error('Constraints not found');

    let peakEnergyWindows: ConstraintInput['peakEnergyWindows'];
    try {
      peakEnergyWindows = JSON.parse(constraintsData.peakEnergyWindowsJson);
      if (!Array.isArray(peakEnergyWindows)) throw new Error('must be an array');
    } catch {
      throw new Error('Stored peak energy windows are invalid; update constraints before scheduling');
    }

    const user = await userRepo.findById(userId);
    if (!user) throw new Error('User not found');
    const timezone = resolveTimezone(user.timezone);

    const constraints: ConstraintInput = {
      sleepStart: constraintsData.sleepStart,
      sleepEnd: constraintsData.sleepEnd,
      minSleepHours: constraintsData.minSleepHours,
      bufferMinutes: constraintsData.bufferMinutes,
      peakEnergyWindows,
      timezone
    };

    const tasksData = await taskRepo.findActiveTasks(userId);
    const tasks: TaskInput[] = tasksData.map(t => ({
      id: t.id,
      title: t.title,
      estimateMinutes: t.estimateMinutes,
      completedMinutes: t.completedMinutes,
      remainingMinutes: Math.max(0, t.estimateMinutes - t.completedMinutes),
      deadline: t.deadline,
      academicWeight: t.academicWeight,
      teamImpact: t.teamImpactWeight,
      cognitiveLoad: t.cognitiveLoad as any,
      deferralCount: t.deferralCount,
      dailyTargetMinutes: (t as any).dailyTargetMinutes ?? null
    }));

    // Horizon (next 7 days) aligned to the user's local midnight
    const dayStr = format(now, 'yyyy-MM-dd', { timeZone: timezone });
    const horizonStart = toDate(`${dayStr}T00:00:00`, { timeZone: timezone });
    const horizonEnd = new Date(horizonStart.getTime() + 7 * 24 * 3600000);

    const fixedData = await new FixedCommitmentRepository().findActive(userId, horizonStart, horizonEnd);
    const fixed: FixedCommitment[] = fixedData.map(f => ({ id: f.id, start: f.startTime, end: f.endTime }));

    return { constraints, tasks, fixed, horizonStart, horizonEnd };
  }

  async simulateSchedule(userId: string, proposedTask: {
    title: string;
    estimateMinutes: number;
    deadline: string;
    academicWeight?: number;
    teamImpactWeight?: number;
    cognitiveLoad?: string;
  }, now = new Date()) {
    const ctx = await this.loadContext(userId, now);
    const tasks = [...ctx.tasks, {
      id: 'simulation-task',
      title: proposedTask.title,
      estimateMinutes: proposedTask.estimateMinutes,
      completedMinutes: 0,
      remainingMinutes: proposedTask.estimateMinutes,
      deadline: new Date(proposedTask.deadline),
      academicWeight: proposedTask.academicWeight ?? 0.5,
      teamImpact: proposedTask.teamImpactWeight ?? 0,
      cognitiveLoad: (proposedTask.cognitiveLoad ?? 'MEDIUM') as any,
      deferralCount: 0
    }];

    const result = runReschedulerPipeline(tasks, ctx.constraints, ctx.fixed, [], ctx.horizonStart, ctx.horizonEnd, now);
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
    const ctx = await this.loadContext(userId, now);
    const result = runReschedulerPipeline(
      ctx.tasks, ctx.constraints, ctx.fixed,
      [], // No locked blocks for a fresh generation
      ctx.horizonStart, ctx.horizonEnd, now
    );
    const totalScheduled = result.logs.reduce((acc, l) => acc + l.scheduledMinutes, 0);
    return scheduleRepo.createSchedule(
      userId, triggerType,
      totalScheduled, // using total scheduled as a proxy for used capacity
      result.blocks, result.logs,
      undefined // No previous version for base generate
    );
  }

  async reschedule(userId: string, versionId: string, now = new Date(), triggerType: string = 'DISRUPTION') {
    const oldVersion = await scheduleRepo.getVersion(versionId, userId);
    if (!oldVersion) throw new Error('Schedule version not found');

    const lockedBlocksData = await scheduleRepo.getLockedBlocks(versionId);
    const lockedBlocks: ScheduleBlock[] = lockedBlocksData.map(b => ({
      taskId: b.taskId || undefined,
      type: b.blockType as any,
      start: b.startTime,
      end: b.endTime,
      durationMinutes: b.durationMinutes,
      isLocked: true
    }));

    const ctx = await this.loadContext(userId, now);
    const result = runReschedulerPipeline(
      ctx.tasks, ctx.constraints, ctx.fixed, lockedBlocks,
      ctx.horizonStart, ctx.horizonEnd, now
    );
    const totalScheduled = result.logs.reduce((acc, l) => acc + l.scheduledMinutes, 0);
    return scheduleRepo.createSchedule(
      userId, triggerType, totalScheduled,
      result.blocks, result.logs,
      versionId // Passes as previousVersionId to preserve history
    );
  }

  /**
   * Re-plan the user's calendar after their workload changed (e.g. exam topics were added).
   * Keeps locked blocks from the latest version if one exists; otherwise generates fresh.
   * Either way it goes through loadContext + runReschedulerPipeline — there is no other path.
   */
  async replan(userId: string, triggerType: string, now = new Date()) {
    const latest = await scheduleRepo.getLatestVersion(userId);
    return latest
      ? this.reschedule(userId, latest.id, now, triggerType)
      : this.generateSchedule(userId, triggerType, now);
  }
}

export const scheduleService = new ScheduleService();
