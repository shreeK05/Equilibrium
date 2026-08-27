import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { userRepo } from '../repositories/user.repo';
import { config } from '../config';
import { constraintRepo } from '../repositories/constraint.repo';

export class AuthService {
  async register(email: string, passwordHashRaw: string) {
    const existing = await userRepo.findByEmail(email);
    if (existing) throw new Error('Email in use');
    
    const passwordHash = await bcrypt.hash(passwordHashRaw, 10);
    const user = await userRepo.create({ email, passwordHash });
    
    // Create default constraints
    await constraintRepo.upsert(user.id, {
      minSleepHours: 7.0,
      sleepStart: '23:00',
      sleepEnd: '06:00',
      bufferMinutes: 30,
      peakEnergyWindowsJson: '[]'
    });

    const token = jwt.sign({ userId: user.id }, config.jwtSecret, { expiresIn: '7d' });
    return { token, user: { id: user.id, email } };
  }

  async login(email: string, passwordHashRaw: string) {
    const user = await userRepo.findByEmail(email);
    if (!user) throw new Error('Invalid credentials');
    
    const valid = await bcrypt.compare(passwordHashRaw, user.passwordHash);
    if (!valid) throw new Error('Invalid credentials');

    const token = jwt.sign({ userId: user.id }, config.jwtSecret, { expiresIn: '7d' });
    return { token, user: { id: user.id, email } };
  }
}

export const authService = new AuthService();
