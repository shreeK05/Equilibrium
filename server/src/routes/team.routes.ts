import { Router } from 'express';
import crypto from 'crypto';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';

export const teamRouter = Router();

function hashToken(token: string) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

teamRouter.post('/shares', authenticate, async (req: any, res, next) => {
  try {
    const hours = Math.min(Math.max(Number(req.body?.expiresInHours ?? 24), 1), 168);
    const token = crypto.randomBytes(32).toString('base64url');
    const expiresAt = new Date(Date.now() + hours * 60 * 60 * 1000);
    await prisma.teamShare.create({
      data: { userId: req.userId, tokenHash: hashToken(token), expiresAt }
    });
    res.status(201).json({ token, expiresAt, readOnly: true });
  } catch (err) { next(err); }
});

teamRouter.get('/shares/:token', async (req, res, next) => {
  try {
    const share = await prisma.teamShare.findFirst({
      where: {
        tokenHash: hashToken(req.params.token),
        revokedAt: null,
        expiresAt: { gt: new Date() }
      }
    });
    if (!share) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Share link is invalid or expired' } });

    const schedule = await prisma.scheduleVersion.findFirst({
      where: { userId: share.userId },
      orderBy: { generatedAt: 'desc' },
      select: {
        id: true,
        generatedAt: true,
        capacityMinutes: true,
        algorithmVersion: true,
        blocks: {
          orderBy: { startTime: 'asc' },
          select: {
            id: true,
            taskId: true,
            startTime: true,
            endTime: true,
            durationMinutes: true,
            blockType: true,
            task: { select: { title: true, cognitiveLoad: true } }
          }
        }
      }
    });
    res.json({ expiresAt: share.expiresAt, schedule });
  } catch (err) { next(err); }
});

teamRouter.delete('/shares/:id', authenticate, async (req: any, res, next) => {
  try {
    const result = await prisma.teamShare.updateMany({
      where: { id: req.params.id, userId: req.userId, revokedAt: null },
      data: { revokedAt: new Date() }
    });
    if (result.count === 0) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Share link not found' } });
    res.status(204).send();
  } catch (err) { next(err); }
});