import { Router } from 'express';
import { taskRepo } from '../repositories/task.repo';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { taskSchema } from '../validation/schemas';

export const tasksRouter = Router();
tasksRouter.use(authenticate);

tasksRouter.get('/', async (req: any, res, next) => {
  try {
    const tasks = await taskRepo.findMany(req.userId);
    res.json(tasks);
  } catch (err) { next(err); }
});

tasksRouter.post('/', validate(taskSchema), async (req: any, res, next) => {
  try {
    const task = await taskRepo.create({ ...req.body, userId: req.userId });
    res.status(201).json(task);
  } catch (err) { next(err); }
});

tasksRouter.get('/:id', async (req: any, res, next) => {
  try {
    const task = await taskRepo.findById(req.params.id, req.userId);
    if (!task) return res.status(404).json({ error: { message: 'Task not found' } });
    res.json(task);
  } catch (err) { next(err); }
});

tasksRouter.patch('/:id', async (req: any, res, next) => {
  try {
    const task = await taskRepo.safeUpdate(req.params.id, req.userId, req.body);
    res.json(task);
  } catch (err: any) {
    if (err.message.includes('not found')) return res.status(404).json({ error: { message: err.message } });
    next(err);
  }
});

tasksRouter.delete('/:id', async (req: any, res, next) => {
  try {
    await taskRepo.delete(req.params.id, req.userId);
    res.status(204).send();
  } catch (err: any) {
    if (err.message.includes('not found')) return res.status(404).json({ error: { message: err.message } });
    next(err);
  }
});
