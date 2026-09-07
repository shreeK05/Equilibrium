import { Router } from 'express';
import express from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';

export const importsRouter = Router();
importsRouter.use(authenticate);

const confirmationSchema = z.object({
  candidates: z.array(z.object({
    id: z.string().uuid(),
    title: z.string().min(1).max(255),
    deadline: z.string().datetime().nullable().optional(),
    estimateMinutes: z.number().int().positive().max(10000),
    confirmed: z.boolean()
  })).min(1)
});

function parseCandidates(rawText: string) {
  return rawText.split(/\r?\n/).map(line => line.trim()).filter(Boolean).map(line => {
    const match = line.match(/^(.+?)(?:\s+-\s+|\s+due\s+)(\d{4}-\d{2}-\d{2})(?:\s+(\d+)\s*(?:m|min|minutes))?$/i);
    return {
      title: match?.[1]?.trim() ?? line,
      deadline: match?.[2] ? new Date(`${match[2]}T23:59:00.000Z`) : null,
      estimateMinutes: match?.[3] ? Number(match[3]) : 60,
      confidence: match ? 0.9 : 0.45,
      rawText: line
    };
  });
}

importsRouter.post('/syllabus', express.text({ type: ['text/plain', 'application/pdf'], limit: '5mb' }), async (req: any, res, next) => {
  try {
    const rawText = typeof req.body === 'string' ? req.body : '';
    if (!rawText.trim()) return res.status(400).json({ error: { code: 'EMPTY_IMPORT', message: 'Provide extracted syllabus text to create candidates' } });
    const job = await prisma.importJob.create({
      data: {
        userId: req.userId,
        type: 'SYLLABUS',
        sourceName: req.headers['x-source-name']?.toString() ?? 'syllabus',
        rawText,
        candidates: { create: parseCandidates(rawText) }
      },
      include: { candidates: true }
    });
    res.status(201).json(job);
  } catch (err) { next(err); }
});

importsRouter.post('/syllabus/:jobId/confirm', async (req: any, res, next) => {
  try {
    const parsed = confirmationSchema.parse(req.body);
    const job = await prisma.importJob.findFirst({ where: { id: req.params.jobId, userId: req.userId } });
    if (!job) return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Import job not found' } });

    const createdTasks = await prisma.$transaction(async (tx) => {
      const tasks = [];
      for (const candidate of parsed.candidates) {
        await tx.importCandidate.updateMany({
          where: { id: candidate.id, importJobId: job.id },
          data: { title: candidate.title, deadline: candidate.deadline ? new Date(candidate.deadline) : null, estimateMinutes: candidate.estimateMinutes, confirmed: candidate.confirmed }
        });
        if (candidate.confirmed) {
          tasks.push(await tx.task.create({
            data: {
              userId: req.userId,
              title: candidate.title,
              estimateMinutes: candidate.estimateMinutes,
              deadline: candidate.deadline ? new Date(candidate.deadline) : new Date(Date.now() + 7 * 86400000)
            }
          }));
        }
      }
      await tx.importJob.update({ where: { id: job.id }, data: { status: 'CONFIRMED' } });
      return tasks;
    });
    res.json({ jobId: job.id, createdTasks });
  } catch (err) { next(err); }
});