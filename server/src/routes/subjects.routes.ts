import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { validate } from '../middleware/validate';

export const subjectsRouter = Router();
subjectsRouter.use(authenticate);

const subjectSchema = z.object({
  name: z.string().min(1).max(100),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a valid hex color').optional().nullable(),
});

const subjectUpdateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/, 'Must be a valid hex color').optional().nullable(),
}).strict().refine(d => Object.keys(d).length > 0, { message: 'At least one field required' });

// GET /api/v1/subjects
subjectsRouter.get('/', async (req: any, res, next) => {
  try {
    const subjects = await prisma.subject.findMany({
      where: { userId: req.userId },
      orderBy: { name: 'asc' },
      include: {
        _count: { select: { tasks: true, exams: true } }
      }
    });
    res.json(subjects);
  } catch (err) { next(err); }
});

// POST /api/v1/subjects
subjectsRouter.post('/', validate(subjectSchema), async (req: any, res, next) => {
  try {
    const subject = await prisma.subject.create({
      data: { ...req.body, userId: req.userId }
    });
    res.status(201).json(subject);
  } catch (err: any) {
    if (err.code === 'P2002') return res.status(409).json({ error: { code: 'DUPLICATE_SUBJECT', message: 'Subject with this name already exists' } });
    next(err);
  }
});

// PATCH /api/v1/subjects/:id
subjectsRouter.patch('/:id', validate(subjectUpdateSchema), async (req: any, res, next) => {
  try {
    const result = await prisma.subject.updateMany({
      where: { id: req.params.id, userId: req.userId },
      data: req.body
    });
    if (result.count === 0) return res.status(404).json({ error: { message: 'Subject not found' } });
    res.json(await prisma.subject.findUnique({ where: { id: req.params.id } }));
  } catch (err) { next(err); }
});

// DELETE /api/v1/subjects/:id
subjectsRouter.delete('/:id', async (req: any, res, next) => {
  try {
    const result = await prisma.subject.deleteMany({
      where: { id: req.params.id, userId: req.userId }
    });
    if (result.count === 0) return res.status(404).json({ error: { message: 'Subject not found' } });
    res.status(204).send();
  } catch (err) { next(err); }
});
