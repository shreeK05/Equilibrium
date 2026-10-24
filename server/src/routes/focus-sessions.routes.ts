import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { validate } from '../middleware/validate';
import { resolveTaskWorkload } from '../utils/task-workload.helper';

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
      where: { id: req.params.id, userId: req.userId },
      include: { task: { select: { id: true, title: true, estimateMinutes: true, completedMinutes: true, actualMinutes: true, remainingMinutes: true, status: true } } }
    });
    if (!session) return res.status(404).json({ error: { message: 'Session not found' } });
    if (session.status === 'COMPLETED') {
      return res.status(200).json(session);
    }
    if (session.status === 'DISCARDED') {
      return res.status(400).json({ error: { message: 'Session is already DISCARDED' } });
    }

    const now = new Date();
    let finalElapsed = session.elapsedSeconds;

    if (session.status === 'RUNNING') {
      const additionalMs = now.getTime() - session.startedAt.getTime() - session.totalPausedMs;
      finalElapsed += Math.floor(additionalMs / 1000);
    }

    const result = await prisma.$transaction(async (tx) => {
      const current = await tx.focusSession.findFirst({
        where: { id: req.params.id, userId: req.userId },
        include: { task: { select: { id: true, title: true, estimateMinutes: true, completedMinutes: true, actualMinutes: true, remainingMinutes: true, status: true } } }
      });
      if (!current) throw new Error('Session not found');
      if (current.status === 'COMPLETED') {
        return current;
      }
      if (current.status === 'DISCARDED') {
        const err: any = new Error('Session is already DISCARDED');
        err.statusCode = 400;
        throw err;
      }

      const updated = await tx.focusSession.update({
        where: { id: req.params.id },
        data: {
          status: 'COMPLETED',
          endedAt: now,
          elapsedSeconds: finalElapsed,
          notes: req.body.notes ?? session.notes,
        },
        include: { task: { select: { id: true, title: true, estimateMinutes: true, completedMinutes: true, actualMinutes: true, remainingMinutes: true, status: true } } }
      });

      // If linked to a task, update task's actualMinutes and remainingMinutes
      if (session.taskId) {
        const linkedTask = await tx.task.findUnique({ where: { id: session.taskId } });
        if (linkedTask) {
          const additionalMinutes = Math.round(finalElapsed / 60);
          const currentWorkload = resolveTaskWorkload(linkedTask);
          const newActual = currentWorkload.actualMinutes + additionalMinutes;
          const newRemaining = Math.max(0, currentWorkload.remainingMinutes - additionalMinutes);
          // Focus session completion never auto-completes the task; keeps IN_PROGRESS unless already COMPLETED
          const newStatus = linkedTask.status === 'COMPLETED' ? 'COMPLETED' : 'IN_PROGRESS';

          await tx.task.update({
            where: { id: session.taskId },
            data: {
              actualMinutes: newActual,
              completedMinutes: newActual,
              remainingMinutes: newRemaining,
              status: newStatus
            }
          });

          // Log disruption for significant over/under runs compared to expected remaining
          const diff = additionalMinutes - currentWorkload.remainingMinutes;
          if (Math.abs(diff) > 10 && currentWorkload.remainingMinutes > 0) {
            await tx.disruptionEvent.create({
              data: {
                userId: req.userId,
                taskId: session.taskId,
                type: diff > 0 ? 'OVERRUN' : 'EARLY_COMPLETION',
                plannedMinutes: currentWorkload.remainingMinutes,
                actualMinutes: additionalMinutes,
              }
            });
          }
        }
      }
      return updated;
    });

    res.json(result);
  } catch (err: any) {
    if (err.statusCode === 400) return res.status(400).json({ error: { message: err.message } });
    if (err.message?.includes('not found')) return res.status(404).json({ error: { message: err.message } });
    next(err);
  }
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
