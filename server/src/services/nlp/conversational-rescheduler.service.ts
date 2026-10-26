import { prisma } from '../../db';
import { scheduleService } from '../schedule.service';
import { scheduleRepo } from '../../repositories/schedule.repo';
import { taskRepo } from '../../repositories/task.repo';
import { resolveTimezone } from '../../scheduler/timezone';
import { format } from 'date-fns-tz';
import { z } from 'zod';
import { groqClient } from './groq-client.service';

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
  clarificationQuestion?: string;
  isAmbiguous?: boolean;
  source?: 'groq' | 'deterministic';
}

const groqIntentSchema = z.object({
  intent: z.enum([
    'CANNOT_STUDY_TONIGHT',
    'MISSED_TASK',
    'MOVE_TO_NEXT_SLOT',
    'REDUCED_CAPACITY_TODAY',
    'EXTRA_CLASS',
    'GENERAL_RESCHEDULE'
  ]),
  interpretation: z.string().optional(),
  summary: z.string().optional(),
  targetTaskHint: z.string().nullable().optional(),
  freeHours: z.number().int().positive().max(24).nullable().optional(),
  isAmbiguous: z.boolean().default(false),
  clarificationQuestion: z.string().nullable().optional(),
  isMateriallyDisruptive: z.boolean().default(false)
});

