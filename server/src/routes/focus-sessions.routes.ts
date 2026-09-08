import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { validate } from '../middleware/validate';

export const focusSessionsRouter = Router();
focusSessionsRouter.use(authenticate);

const startSessionSchema = z.object({
  taskId: z.string().uuid().optional(),
  notes: z.string().max(500).optional(),
});

const completeSessionSchema = z.object({
  notes: z.string().max(500).optional(),
});

// POST /api/v1/focus-sessions — start a session
focusSessionsRouter.post('/', validate(startSessionSchema), async (req: any, res, next) => {
  try {
    // Check if there's already a RUNNING session for this user and auto-discard it
    await prisma.focusSession.updateMany({
      where: { userId: req.userId, status: 'RUNNING' },
      data: { status: 'DISCARDED', endedAt: new Date() }
    });

    // Validate task ownership if taskId provided
    if (req.body.taskId) {
      const task = await prisma.task.findFirst({ where: { id: req.body.taskId, userId: req.userId } });
      if (!task) return res.status(404).json({ error: { message: 'Task not found' } });
    }

    const session = await prisma.focusSession.create({
      data: {
        userId: req.userId,
        taskId: req.body.taskId ?? null,
        startedAt: new Date(),
        status: 'RUNNING',
        notes: req.body.notes ?? null,
      },
      include: { task: { select: { id: true, title: true } } }
    });

    res.status(201).json(session);
  } catch (err) { next(err); }
});

// PATCH /api/v1/focus-sessions/:id/pause
focusSessionsRouter.patch('/:id/pause', async (req: any, res, next) => {
  try {
    const session = await prisma.focusSession.findFirst({
      where: { id: req.params.id, userId: req.userId }
    });
    if (!session) return res.status(404).json({ error: { message: 'Session not found' } });
    if (session.status !== 'RUNNING') return res.status(400).json({ error: { message: 'Session is not running' } });

    const now = new Date();
    const additionalMs = now.getTime() - session.startedAt.getTime() - session.totalPausedMs;
    const newElapsed = session.elapsedSeconds + Math.floor(additionalMs / 1000);

    const updated = await prisma.focusSession.update({
      where: { id: req.params.id },
      data: {
        status: 'PAUSED',
        pausedAt: now,
        elapsedSeconds: newElapsed,
      },
      include: { task: { select: { id: true, title: true } } }
    });
    res.json(updated);
  } catch (err) { next(err); }
});

// PATCH /api/v1/focus-sessions/:id/resume
focusSessionsRouter.patch('/:id/resume', async (req: any, res, next) => {
  try {
    const session = await prisma.focusSession.findFirst({
      where: { id: req.params.id, userId: req.userId }
    });
    if (!session) return res.status(404).json({ error: { message: 'Session not found' } });
    if (session.status !== 'PAUSED') return res.status(400).json({ error: { message: 'Session is not paused' } });

    const now = new Date();
    const pauseDurationMs = session.pausedAt ? now.getTime() - session.pausedAt.getTime() : 0;

    const updated = await prisma.focusSession.update({
      where: { id: req.params.id },
      data: {
        status: 'RUNNING',
        pausedAt: null,
        totalPausedMs: session.totalPausedMs + pauseDurationMs,
      },
      include: { task: { select: { id: true, title: true } } }
    });
    res.json(updated);
  } catch (err) { next(err); }
});

// PATCH /api/v1/focus-sessions/:id/complete
focusSessionsRouter.patch('/:id/complete', validate(completeSessionSchema), async (req: any, res, next) => {
  try {
    const session = await prisma.focusSession.findFirst({
      where: { id: req.params.id, userId: req.userId }
    });
    if (!session) return res.status(404).json({ error: { message: 'Session not found' } });
    if (session.status === 'COMPLETED' || session.status === 'DISCARDED') {
      return res.status(400).json({ error: { message: `Session is already ${session.status}` } });
    }

    const now = new Date();
    let finalElapsed = session.elapsedSeconds;

    if (session.status === 'RUNNING') {
      const additionalMs = now.getTime() - session.startedAt.getTime() - session.totalPausedMs;
      finalElapsed += Math.floor(additionalMs / 1000);
    }

    const result = await prisma.$transaction(async (tx) => {
      const updated = await tx.focusSession.update({
        where: { id: req.params.id },
        data: {
          status: 'COMPLETED',
          endedAt: now,
          elapsedSeconds: finalElapsed,
          notes: req.body.notes ?? session.notes,
        },
        include: { task: { select: { id: true, title: true, estimateMinutes: true, completedMinutes: true, status: true } } }
      });

      // If linked to a task, update task's completedMinutes
      if (session.taskId && updated.task) {
        const additionalMinutes = Math.round(finalElapsed / 60);
        const newCompleted = Math.min(
          updated.task.estimateMinutes,
          updated.task.completedMinutes + additionalMinutes
        );
        const newStatus = newCompleted >= updated.task.estimateMinutes ? 'COMPLETED' : 'IN_PROGRESS';
        await tx.task.update({
          where: { id: session.taskId },
          data: { completedMinutes: newCompleted, status: newStatus }
        });
        // Log disruption for significant over/under runs
        const diff = additionalMinutes - (updated.task.estimateMinutes - updated.task.completedMinutes);
        if (Math.abs(diff) > 10) {
          await tx.disruptionEvent.create({
            data: {
              userId: req.userId,
              taskId: session.taskId,
              type: diff > 0 ? 'OVERRUN' : 'EARLY_COMPLETION',
              plannedMinutes: updated.task.estimateMinutes - updated.task.completedMinutes,
              actualMinutes: additionalMinutes,
            }
          });
        }
      }
      return updated;
    });

    res.json(result);
  } catch (err) { next(err); }
});

// PATCH /api/v1/focus-sessions/:id/discard
focusSessionsRouter.patch('/:id/discard', async (req: any, res, next) => {
  try {
    const session = await prisma.focusSession.findFirst({
      where: { id: req.params.id, userId: req.userId }
    });
    if (!session) return res.status(404).json({ error: { message: 'Session not found' } });

    const updated = await prisma.focusSession.update({
      where: { id: req.params.id },
      data: { status: 'DISCARDED', endedAt: new Date() }
    });
    res.json(updated);
  } catch (err) { next(err); }
});

// GET /api/v1/focus-sessions — history (last 50)
focusSessionsRouter.get('/', async (req: any, res, next) => {
  try {
    const sessions = await prisma.focusSession.findMany({
      where: { userId: req.userId, status: { in: ['COMPLETED', 'DISCARDED'] } },
      orderBy: { startedAt: 'desc' },
      take: 50,
      include: { task: { select: { id: true, title: true } } }
    });
    res.json(sessions);
  } catch (err) { next(err); }
});

// GET /api/v1/focus-sessions/active — get the currently running/paused session
focusSessionsRouter.get('/active', async (req: any, res, next) => {
  try {
    const session = await prisma.focusSession.findFirst({
      where: { userId: req.userId, status: { in: ['RUNNING', 'PAUSED'] } },
      orderBy: { startedAt: 'desc' },
      include: { task: { select: { id: true, title: true, estimateMinutes: true, completedMinutes: true } } }
    });
    if (!session) return res.json(null);
    res.json(session);
  } catch (err) { next(err); }
});
