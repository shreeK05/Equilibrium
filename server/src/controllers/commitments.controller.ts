import { Request, Response } from 'express';
import { FixedCommitmentRepository } from '../repositories/commitment.repo';
import { fixedCommitmentSchema } from '../validation/schemas';

const repo = new FixedCommitmentRepository();

export class FixedCommitmentsController {
  static async create(req: Request, res: Response) {
    const data = fixedCommitmentSchema.parse(req.body);
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
    // Make properties optional for PATCH
    const patchSchema = fixedCommitmentSchema.partial().superRefine((data, ctx) => {
      if (data.startTime && data.endTime) {
        const start = new Date(data.startTime).getTime();
        const end = new Date(data.endTime).getTime();
        if (end <= start) {
          ctx.addIssue({ code: 'custom', message: 'endTime must be after startTime', path: ['endTime'] });
        }
      }
    });
    const data = patchSchema.parse(req.body);

    const updated = await repo.updateStrict((req.params.id as string), (req as any).userId, data);
    if (!updated) {
      return res.status(404).json({ error: { code: 'NOT_FOUND', message: 'Commitment not found' } });
    }
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
