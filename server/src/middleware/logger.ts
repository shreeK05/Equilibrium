import { Request, Response, NextFunction } from 'express';
import crypto from 'crypto';
import morgan from 'morgan';

export function requestCorrelation(req: Request, res: Response, next: NextFunction) {
  const reqId = req.headers['x-request-id'] || crypto.randomUUID();
  (req as any).id = Array.isArray(reqId) ? reqId[0] : reqId;
  res.setHeader('X-Request-ID', (req as any).id);
  next();
}

// Custom morgan format to include Request ID and avoid logging sensitive tokens
morgan.token('(req as any).id', (req: Request) => (req as any).id);
morgan.token('user-id', (req: any) => req.userId || 'anonymous');

export const requestLogger = morgan(
  ':(req as any).id :user-id :method :url :status :res[content-length] - :response-time ms'
);
