import bcrypt from 'bcrypt';
import jwt from 'jsonwebtoken';
import { userRepo } from '../repositories/user.repo';
import { config } from '../config';
import { constraintRepo } from '../repositories/constraint.repo';
import crypto from 'crypto';
import { prisma } from '../db';

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

  async forgotPassword(email: string) {
    const user = await userRepo.findByEmail(email);
    if (!user) return; // Do not reveal if email exists

    // Generate secure random token
    const token = crypto.randomBytes(32).toString('hex');
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    // Expire in 15 minutes
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    // Invalidate existing active reset tokens for this user
    await prisma.passwordResetToken.deleteMany({
      where: { userId: user.id, usedAt: null }
    });

    await prisma.passwordResetToken.create({
      data: {
        userId: user.id,
        tokenHash,
        expiresAt,
      }
    });

    // NOTE: EMAIL DELIVERY IS NOT CONFIGURED IN PRODUCTION.
    // In a real production environment, you would send an email here using a provider (e.g., Resend, Sendgrid, AWS SES).
    // The email would contain a link: https://your-domain.com/reset-password?token=${token}
    // We do NOT log the raw token or return it in the API response to maintain security.
    return;
  }

  async resetPassword(token: string, newPasswordRaw: string) {
    const tokenHash = crypto.createHash('sha256').update(token).digest('hex');

    const resetRecord = await prisma.passwordResetToken.findUnique({
      where: { tokenHash }
    });

    if (!resetRecord || resetRecord.usedAt || resetRecord.expiresAt < new Date()) {
      throw new Error('Invalid or expired reset token');
    }

    const passwordHash = await bcrypt.hash(newPasswordRaw, 10);

    // Run password update and token invalidation in a transaction to prevent race conditions
    await prisma.$transaction([
      prisma.user.update({
        where: { id: resetRecord.userId },
        data: { passwordHash }
      }),
      prisma.passwordResetToken.update({
        where: { id: resetRecord.id },
        data: { usedAt: new Date() }
      })
    ]);

    // NOTE: If the authentication architecture used stateful sessions (e.g., stored refresh tokens),
    // they should be revoked here. Since it uses stateless JWTs without a denylist, we cannot securely
    // revoke existing JWTs. The user is strongly recommended to implement a refresh-token architecture or
    // a token generation counter on the User model to invalidate all previous JWTs on password reset.
    return { success: true };
  }
}

export const authService = new AuthService();
