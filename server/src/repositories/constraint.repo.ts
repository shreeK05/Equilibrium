import { prisma } from '../db';
import { Prisma } from '@prisma/client';

export class ConstraintRepository {
  async findByUserId(userId: string) {
    return prisma.userConstraint.findUnique({ where: { userId } });
  }

  async upsert(userId: string, data: any) {
    return prisma.userConstraint.upsert({
      where: { userId },
      create: { 
        minSleepHours: 7.0,
        sleepStart: '23:00',
        sleepEnd: '06:00',
        bufferMinutes: 30,
        peakEnergyWindowsJson: '[]',
        ...data, 
        user: { connect: { id: userId } } 
      },
      update: data
    });
  }
}

export const constraintRepo = new ConstraintRepository();
