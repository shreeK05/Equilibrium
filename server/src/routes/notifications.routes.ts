import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';

export const notificationsRouter = Router();
notificationsRouter.use(authenticate);

const preferenceSchema = z.object({
  upcomingTaskAlerts: z.boolean().optional(),
  overloadAlerts: z.boolean().optional(),
  rescheduleAlerts: z.boolean().optional(),
  dailyBrief: z.boolean().optional()
}).strict();

notificationsRouter.get('/preferences', async (req: any, res, next) => {
  try {
    const preferences = await prisma.notificationPreference.upsert({
      where: { userId: req.userId },
      create: { userId: req.userId },
      update: {}
    });
    res.json(preferences);
  } catch (err) { next(err); }
});

notificationsRouter.patch('/preferences', async (req: any, res, next) => {
  try {
    const data = preferenceSchema.parse(req.body);
    res.json(await prisma.notificationPreference.upsert({
      where: { userId: req.userId },
      create: { userId: req.userId, ...data },
      update: data
    }));
  } catch (err) { next(err); }
});