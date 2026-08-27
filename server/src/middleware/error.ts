import { Request, Response, NextFunction } from 'express';

export function errorHandler(err: any, req: any, res: Response, next: NextFunction) {
  if (err.name === 'ZodError') {
    return res.status(400).json({ 
      error: { code: 'VALIDATION_ERROR', message: 'Invalid input', details: err.errors } 
    });
  }
  
  const reqId = req.id || 'unknown';
  // Log the full error server-side for debugging
  console.error(`[RequestID: ${reqId}] Unhandled Error:`, err);
  
  const isDev = process.env.NODE_ENV !== 'production';
  
  res.status(500).json({ 
    error: { 
      code: 'INTERNAL_ERROR', 
      message: 'An unexpected internal error occurred. Please contact support if the issue persists.',
      requestId: reqId,
      ...(isDev && { details: err.message }) 
    } 
  });
}