export class ConversationalReschedulerService {
  /**
   * Deterministic intent classification fallback
   */
  classifyIntent(message: string): { intent: RescheduleIntentType; details?: any } {
    const text = message.toLowerCase().trim();

    if (/\b(cannot study tonight|unable to study tonight|can't study tonight|no study tonight|tired tonight|off tonight|skip tonight|sick today|sick tonight)\b/.test(text)) {
      return { intent: 'CANNOT_STUDY_TONIGHT' };
    }

    if (/\b(could not finish|couldn't finish|missed this task|missed this session|didn't finish|catch up|incomplete)\b/.test(text)) {
      return { intent: 'MISSED_TASK' };
    }

    if (/\b(move (?:this|the)?\s*(?:assignment|task)?\s*to (?:the )?next (?:available )?slot|postpone|push (?:this|it)|push back)\b/.test(text)) {
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
   * Leverages Groq LLM when available, falling back safely to deterministic logic.
   */
  async interpretAndPropose(
    userId: string,
    message: string,
    targetTaskId?: string,
    now: Date = new Date()
  ): Promise<RescheduleProposal> {
    const user = await prisma.user.findUnique({ where: { id: userId } });
    const tz = resolveTimezone(user?.timezone);

    const latestVersion = await scheduleRepo.getLatestVersion(userId);
    const activeTasks = await taskRepo.findActiveTasks(userId);
    const taskMap = new Map(activeTasks.map(t => [t.id, t]));

    // Check currently scheduled blocks for today
    const dayStr = format(now, 'yyyy-MM-dd', { timeZone: tz });
    const todayBlocks = (latestVersion?.blocks || []).filter(b => {
      const bDay = format(new Date(b.startTime), 'yyyy-MM-dd', { timeZone: tz });
      return bDay === dayStr && b.blockType === 'TASK' && new Date(b.endTime) > now;
    });

    let intent: RescheduleIntentType = 'GENERAL_RESCHEDULE';
    let details: any = undefined;
    let customInterpretation: string | undefined;
    let customSummary: string | undefined;
    let clarificationQuestion: string | undefined;
    let isAmbiguous = false;
    let isMateriallyDisruptive = false;
    let source: 'groq' | 'deterministic' = 'deterministic';

    // Try Groq LLM for intent classification if available
    if (groqClient.isConfigured()) {
      try {
        const taskSummaryList = activeTasks.slice(0, 10).map(t => `'${t.title}' (${t.remainingMinutes ?? t.estimateMinutes}m, due ${t.deadline.toISOString()})`).join('; ');
        const systemPrompt = `You are Equilibrium's conversational schedule adaptation assistant.
A student is explaining a change of plans, tiredness, illness, disruption, or rescheduling request in natural language.
Current time: ${now.toISOString()} in timezone ${tz}
Student's active tasks: ${taskSummaryList || 'None'}

Return a valid JSON object matching this schema:
{
  "intent": "CANNOT_STUDY_TONIGHT" | "MISSED_TASK" | "MOVE_TO_NEXT_SLOT" | "REDUCED_CAPACITY_TODAY" | "EXTRA_CLASS" | "GENERAL_RESCHEDULE",
  "interpretation": "1 clear sentence explaining what the student communicated",
  "summary": "1 clear sentence proposing the schedule adjustment",
  "targetTaskHint": "name of target task if mentioned, else null",
  "freeHours": number if reduced capacity requested, else null,
  "isAmbiguous": boolean (true if the request is too vague or missing details),
  "clarificationQuestion": "friendly question to clarify intent if isAmbiguous, else null",
  "isMateriallyDisruptive": boolean (true if clearing or shifting today's active study blocks)
}

Rules:
1. CANNOT_STUDY_TONIGHT: student is sick, tired, taking tonight off, or unable to study tonight.
2. MISSED_TASK: student missed a session or task and wants to catch up.
3. MOVE_TO_NEXT_SLOT: student wants to postpone a specific task to the next slot.
4. REDUCED_CAPACITY_TODAY: student has only limited hours free today.
5. EXTRA_CLASS: student has an extra college lecture or commitment.
6. GENERAL_RESCHEDULE: general replan or optimize.
7. If vague (e.g., 'not feeling it', 'reschedule something'), set isAmbiguous: true and ask a clarification question.
8. Only output valid JSON.`;

        const groqRes = await groqClient.chatCompletionJson(
          [
            { role: 'system', content: systemPrompt },
            { role: 'user', content: message.trim() }
          ],
          { userId, timeoutMs: 7000 }
        );

        if (groqRes.success && groqRes.data) {
          const validated = groqIntentSchema.safeParse(groqRes.data);
          if (validated.success) {
            intent = validated.data.intent;
            customInterpretation = validated.data.interpretation;
            customSummary = validated.data.summary;
            clarificationQuestion = validated.data.clarificationQuestion || undefined;
            isAmbiguous = validated.data.isAmbiguous;
            if (validated.data.isMateriallyDisruptive) {
              isMateriallyDisruptive = true;
            }
            if (validated.data.freeHours) {
              details = { freeHours: validated.data.freeHours };
            }
            if (validated.data.targetTaskHint && !targetTaskId) {
              // Try to find matching task by title
              const hintLower = validated.data.targetTaskHint.toLowerCase();
              const found = activeTasks.find(t => t.title.toLowerCase().includes(hintLower));
              if (found) targetTaskId = found.id;
            }
            source = 'groq';
          }
        }
      } catch {
        // Fall back gracefully to deterministic logic
      }
    }

    // Fallback to deterministic classification if Groq was not used
    if (source === 'deterministic') {
      const classified = this.classifyIntent(message);
      intent = classified.intent;
      details = classified.details;
    }

    let interpretation = customInterpretation || '';
    let summary = customSummary || '';
    const consequences: string[] = [];
    let affectedTaskIds: string[] = [];

    switch (intent) {
      case 'CANNOT_STUDY_TONIGHT': {
        isMateriallyDisruptive = true;
        if (!interpretation) {
          interpretation = "Detected intent: Clear tonight's remaining study sessions and replan work starting tomorrow morning.";
        }
        affectedTaskIds = Array.from(new Set(todayBlocks.map(b => b.taskId).filter(Boolean) as string[]));
        const affectedTitles = affectedTaskIds.map(id => taskMap.get(id)?.title).filter(Boolean);

        if (affectedTaskIds.length === 0) {
          summary = "No study blocks were planned for tonight. Your schedule is already clear.";
        } else {
          if (!summary) {
            summary = `Shifting ${todayBlocks.length} planned session(s) (${affectedTitles.join(', ')}) forward to tomorrow.`;
          }

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
        if (!interpretation) {
          interpretation = `Detected intent: Replan missed work for '${task?.title || 'active tasks'}' from the current time.`;
        }
        if (taskId) affectedTaskIds = [taskId];
        if (!summary) {
          summary = task 
            ? `Preserves your recorded progress and replans the remaining ${task.remainingMinutes ?? task.estimateMinutes}m for '${task.title}' into the next feasible focus slots.`
            : "Recalculates all active incomplete tasks from the current time.";
        }
        break;
      }

      case 'MOVE_TO_NEXT_SLOT': {
        const taskId = targetTaskId || (todayBlocks.length > 0 ? todayBlocks[0].taskId : undefined);
        const task = taskId ? taskMap.get(taskId) : undefined;
        if (!interpretation) {
          interpretation = `Detected intent: Move '${task?.title || 'current task'}' to the next available study slot.`;
        }
        if (taskId) affectedTaskIds = [taskId];
        if (!summary) {
          summary = task
            ? `Defers current session for '${task.title}' and finds the next unallocated study window prior to its deadline.`
            : "Moves the next task forward in your schedule.";
        }
        break;
      }

      case 'REDUCED_CAPACITY_TODAY': {
        const freeH = details?.freeHours ?? 1;
        if (!interpretation) {
          interpretation = `Detected intent: Restrict study time today to ${freeH} hour(s) and distribute overflow work to upcoming days.`;
        }
        if (!summary) {
          summary = `Caps study sessions today at ${freeH * 60}m. Excess workload will be comfortably paced over tomorrow and subsequent days.`;
        }
        affectedTaskIds = Array.from(new Set(todayBlocks.map(b => b.taskId).filter(Boolean) as string[]));
        isMateriallyDisruptive = true;
        break;
      }

      case 'EXTRA_CLASS': {
        if (!interpretation) {
          interpretation = "Detected intent: Accommodate an extra college lecture or commitment.";
        }
        if (!summary) {
          summary = "Protects your college lecture time block and recalculates study sessions to prevent schedule collisions.";
        }
        break;
      }

      default: {
        if (!interpretation) {
          interpretation = "Detected intent: Replan schedule to optimize workload.";
        }
        if (!summary) {
          summary = "Recalculates your schedule considering deadlines, protected sleep, meals, and academic priorities.";
        }
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
      requiresConfirmation: isMateriallyDisruptive || consequences.length > 0 || isAmbiguous,
      newCapacityScheduledMinutes: latestVersion?.capacityMinutes ?? 0,
      deferredTaskCount: 0,
      clarificationQuestion,
      isAmbiguous,
      source
    };
  }

  /**
   * Execute the rescheduling once user confirms or when changes are non-disruptive.
   * Strictly uses backend scheduling engine. Never allows LLM to directly write blocks.
   */
  async applyReschedule(
    userId: string,
    intent: RescheduleIntentType,
    targetTaskId?: string,
    now: Date = new Date()
  ) {
    const newVersion = await scheduleService.replan(userId, `CONVERSATIONAL_${intent}`, now);
    return newVersion;
  }
}

export const conversationalRescheduler = new ConversationalReschedulerService();
