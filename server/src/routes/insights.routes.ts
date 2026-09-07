import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { constraintRepo } from '../repositories/constraint.repo';
import { scheduleRepo } from '../repositories/schedule.repo';
import { taskRepo } from '../repositories/task.repo';

export const insightsRouter = Router();
insightsRouter.use(authenticate);

insightsRouter.get('/', async (req: any, res, next) => {
  try {
    const [constraints, tasks, schedule] = await Promise.all([
      constraintRepo.findByUserId(req.userId),
      taskRepo.findActiveTasks(req.userId),
      scheduleRepo.getLatestVersion(req.userId)
    ]);
    const sleepMinutes = constraints ? Math.round(constraints.minSleepHours * 60) : 420;
    const scheduledMinutes = schedule?.blocks
      .filter(block => block.blockType === 'TASK')
      .reduce((total, block) => total + block.durationMinutes, 0) ?? 0;
    const remainingMinutes = tasks.reduce(
      (total, task) => total + Math.max(0, task.estimateMinutes - task.completedMinutes),
      0
    );
    const deferredCount = tasks.reduce((total, task) => total + task.deferralCount, 0);
    const safeDailyMinutes = Math.max(0, 1440 - sleepMinutes - (constraints?.bufferMinutes ?? 30));

    res.json({
      safeDailyMinutes,
      scheduledMinutes,
      remainingMinutes,
      utilization: safeDailyMinutes === 0 ? 0 : scheduledMinutes / safeDailyMinutes,
      deferredCount,
      riskLevel: scheduledMinutes > safeDailyMinutes ? 'HIGH' : scheduledMinutes > safeDailyMinutes * 0.8 ? 'MEDIUM' : 'LOW'
    });
  } catch (err) { next(err); }
});