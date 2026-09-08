import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { validate } from '../middleware/validate';

export const profileRouter = Router();
profileRouter.use(authenticate);

const profileUpdateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  college: z.string().max(200).optional().nullable(),
  degree: z.string().max(100).optional().nullable(),
  branch: z.string().max(100).optional().nullable(),
  semester: z.string().max(20).optional().nullable(),
  themePreference: z.enum(['light', 'dark', 'system']).optional(),
  timezone: z.string().max(50).optional(),
}).strict().refine(data => Object.keys(data).length > 0, { message: 'At least one field required' });

// GET /api/v1/profile
profileRouter.get('/', async (req: any, res, next) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.userId },
      select: {
        id: true,
        email: true,
        name: true,
        college: true,
        degree: true,
        branch: true,
        semester: true,
        themePreference: true,
        timezone: true,
        createdAt: true,
      }
    });
    if (!user) return res.status(404).json({ error: { message: 'Profile not found' } });
    res.json(user);
  } catch (err) { next(err); }
});

// PATCH /api/v1/profile
profileRouter.patch('/', validate(profileUpdateSchema), async (req: any, res, next) => {
  try {
    const user = await prisma.user.update({
      where: { id: req.userId },
      data: req.body,
      select: {
        id: true,
        email: true,
        name: true,
        college: true,
        degree: true,
        branch: true,
        semester: true,
        themePreference: true,
        timezone: true,
        createdAt: true,
      }
    });
    res.json(user);
  } catch (err) { next(err); }
});
