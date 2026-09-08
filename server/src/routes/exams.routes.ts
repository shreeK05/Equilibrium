import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { z } from 'zod';
import { validate } from '../middleware/validate';

export const examsRouter = Router();
examsRouter.use(authenticate);

const examSchema = z.object({
  title: z.string().min(1).max(200),
  examDate: z.string().datetime(),
  subjectId: z.string().uuid().optional().nullable(),
  venue: z.string().max(200).optional().nullable(),
});

const examUpdateSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  examDate: z.string().datetime().optional(),
  subjectId: z.string().uuid().optional().nullable(),
  venue: z.string().max(200).optional().nullable(),
}).strict().refine(d => Object.keys(d).length > 0, { message: 'At least one field required' });

const topicSchema = z.object({
  title: z.string().min(1).max(200),
  estimateMinutes: z.number().int().positive().max(600).default(60),
  confidence: z.number().min(0).max(1).default(0.5),
  topicType: z.enum(['REVISION', 'PYQ', 'MOCK_TEST', 'LEARNING', 'WEAK_TOPIC']).default('REVISION'),
});

const topicUpdateSchema = z.object({
  title: z.string().min(1).max(200).optional(),
  estimateMinutes: z.number().int().positive().max(600).optional(),
  confidence: z.number().min(0).max(1).optional(),
  topicType: z.enum(['REVISION', 'PYQ', 'MOCK_TEST', 'LEARNING', 'WEAK_TOPIC']).optional(),
  isCompleted: z.boolean().optional(),
}).strict().refine(d => Object.keys(d).length > 0, { message: 'At least one field required' });

// GET /api/v1/exams
examsRouter.get('/', async (req: any, res, next) => {
  try {
    const exams = await prisma.exam.findMany({
      where: { userId: req.userId },
      orderBy: { examDate: 'asc' },
      include: {
        subject: { select: { id: true, name: true, color: true } },
        topics: { orderBy: { createdAt: 'asc' } }
      }
    });
    res.json(exams);
  } catch (err) { next(err); }
});

// GET /api/v1/exams/:id
examsRouter.get('/:id', async (req: any, res, next) => {
  try {
    const exam = await prisma.exam.findFirst({
      where: { id: req.params.id, userId: req.userId },
      include: {
        subject: { select: { id: true, name: true, color: true } },
        topics: { orderBy: { createdAt: 'asc' } }
      }
    });
    if (!exam) return res.status(404).json({ error: { message: 'Exam not found' } });
    res.json(exam);
  } catch (err) { next(err); }
});

// POST /api/v1/exams
examsRouter.post('/', validate(examSchema), async (req: any, res, next) => {
  try {
    // Verify subject ownership if provided
    if (req.body.subjectId) {
      const subject = await prisma.subject.findFirst({ where: { id: req.body.subjectId, userId: req.userId } });
      if (!subject) return res.status(404).json({ error: { message: 'Subject not found' } });
    }
    const exam = await prisma.exam.create({
      data: {
        userId: req.userId,
        title: req.body.title,
        examDate: new Date(req.body.examDate),
        subjectId: req.body.subjectId ?? null,
        venue: req.body.venue ?? null,
      },
      include: {
        subject: { select: { id: true, name: true, color: true } },
        topics: true
      }
    });
    res.status(201).json(exam);
  } catch (err) { next(err); }
});

// PATCH /api/v1/exams/:id
examsRouter.patch('/:id', validate(examUpdateSchema), async (req: any, res, next) => {
  try {
    const data: any = { ...req.body };
    if (data.examDate) data.examDate = new Date(data.examDate);
    const result = await prisma.exam.updateMany({
      where: { id: req.params.id, userId: req.userId },
      data
    });
    if (result.count === 0) return res.status(404).json({ error: { message: 'Exam not found' } });
    const exam = await prisma.exam.findUnique({
      where: { id: req.params.id },
      include: { subject: { select: { id: true, name: true, color: true } }, topics: true }
    });
    res.json(exam);
  } catch (err) { next(err); }
});

