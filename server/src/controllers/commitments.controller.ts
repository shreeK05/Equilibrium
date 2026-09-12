import { Request, Response } from 'express';
import { FixedCommitmentRepository } from '../repositories/commitment.repo';
import { fixedCommitmentSchema } from '../validation/schemas';
import { z } from 'zod';

const repo = new FixedCommitmentRepository();

export class FixedCommitmentsController {
  static async create(req: Request, res: Response) {
    const data = fixedCommitmentSchema.parse(req.body);
    
    // Check for overlap
    const overlaps = await repo.findActive((req as any).userId, new Date(data.startTime), new Date(data.endTime));
    if (overlaps.length > 0) {
      return res.status(409).json({ error: { code: 'CONFLICT', message: 'That time conflicts with an existing commitment.' } });
    }

    const commitment = await repo.create({
      ...data,
      userId: (req as any).userId
    });
    res.status(201).json(commitment);
  }

  static async list(req: Request, res: Response) {
    const commitments = await repo.findMany((req as any).userId);
    res.json(commitments);
  }

  static async get(req: Request, res: Response) {
    const commitment = await repo.findById((req.params.id as string), (req as any).userId);
    if (!commitment) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Commitment not found' } });
    }
    res.json(commitment);
  }

  static async update(req: Request, res: Response) {
    // Create a fresh partial schema to avoid Zod Error about refinements
    const patchSchema = z.object({
      title: z.string().min(1).max(255).optional(),
      startTime: z.string().datetime().optional(),
      endTime: z.string().datetime().optional(),
      type: z.enum(['CLASS', 'LAB', 'EXAM', 'PERSONAL', 'CUSTOM', 'ROUTINE']).optional(),
      recurrence: z.string().max(255).optional().nullable(),
      daysOfWeek: z.string().optional().nullable(),
      flexibility: z.enum(['FIXED', 'FLEXIBLE', 'SOFT']).optional(),
      color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional().nullable(),
      isActive: z.boolean().optional()
    }).superRefine((data, ctx) => {
      if (data.startTime && data.endTime) {
        const start = new Date(data.startTime).getTime();
        const end = new Date(data.endTime).getTime();
        if (end <= start) {
          ctx.addIssue({ code: 'custom', message: 'endTime must be after startTime', path: ['endTime'] });
        }
      }
    });
    const data = patchSchema.parse(req.body);

    const existing = await repo.findById((req.params.id as string), (req as any).userId);
    if (!existing) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Commitment not found' } });
    }

    const newStart = data.startTime ? new Date(data.startTime) : existing.startTime;
    const newEnd = data.endTime ? new Date(data.endTime) : existing.endTime;

    const overlaps = await repo.findActive((req as any).userId, newStart, newEnd);
    const hasRealOverlap = overlaps.some(c => c.id !== existing.id);
    if (hasRealOverlap) {
      return res.status(409).json({ error: { code: 'CONFLICT', message: 'That time conflicts with an existing commitment.' } });
    }

    const updated = await repo.updateStrict((req.params.id as string), (req as any).userId, data);
    res.json(updated);
  }

  static async delete(req: Request, res: Response) {
    const success = await repo.delete((req.params.id as string), (req as any).userId);
    if (!success) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Commitment not found' } });
    }
    res.status(204).send();
  }
}
