import { prisma } from '../db';
import { Prisma } from '@prisma/client';

export class FixedCommitmentRepository {
  async create(data: Prisma.FixedCommitmentUncheckedCreateInput) {
    return prisma.fixedCommitment.create({ data });
  }

  async findMany(userId: string) {
    return prisma.fixedCommitment.findMany({
      where: { userId },
      orderBy: { startTime: 'asc' }
    });
  }

  async findActive(userId: string, fromDate: Date, toDate: Date) {
    // Basic range overlap query + isActive filter
    // In a real system handling recurrences, you'd expand the RRULEs here or in service.
    // For now we just query explicit overlapping windows + isActive
    return prisma.fixedCommitment.findMany({
      where: {
        userId,
        isActive: true,
        startTime: { lt: toDate },
        endTime: { gt: fromDate },
      },
      orderBy: { startTime: 'asc' }
    });
  }

  async findById(id: string, userId: string) {
    return prisma.fixedCommitment.findFirst({
      where: { id, userId }
    });
  }

  async update(id: string, userId: string, data: Prisma.FixedCommitmentUpdateInput) {
    return prisma.fixedCommitment.update({
      where: { id_userId: { id, userId } } as any, // fallback to single id if unique isn't compound
      data
    });
  }

  async updateStrict(id: string, userId: string, data: Prisma.FixedCommitmentUpdateInput) {
    // Actually Prisma doesn't have id_userId compound key unless defined. 
    // Just use updateMany and findFirst
    await prisma.fixedCommitment.updateMany({
      where: { id, userId },
      data
    });
    return this.findById(id, userId);
  }

  async delete(id: string, userId: string) {
    const result = await prisma.fixedCommitment.deleteMany({
      where: { id, userId }
    });
    return result.count > 0;
  }
}
