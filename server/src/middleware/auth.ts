import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config } from '../config';
import { userRepo } from '../repositories/user.repo';

export async function authenticate(req: Request, res: Response, next: NextFunction) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Missing or malformed Authorization Bearer token' } });
  }

  const token = authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Empty token' } });
  
  try {
    const decoded = jwt.verify(token, config.jwtSecret) as { userId: string, tokenVersion?: number };
    if (!decoded.userId) throw new Error('Malformed token claims');

    const user = await userRepo.findById(decoded.userId);
    if (!user) return res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'User not found' } });
    
    // Check if token version matches the user's current token version
    if (decoded.tokenVersion !== undefined && decoded.tokenVersion !== user.tokenVersion) {
      return res.status(401).json({ error: { code: 'TOKEN_REVOKED', message: 'Token has been revoked' } });
    }

    (req as any).userId = decoded.userId;
    next();
  } catch (err: any) {
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ error: { code: 'TOKEN_EXPIRED', message: 'Token has expired' } });
    }
    res.status(401).json({ error: { code: 'UNAUTHORIZED', message: 'Invalid token' } });
  }
}
