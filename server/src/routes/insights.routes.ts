import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { constraintRepo } from '../repositories/constraint.repo';
import { scheduleRepo } from '../repositories/schedule.repo';
import { taskRepo } from '../repositories/task.repo';
import { computeSafeDailyMinutes } from '../utils/workload.helper';
import { resolveTaskWorkload } from '../utils/task-workload.helper';

export const insightsRouter = Router();
insightsRouter.use(authenticate);

insightsRouter.get('/', async (req: any, res, next) => {
  try {
    const [constraints, tasks, schedule] = await Promise.all([
      constraintRepo.findByUserId(req.userId),
      taskRepo.findActiveTasks(req.userId),
      scheduleRepo.getLatestVersion(req.userId)
    ]);
    const safeDailyMinutes = computeSafeDailyMinutes(constraints);
    const scheduledMinutes = schedule?.blocks
      .filter(block => block.blockType === 'TASK')
      .reduce((total, block) => total + block.durationMinutes, 0) ?? 0;
    const remainingMinutes = tasks.reduce(
      (total, task) => total + resolveTaskWorkload(task).remainingMinutes,
      0
    );
    const deferredCount = tasks.reduce((total, task) => total + task.deferralCount, 0);
    const safeTotalMinutes = safeDailyMinutes * 7;

    res.json({
      safeDailyMinutes,
      scheduledMinutes,
      remainingMinutes,
      utilization: safeTotalMinutes === 0 ? 0 : scheduledMinutes / safeTotalMinutes,
      deferredCount,
      riskLevel: scheduledMinutes > safeTotalMinutes ? 'HIGH' : scheduledMinutes > safeTotalMinutes * 0.8 ? 'MEDIUM' : 'LOW'
    });
  } catch (err) { next(err); }
});