import { prisma } from '../db';
import { scheduleService } from './schedule.service';

const TOPIC_TYPE_LABEL: Record<string, string> = {
  LEARNING: 'Learning',
  REVISION: 'Revision',
  PYQ: 'PYQ Practice',
  MOCK_TEST: 'Mock Test',
  WEAK_TOPIC: 'Weak Topic',
};

/** Legacy title format that dropped topicType — kept only to detect and repair old tasks. */
export function legacyTopicTaskTitle(examTitle: string, topicTitle: string): string {
  return `${examTitle} — ${topicTitle}`;
}

/**
 * Build a task title that keeps the part that makes a topic distinct.
 * Two topics both named "unit 1" (one LEARNING, one REVISION) must not collapse into the same title,
 * so the topic type is appended unless the user already wrote it into the topic name.
 *   ("OS written exam", "unit 1", "REVISION") -> "OS written exam — Unit 1 · Revision"
 *   ("OS", "Unit 3 revision", "REVISION")      -> "OS — Unit 3 revision"
 */
export function buildTopicTaskTitle(examTitle: string, topicTitle: string, topicType: string): string {
  const label = TOPIC_TYPE_LABEL[topicType] ?? topicType.charAt(0) + topicType.slice(1).toLowerCase();
  const raw = topicTitle.trim();
  const topic = raw.charAt(0).toUpperCase() + raw.slice(1);
  const firstWord = label.split(' ')[0].toLowerCase();
  const alreadyLabelled = topic.toLowerCase().includes(firstWord);
  const core = alreadyLabelled ? topic : `${topic} · ${label}`;
  return `${examTitle.trim()} — ${core}`;
}

function uniquify(title: string, taken: Set<string>): string {
  if (!taken.has(title)) return title;
  let n = 2;
  while (taken.has(`${title} (${n})`)) n++;
  return `${title} (${n})`;
}

export class ExamPrepService {
  /**
   * Converts an exam's open topics into Tasks, then re-plans the calendar.
   * This service never writes ScheduleBlocks itself: placement goes through
   * scheduleService.replan -> loadContext -> runReschedulerPipeline (Knapsack + Sleep Shield + validator),
   * exactly like every other scheduling trigger.
   */
  async scheduleTopics(userId: string, examId: string, now = new Date()) {
    const exam = await prisma.exam.findFirst({
      where: { id: examId, userId },
      include: { topics: true },
    });
    if (!exam) return null;

    const takenTitles = new Set<string>();
    const createdTasks: any[] = [];
    let tasksRenamed = 0;

    // Repair tasks created with the old, type-less title so existing users get distinct names too.
    for (const topic of exam.topics) {
      if (!topic.linkedTaskId) continue;
      const linked = await prisma.task.findUnique({ where: { id: topic.linkedTaskId } });
      if (!linked) continue;
      if (linked.title === legacyTopicTaskTitle(exam.title, topic.title)) {
        const title = uniquify(buildTopicTaskTitle(exam.title, topic.title, topic.topicType), takenTitles);
        await prisma.task.update({ where: { id: linked.id }, data: { title } });
        takenTitles.add(title);
        tasksRenamed++;
      } else {
        takenTitles.add(linked.title);
      }
    }

    for (const topic of exam.topics) {
      if (topic.isCompleted || topic.linkedTaskId) continue;
      const title = uniquify(buildTopicTaskTitle(exam.title, topic.title, topic.topicType), takenTitles);
      takenTitles.add(title);

      const task = await prisma.task.create({
        data: {
          userId,
          subjectId: exam.subjectId ?? null,
          title,
          description: `${TOPIC_TYPE_LABEL[topic.topicType] ?? topic.topicType} session for ${exam.title}`,
          category: 'Exam Prep',
          estimateMinutes: topic.estimateMinutes,
          deadline: exam.examDate,
          deadlineType: 'HARD',
          academicWeight: 0.9, // exam prep gets high academic weight
          cognitiveLoad: topic.topicType === 'MOCK_TEST' ? 'HIGH' : 'MEDIUM',
        },
      });
      await prisma.examTopic.update({ where: { id: topic.id }, data: { linkedTaskId: task.id } });
      createdTasks.push(task);
    }

    let schedule: { versionId: string; blocksPlaced: number } | null = null;
    let scheduleError: string | null = null;
    if (createdTasks.length > 0 || tasksRenamed > 0) {
      try {
        const version: any = await scheduleService.replan(userId, 'EXAM_PREP', now);
        schedule = { versionId: version.id, blocksPlaced: version.blocks?.length ?? 0 };
      } catch (err: any) {
        scheduleError = err?.message ?? 'Scheduling failed';
      }
    }

    return { tasksCreated: createdTasks.length, tasks: createdTasks, tasksRenamed, schedule, scheduleError };
  }
}

export const examPrepService = new ExamPrepService();
