import { prisma } from '../../db';
import { scheduleService } from '../schedule.service';
import { scheduleRepo } from '../../repositories/schedule.repo';
import { taskRepo } from '../../repositories/task.repo';
import { resolveTimezone } from '../../scheduler/timezone';
import { format, toDate } from 'date-fns-tz';

export type RescheduleIntentType =
  | 'CANNOT_STUDY_TONIGHT'
  | 'MISSED_TASK'
  | 'MOVE_TO_NEXT_SLOT'
  | 'REDUCED_CAPACITY_TODAY'
  | 'EXTRA_CLASS'
  | 'GENERAL_RESCHEDULE';

export interface RescheduleProposal {
  intent: RescheduleIntentType;
  interpretation: string;
  affectedTaskIds: string[];
  affectedTaskTitles: string[];
  summary: string;
  consequences: string[];
  isMateriallyDisruptive: boolean;
  requiresConfirmation: boolean;
  newCapacityScheduledMinutes: number;
  deferredTaskCount: number;
  proposedVersionId?: string;
}

export class ConversationalReschedulerService {
  /**
   * Classify user's natural language statement into structured intent.
   */
  classifyIntent(message: string): { intent: RescheduleIntentType; details?: any } {
    const text = message.toLowerCase().trim();

    if (/\b(cannot study tonight|unable to study tonight|can't study tonight|no study tonight|tired tonight|off tonight|skip tonight)\b/.test(text)) {
      return { intent: 'CANNOT_STUDY_TONIGHT' };
    }

    if (/\b(could not finish|couldn't finish|missed this task|missed this session|didn't finish|catch up|incomplete)\b/.test(text)) {
      return { intent: 'MISSED_TASK' };
    }

    if (/\b(move (?:this|the)?\s*(?:assignment|task)?\s*to (?:the )?next (?:available )?slot|postpone|push (?:this|it))\b/.test(text)) {
      return { intent: 'MOVE_TO_NEXT_SLOT' };
    }

    const freeHourMatch = text.match(/\b(?:only|have)\s+(\d+)\s*(?:h|hr|hours?)\s*(?:free|available)\s*(?:today)?\b/);
    if (freeHourMatch) {
      return { intent: 'REDUCED_CAPACITY_TODAY', details: { freeHours: parseInt(freeHourMatch[1], 10) } };
    }

    if (/\b(extra (?:college )?lecture|extra class|new meeting|surprise test|lab session)\b/.test(text)) {
      return { intent: 'EXTRA_CLASS' };
    }

    return { intent: 'GENERAL_RESCHEDULE' };
  }

  /**
   * Interpret request, calculate preview schedule, explain proposed changes and consequences.
   */
  async interpretAndPropose(
    userId: string,
    message: string,
    targetTaskId?: string,
    now: Date = new Date()
  ): Promise<RescheduleProposal> {
    const { intent, details } = this.classifyIntent(message);
    const user = await prisma.user.findUnique({ where: { id: userId } });
    const tz = resolveTimezone(user?.timezone);

    const latestVersion = await scheduleRepo.getLatestVersion(userId);
    const activeTasks = await taskRepo.findActiveTasks(userId);
    const taskMap = new Map(activeTasks.map(t => [t.id, t]));

    let interpretation = '';
    let summary = '';
    const consequences: string[] = [];
    let affectedTaskIds: string[] = [];
    let isMateriallyDisruptive = false;

    // Check currently scheduled blocks for today
    const dayStr = format(now, 'yyyy-MM-dd', { timeZone: tz });
    const todayBlocks = (latestVersion?.blocks || []).filter(b => {
      const bDay = format(new Date(b.startTime), 'yyyy-MM-dd', { timeZone: tz });
      return bDay === dayStr && b.blockType === 'TASK' && new Date(b.endTime) > now;
    });

    switch (intent) {
      case 'CANNOT_STUDY_TONIGHT': {
        interpretation = "Detected intent: Clear tonight's remaining study sessions and replan work starting tomorrow morning.";
        affectedTaskIds = Array.from(new Set(todayBlocks.map(b => b.taskId).filter(Boolean) as string[]));
        const affectedTitles = affectedTaskIds.map(id => taskMap.get(id)?.title).filter(Boolean);

        if (affectedTaskIds.length === 0) {
          summary = "No study blocks were planned for tonight. Your schedule is already clear.";
        } else {
          summary = `Shifting ${todayBlocks.length} planned session(s) (${affectedTitles.join(', ')}) forward to tomorrow.`;
          isMateriallyDisruptive = true;

          // Check for impending morning deadlines
          for (const id of affectedTaskIds) {
            const t = taskMap.get(id);
            if (t) {
              const diffHours = (new Date(t.deadline).getTime() - now.getTime()) / 3600000;
              if (diffHours < 24) {
                consequences.push(`Warning: '${t.title}' is due within 24 hours (${format(new Date(t.deadline), 'EEE HH:mm', { timeZone: tz })}). Postponing tonight may leave tight turnaround tomorrow.`);
              }
            }
          }
        }
        break;
      }

      case 'MISSED_TASK': {
        const taskId = targetTaskId || (todayBlocks.length > 0 ? todayBlocks[0].taskId : undefined);
        const task = taskId ? taskMap.get(taskId) : undefined;
        interpretation = `Detected intent: Replan missed work for '${task?.title || 'active tasks'}' from the current time.`;
        if (taskId) affectedTaskIds = [taskId];
        summary = task 
          ? `Preserves your recorded progress and replans the remaining ${task.remainingMinutes ?? task.estimateMinutes}m for '${task.title}' into the next feasible focus slots.`
          : "Recalculates all active incomplete tasks from the current time.";
        break;
      }

      case 'MOVE_TO_NEXT_SLOT': {
        const taskId = targetTaskId || (todayBlocks.length > 0 ? todayBlocks[0].taskId : undefined);
        const task = taskId ? taskMap.get(taskId) : undefined;
        interpretation = `Detected intent: Move '${task?.title || 'current task'}' to the next available study slot.`;
        if (taskId) affectedTaskIds = [taskId];
        summary = task
          ? `Defers current session for '${task.title}' and finds the next unallocated study window prior to its deadline.`
          : "Moves the next task forward in your schedule.";
        break;
      }

      case 'REDUCED_CAPACITY_TODAY': {
        const freeH = details?.freeHours ?? 1;
        interpretation = `Detected intent: Restrict study time today to ${freeH} hour(s) and distribute overflow work to upcoming days.`;
        summary = `Caps study sessions today at ${freeH * 60}m. Excess workload will be comfortably paced over tomorrow and subsequent days.`;
        affectedTaskIds = Array.from(new Set(todayBlocks.map(b => b.taskId).filter(Boolean) as string[]));
        isMateriallyDisruptive = true;
        break;
      }

      case 'EXTRA_CLASS': {
        interpretation = "Detected intent: Accommodate an extra college lecture or commitment.";
        summary = "Protects your college lecture time block and recalculates study sessions to prevent schedule collisions.";
        break;
      }

      default: {
        interpretation = "Detected intent: Replan schedule to optimize workload.";
        summary = "Recalculates your schedule considering deadlines, protected sleep, meals, and academic priorities.";
        break;
      }
    }

    const affectedTaskTitles = affectedTaskIds
      .map(id => taskMap.get(id)?.title)
      .filter((t): t is string => Boolean(t));

    return {
      intent,
      interpretation,
      affectedTaskIds,
      affectedTaskTitles,
      summary,
      consequences,
      isMateriallyDisruptive,
      requiresConfirmation: isMateriallyDisruptive || consequences.length > 0,
      newCapacityScheduledMinutes: latestVersion?.capacityMinutes ?? 0,
      deferredTaskCount: 0
    };
  }

  /**
   * Execute the rescheduling once user confirms or when changes are non-disruptive.
   */
  async applyReschedule(
    userId: string,
    intent: RescheduleIntentType,
    targetTaskId?: string,
    now: Date = new Date()
  ) {
    const latestVersion = await scheduleRepo.getLatestVersion(userId);
    const newVersion = await scheduleService.replan(userId, `CONVERSATIONAL_${intent}`, now);
    return newVersion;
  }
}

export const conversationalRescheduler = new ConversationalReschedulerService();
