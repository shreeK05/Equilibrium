import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { scheduleService } from '../services/schedule.service';
import { z } from 'zod';

export const routinesRouter = Router();
routinesRouter.use(authenticate);

export const DEFAULT_ROUTINES = [
  { id: 'default-breakfast', title: 'Breakfast', category: 'MEAL', startTime: '08:00', endTime: '08:45', daysOfWeek: [0, 1, 2, 3, 4, 5, 6], isEnabled: true },
  { id: 'default-lunch', title: 'Lunch', category: 'MEAL', startTime: '13:00', endTime: '14:00', daysOfWeek: [0, 1, 2, 3, 4, 5, 6], isEnabled: true },
  { id: 'default-dinner', title: 'Dinner', category: 'MEAL', startTime: '20:00', endTime: '21:00', daysOfWeek: [0, 1, 2, 3, 4, 5, 6], isEnabled: true },
  { id: 'default-evening-break', title: 'Evening Break', category: 'BREAK', startTime: '17:30', endTime: '18:00', daysOfWeek: [0, 1, 2, 3, 4, 5, 6], isEnabled: true }
];

const routineItemSchema = z.object({
  id: z.string().optional(),
  title: z.string().min(1).max(100),
  category: z.enum(['MEAL', 'BREAK', 'EXERCISE', 'COMMUTE', 'PERSONAL']),
  startTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid start time HH:mm'),
  endTime: z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Invalid end time HH:mm'),
  daysOfWeek: z.array(z.number().int().min(0).max(6)).optional(),
  isEnabled: z.boolean().default(true)
});

const updateRoutinesSchema = z.object({
  routines: z.array(routineItemSchema),
  maxDailyStudyMinutes: z.number().int().min(60).max(1440).optional(),
  maxFocusSessionMinutes: z.number().int().min(30).max(360).optional()
});

// GET /api/v1/routines
routinesRouter.get('/', async (req: any, res, next) => {
  try {
    const userId = req.userId;
    const constraint = await prisma.userConstraint.findUnique({
      where: { userId }
    });

    let routines = DEFAULT_ROUTINES;
    if (constraint?.routinesJson) {
      try {
        const parsed = JSON.parse(constraint.routinesJson);
        if (Array.isArray(parsed) && parsed.length > 0) {
          routines = parsed;
        }
      } catch {
        routines = DEFAULT_ROUTINES;
      }
    }

    res.json({
      routines,
      maxDailyStudyMinutes: constraint?.maxDailyStudyMinutes ?? 480,
      maxFocusSessionMinutes: constraint?.maxFocusSessionMinutes ?? 120
    });
  } catch (err) { next(err); }
});

// PUT /api/v1/routines
routinesRouter.put('/', async (req: any, res, next) => {
  try {
    const userId = req.userId;
    const { routines, maxDailyStudyMinutes, maxFocusSessionMinutes } = updateRoutinesSchema.parse(req.body);

    const updated = await prisma.userConstraint.upsert({
      where: { userId },
      create: {
        userId,
        minSleepHours: 7.0,
        sleepStart: '23:00',
        sleepEnd: '06:00',
        bufferMinutes: 30,
        peakEnergyWindowsJson: '[]',
        routinesJson: JSON.stringify(routines),
        maxDailyStudyMinutes: maxDailyStudyMinutes ?? 480,
        maxFocusSessionMinutes: maxFocusSessionMinutes ?? 120
      },
      update: {
        routinesJson: JSON.stringify(routines),
        ...(maxDailyStudyMinutes !== undefined ? { maxDailyStudyMinutes } : {}),
        ...(maxFocusSessionMinutes !== undefined ? { maxFocusSessionMinutes } : {})
      }
    });

    // Proactively re-plan active schedule so protected meals and routines take immediate effect
    try {
      await scheduleService.replan(userId, 'ROUTINE_UPDATE');
    } catch (schedErr) {
      // Non-blocking if no tasks yet exist
    }

    res.json({
      routines,
      maxDailyStudyMinutes: updated.maxDailyStudyMinutes,
      maxFocusSessionMinutes: updated.maxFocusSessionMinutes,
      message: 'Routines and student life preferences successfully updated'
    });
  } catch (err) { next(err); }
});

// POST /api/v1/routines/reset-defaults
routinesRouter.post('/reset-defaults', async (req: any, res, next) => {
  try {
    const userId = req.userId;
    await prisma.userConstraint.upsert({
      where: { userId },
      create: {
        userId,
        minSleepHours: 7.0,
        sleepStart: '23:00',
        sleepEnd: '06:00',
        bufferMinutes: 30,
        peakEnergyWindowsJson: '[]',
        routinesJson: JSON.stringify(DEFAULT_ROUTINES),
        maxDailyStudyMinutes: 480,
        maxFocusSessionMinutes: 120
      },
      update: {
        routinesJson: JSON.stringify(DEFAULT_ROUTINES),
        maxDailyStudyMinutes: 480,
        maxFocusSessionMinutes: 120
      }
    });

    try {
      await scheduleService.replan(userId, 'ROUTINE_RESET');
    } catch (schedErr) {}

    res.json({
      routines: DEFAULT_ROUTINES,
      maxDailyStudyMinutes: 480,
      maxFocusSessionMinutes: 120,
      message: 'Routines reset to student life defaults'
    });
  } catch (err) { next(err); }
});