// DELETE /api/v1/exams/:id
examsRouter.delete('/:id', async (req: any, res, next) => {
  try {
    const result = await prisma.exam.deleteMany({
      where: { id: req.params.id, userId: req.userId }
    });
    if (result.count === 0) return res.status(404).json({ error: { message: 'Exam not found' } });
    res.status(204).send();
  } catch (err) { next(err); }
});

// --- EXAM TOPICS ---

// POST /api/v1/exams/:id/topics
examsRouter.post('/:id/topics', validate(topicSchema), async (req: any, res, next) => {
  try {
    const exam = await prisma.exam.findFirst({ where: { id: req.params.id, userId: req.userId } });
    if (!exam) return res.status(404).json({ error: { message: 'Exam not found' } });

    const topic = await prisma.examTopic.create({
      data: {
        examId: req.params.id,
        title: req.body.title,
        estimateMinutes: req.body.estimateMinutes ?? 60,
        confidence: req.body.confidence ?? 0.5,
        topicType: req.body.topicType ?? 'REVISION',
      }
    });
    res.status(201).json(topic);
  } catch (err) { next(err); }
});

// PATCH /api/v1/exams/:examId/topics/:topicId
examsRouter.patch('/:examId/topics/:topicId', validate(topicUpdateSchema), async (req: any, res, next) => {
  try {
    // Verify ownership via exam
    const exam = await prisma.exam.findFirst({ where: { id: req.params.examId, userId: req.userId } });
    if (!exam) return res.status(404).json({ error: { message: 'Exam not found' } });

    const topic = await prisma.examTopic.update({
      where: { id: req.params.topicId },
      data: req.body
    });
    res.json(topic);
  } catch (err: any) {
    if (err.code === 'P2025') return res.status(404).json({ error: { message: 'Topic not found' } });
    next(err);
  }
});

// DELETE /api/v1/exams/:examId/topics/:topicId
examsRouter.delete('/:examId/topics/:topicId', async (req: any, res, next) => {
  try {
    const exam = await prisma.exam.findFirst({ where: { id: req.params.examId, userId: req.userId } });
    if (!exam) return res.status(404).json({ error: { message: 'Exam not found' } });

    await prisma.examTopic.delete({ where: { id: req.params.topicId } });
    res.status(204).send();
  } catch (err: any) {
    if (err.code === 'P2025') return res.status(404).json({ error: { message: 'Topic not found' } });
    next(err);
  }
});

// POST /api/v1/exams/:id/schedule-topics — converts exam topics into real tasks for scheduling
examsRouter.post('/:id/schedule-topics', async (req: any, res, next) => {
  try {
    const exam = await prisma.exam.findFirst({
      where: { id: req.params.id, userId: req.userId },
      include: { topics: true }
    });
    if (!exam) return res.status(404).json({ error: { message: 'Exam not found' } });

    const createdTasks = [];
    for (const topic of exam.topics) {
      if (topic.isCompleted || topic.linkedTaskId) continue;

      // Create a real task for this topic so the scheduler can plan it
      const task = await prisma.task.create({
        data: {
          userId: req.userId,
          subjectId: exam.subjectId ?? null,
          title: `${exam.title} — ${topic.title}`,
          description: `${topic.topicType} session for ${exam.title}`,
          category: 'Exam Prep',
          estimateMinutes: topic.estimateMinutes,
          deadline: exam.examDate,
          deadlineType: 'HARD',
          academicWeight: 0.9, // exam prep gets high academic weight
          cognitiveLoad: topic.topicType === 'MOCK_TEST' ? 'HIGH' : 'MEDIUM',
        }
      });
      // Link back
      await prisma.examTopic.update({ where: { id: topic.id }, data: { linkedTaskId: task.id } });
      createdTasks.push(task);
    }

    res.status(201).json({ tasksCreated: createdTasks.length, tasks: createdTasks });
  } catch (err) { next(err); }
});
