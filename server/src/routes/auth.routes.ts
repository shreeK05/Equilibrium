import { Router } from 'express';
import { authService } from '../services/auth.service';
import { registerSchema } from '../validation/schemas';
import { validate } from '../middleware/validate';
import { authRateLimiter } from '../middleware/rate-limit';
import { z } from 'zod';
import { authenticate } from '../middleware/auth';
import { userRepo } from '../repositories/user.repo';

export const authRouter = Router();

authRouter.use(authRateLimiter);

authRouter.post('/register', validate(registerSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.register(email, password);
    res.json(result);
  } catch (err: any) {
    if (err.message === 'Email in use') return res.status(409).json({ error: { message: err.message } });
    next(err);
  }
});

authRouter.post('/login', validate(registerSchema), async (req, res, next) => {
  try {
    const { email, password } = req.body;
    const result = await authService.login(email, password);
    res.json(result);
  } catch (err: any) {
    if (err.message === 'Invalid credentials') return res.status(401).json({ error: { message: err.message } });
    next(err);
  }
});

authRouter.get('/me', authenticate, async (req: any, res, next) => {
  try {
    const user = await userRepo.findById(req.userId);
    if (!user) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'User not found' } });
    res.json({ id: user.id, email: user.email, timezone: user.timezone, createdAt: user.createdAt });
  } catch (err) { next(err); }
});
