import { Router } from 'express';
import { scheduleService } from '../services/schedule.service';
import { scheduleRepo } from '../repositories/schedule.repo';
import { authenticate } from '../middleware/auth';

export const schedulesRouter = Router();
schedulesRouter.use(authenticate);

schedulesRouter.post('/generate', async (req: any, res, next) => {
  try {
    const version = await scheduleService.generateSchedule(req.userId);
    res.status(201).json(version);
  } catch (err) { next(err); }
});

schedulesRouter.post('/:id/reschedule', async (req: any, res, next) => {
  try {
    const version = await scheduleService.reschedule(req.userId, req.params.id);
    res.status(201).json(version);
  } catch (err: any) {
    if (err.message.includes('not found')) return res.status(404).json({ error: { message: err.message } });
    next(err);
  }
});

schedulesRouter.get('/current', async (req: any, res, next) => {
  try {
    const version = await scheduleRepo.getLatestVersion(req.userId);
    if (!version) return res.status(404).json({ error: { message: 'No schedule found' } });
    res.json(version);
  } catch (err) { next(err); }
});

schedulesRouter.get('/history', async (req: any, res, next) => {
  try {
    const history = await scheduleRepo.getHistory(req.userId);
    res.json(history);
  } catch (err) { next(err); }
});

schedulesRouter.get('/:id', async (req: any, res, next) => {
  try {
    const version = await scheduleRepo.getVersion(req.params.id, req.userId);
    if (!version) return res.status(404).json({ error: { message: 'Schedule not found' } });
    res.json(version);
  } catch (err) { next(err); }
});

schedulesRouter.get('/:id/decisions', async (req: any, res, next) => {
  try {
    const version = await scheduleRepo.getVersion(req.params.id, req.userId);
    if (!version) return res.status(404).json({ error: { message: 'Schedule not found' } });
    // Parse the JSON components before sending
    const decisions = version.decisionLogs.map(log => ({
      ...log,
      priorityComponents: JSON.parse(log.priorityComponentsJson)
    }));
    res.json(decisions);
  } catch (err) { next(err); }
});
