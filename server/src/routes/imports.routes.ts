import { Router } from 'express';
import express from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { PDFParse } from 'pdf-parse';

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

function parseIcsDate(value: string) {
  const normalized = value.replace(/\r/g, '').trim();
  if (/^\d{8}T\d{6}Z$/.test(normalized)) {
    return new Date(normalized.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z/, '$1-$2-$3T$4:$5:$6Z'));
  }
  if (/^\d{8}T\d{6}$/.test(normalized)) {
    return new Date(normalized.replace(/(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})/, '$1-$2-$3T$4:$5:$6Z'));
  }
  return new Date(`${normalized.slice(0, 4)}-${normalized.slice(4, 6)}-${normalized.slice(6, 8)}T00:00:00.000Z`);
}

function parseIcsEvents(rawText: string) {
  return rawText.split('BEGIN:VEVENT').slice(1).map(event => {
    const read = (key: string) => event.match(new RegExp(`(?:^|\\n)${key}(?:;[^:]*)?:([^\\n]+)`))?.[1]?.trim();
    const start = read('DTSTART');
    const end = read('DTEND');
    const title = read('SUMMARY') ?? 'Imported commitment';
    if (!start || !end) return null;
    return { title, startTime: parseIcsDate(start), endTime: parseIcsDate(end) };
  }).filter((event): event is { title: string; startTime: Date; endTime: Date } =>
    event !== null && event.endTime > event.startTime
  );
}

importsRouter.post('/syllabus', [
  express.raw({ type: 'application/pdf', limit: '5mb' }),
  express.text({ type: 'text/plain', limit: '5mb' })
], async (req: any, res, next) => {
  try {
    let rawText = typeof req.body === 'string' ? req.body : '';
    if (Buffer.isBuffer(req.body)) {
      const parser = new PDFParse({ data: req.body });
      try {
        const result = await parser.getText();
        rawText = result.text;
      } finally {
        await parser.destroy();
      }
    }
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

importsRouter.post('/calendar/ics', express.text({ type: ['text/calendar', 'text/plain'], limit: '2mb' }), async (req: any, res, next) => {
  try {
    const events = parseIcsEvents(typeof req.body === 'string' ? req.body : '');
    if (events.length === 0) return res.status(400).json({ error: { code: 'EMPTY_CALENDAR', message: 'No valid calendar events were found' } });
    const commitments = await prisma.$transaction(events.map(event => prisma.fixedCommitment.create({
      data: { userId: req.userId, title: event.title, startTime: event.startTime, endTime: event.endTime, type: 'CUSTOM' }
    })));
    res.status(201).json({ importedCount: commitments.length, commitments });
  } catch (err) { next(err); }
});