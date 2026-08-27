import { Router } from 'express';
import { constraintRepo } from '../repositories/constraint.repo';
import { authenticate } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { constraintSchema } from '../validation/schemas';

export const constraintsRouter = Router();
constraintsRouter.use(authenticate);

constraintsRouter.get('/', async (req: any, res, next) => {
  try {
    const constraints = await constraintRepo.findByUserId(req.userId);
    if (!constraints) return res.status(404).json({ error: { message: 'Constraints not found' } });
    res.json(constraints);
  } catch (err) { next(err); }
});

constraintsRouter.patch('/', validate(constraintSchema), async (req: any, res, next) => {
  try {
    const constraints = await constraintRepo.upsert(req.userId, req.body);
    res.json(constraints);
  } catch (err) { next(err); }
});
