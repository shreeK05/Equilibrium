import { Router } from 'express';
import { authenticate } from '../middleware/auth';
import { prisma } from '../db';
import { nlpTaskParser } from '../services/nlp/nlp-task-parser.service';
import { conversationalRescheduler, RescheduleIntentType } from '../services/nlp/conversational-rescheduler.service';
import { groqClient } from '../services/nlp/groq-client.service';
import { resolveTimezone } from '../scheduler/timezone';
import { config } from '../config';
import { rateLimit } from 'express-rate-limit';
import { z } from 'zod';

export const nlpRouter = Router();
nlpRouter.use(authenticate);

// Per-user/IP rate limiter for NLP endpoints to prevent quota exhaustion
const nlpRateLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 25, // 25 calls per minute
  standardHeaders: true,
  legacyHeaders: false,
  message: {
    error: {
      code: 'RATE_LIMIT_EXCEEDED',
      message: 'Too many NLP requests. Please wait a moment before trying again.'
    }
  }
});

nlpRouter.use(nlpRateLimiter);

const parseTaskSchema = z.object({
  text: z.string().min(1).max(1000)
});

const rescheduleIntentSchema = z.object({
  message: z.string().min(1).max(1000),
  targetTaskId: z.string().uuid().optional()
});

const applyRescheduleSchema = z.object({
  intent: z.string().min(1),
  targetTaskId: z.string().uuid().optional()
});

// GET /api/v1/nlp/status — Status of LLM engine and fallback availability
nlpRouter.get('/status', async (req: any, res) => {
  const modelCheck = await groqClient.verifyModelAvailable();
  res.json({
    llmConfigured: groqClient.isConfigured(),
    model: config.groqModel,
    modelAvailable: modelCheck.available,
    error: modelCheck.error,
    availableModels: modelCheck.models.slice(0, 10),
    fallbackModel: config.groqFallbackModel,
    fallbackAvailable: true
  });
});

// POST /api/v1/nlp/parse-task — Natural-language task creation preview
nlpRouter.post('/parse-task', async (req: any, res, next) => {
  try {
    const { text } = parseTaskSchema.parse(req.body);
    const userId = req.userId;

    const [user, subjects] = await Promise.all([
      prisma.user.findUnique({ where: { id: userId }, select: { timezone: true } }),
      prisma.subject.findMany({ where: { userId }, select: { name: true } })
    ]);

    const tz = resolveTimezone(user?.timezone);
    const existingSubjectNames = subjects.map(s => s.name);

    const parsed = await nlpTaskParser.parseTaskAsync(text, tz, existingSubjectNames, new Date(), userId);
    res.json(parsed);
  } catch (err) { next(err); }
});

// POST /api/v1/nlp/reschedule-intent — Conversational rescheduling interpretation
nlpRouter.post('/reschedule-intent', async (req: any, res, next) => {
  try {
    const { message, targetTaskId } = rescheduleIntentSchema.parse(req.body);
    const userId = req.userId;

    const proposal = await conversationalRescheduler.interpretAndPropose(
      userId,
      message,
      targetTaskId,
      new Date()
    );

    res.json(proposal);
  } catch (err) { next(err); }
});

// POST /api/v1/nlp/apply-reschedule — Apply confirmed conversational rescheduling
nlpRouter.post('/apply-reschedule', async (req: any, res, next) => {
  try {
    const { intent, targetTaskId } = applyRescheduleSchema.parse(req.body);
    const userId = req.userId;

    const newVersion = await conversationalRescheduler.applyReschedule(
      userId,
      intent as RescheduleIntentType,
      targetTaskId,
      new Date()
    );

    res.status(201).json(newVersion);
  } catch (err) { next(err); }
});
