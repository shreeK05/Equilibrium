import { ZodObject } from 'zod';
import { Request, Response, NextFunction } from 'express';

export const validate = (schema: ZodObject<any, any>) => (req: Request, res: Response, next: NextFunction) => {
  try {
    schema.parse(req.body);
    next();
  } catch (err: any) {
    if (err.name === 'ZodError') {
      return res.status(400).json({
        error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: err.issues }
      });
    }
    next(err);
  }
};
