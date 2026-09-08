import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';

export const dashboardRouter = Router();
dashboardRouter.use(authenticate);

// GET /api/v1/dashboard — real-time dashboard metrics
dashboardRouter.get('/', async (req: any, res, next) => {
  try {
    const userId = req.userId;
    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0);
    const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59);

    const [tasks, schedule, todaySessions, exams] = await Promise.all([
      prisma.task.findMany({
        where: { userId },
        select: {
          id: true, title: true, status: true, deadline: true,
          estimateMinutes: true, completedMinutes: true, deferralCount: true,
          cognitiveLoad: true, academicWeight: true
        }
      }),
      prisma.scheduleVersion.findFirst({
        where: { userId },
        orderBy: { generatedAt: 'desc' },
        include: {
          blocks: { orderBy: { startTime: 'asc' } }
        }
      }),
      prisma.focusSession.findMany({
        where: {
          userId,
          status: 'COMPLETED',
          startedAt: { gte: todayStart, lte: todayEnd }
        },
        select: { elapsedSeconds: true }
      }),
      prisma.exam.findMany({
        where: { userId, examDate: { gte: now } },
        orderBy: { examDate: 'asc' },
        take: 5,
        include: { topics: true }
      })
    ]);

    // Task metrics
    const completedTasks = tasks.filter(t => t.status === 'COMPLETED');
    const pendingTasks = tasks.filter(t => !['COMPLETED', 'ARCHIVED'].includes(t.status));
    const overdueTasks = pendingTasks.filter(t => new Date(t.deadline) < now);
    const dueTodayTasks = pendingTasks.filter(t => {
      const d = new Date(t.deadline);
      return d >= todayStart && d <= todayEnd;
    });
    const dueNext3DaysTasks = pendingTasks.filter(t => {
      const d = new Date(t.deadline);
      const threeDays = new Date(now.getTime() + 3 * 24 * 60 * 60 * 1000);
      return d >= now && d <= threeDays;
    });

    // Schedule metrics (today's blocks only)
    const todayBlocks = schedule?.blocks.filter(b => {
      const s = new Date(b.startTime);
      return s >= todayStart && s <= todayEnd;
    }) ?? [];
    const taskBlocksToday = todayBlocks.filter(b => b.blockType === 'TASK');
    const plannedMinutesToday = taskBlocksToday.reduce((sum, b) => sum + b.durationMinutes, 0);
    const completedBlocksToday = taskBlocksToday.filter(b => b.isCompleted);
    const completedBlockMinutesToday = completedBlocksToday.reduce((sum, b) => sum + b.durationMinutes, 0);

    // Focus time today from real sessions
    const focusSecondsToday = todaySessions.reduce((sum, s) => sum + s.elapsedSeconds, 0);
    const focusMinutesToday = Math.round(focusSecondsToday / 60);

    // Remaining workload
    const totalRemainingMinutes = pendingTasks.reduce(
      (sum, t) => sum + Math.max(0, t.estimateMinutes - t.completedMinutes), 0
    );
    const deferredTasksCount = pendingTasks.filter(t => t.deferralCount > 0).length;

    // Upcoming blocks (next 5 from schedule)
    const upcomingBlocks = (schedule?.blocks ?? [])
      .filter(b => new Date(b.startTime) > now && b.blockType === 'TASK')
      .slice(0, 5);

    // Exam countdowns
    const examCountdowns = exams.map(exam => {
      const daysLeft = Math.ceil((new Date(exam.examDate).getTime() - now.getTime()) / (1000 * 60 * 60 * 24));
      const totalTopics = exam.topics.length;
      const completedTopics = exam.topics.filter(t => t.isCompleted).length;
      const coveragePercent = totalTopics > 0 ? Math.round((completedTopics / totalTopics) * 100) : 0;
      const remainingMinutes = exam.topics.filter(t => !t.isCompleted).reduce((s, t) => s + t.estimateMinutes, 0);
      return {
        id: exam.id,
        title: exam.title,
        examDate: exam.examDate,
        daysLeft,
        totalTopics,
        completedTopics,
        coveragePercent,
        remainingMinutes
      };
    });

    // Completion rate
    const completionRate = tasks.length > 0
      ? Math.round((completedTasks.length / tasks.length) * 100)
      : 0;

    res.json({
      today: {
        plannedMinutes: plannedMinutesToday,
        completedMinutes: completedBlockMinutesToday,
        remainingMinutes: Math.max(0, plannedMinutesToday - completedBlockMinutesToday),
        focusMinutes: focusMinutesToday,
        taskBlockCount: taskBlocksToday.length,
        completedTaskBlockCount: completedBlocksToday.length,
      },
      tasks: {
        total: tasks.length,
        completed: completedTasks.length,
        pending: pendingTasks.length,
        overdue: overdueTasks.length,
        dueToday: dueTodayTasks.length,
        dueNext3Days: dueNext3DaysTasks.length,
        deferred: deferredTasksCount,
        completionRate,
        totalRemainingMinutes,
      },
      upcomingBlocks,
      examCountdowns,
      scheduleVersionId: schedule?.id ?? null,
      scheduleGeneratedAt: schedule?.generatedAt ?? null,
    });
  } catch (err) { next(err); }
});
