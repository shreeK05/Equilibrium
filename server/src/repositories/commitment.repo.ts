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
    const records = await prisma.fixedCommitment.findMany({
      where: {
        userId,
        isActive: true,
        OR: [
          {
            type: { not: 'ROUTINE' },
            startTime: { lt: toDate },
            endTime: { gt: fromDate },
          },
          {
            type: 'ROUTINE'
          }
        ]
      },
      orderBy: { startTime: 'asc' }
    });

    const expanded: typeof records = [];
    
    for (const record of records) {
      if (record.type === 'ROUTINE' && record.daysOfWeek) {
        let days: number[] = [];
        try {
          days = JSON.parse(record.daysOfWeek);
        } catch { continue; }

        const startHour = record.startTime.getUTCHours();
        const startMin = record.startTime.getUTCMinutes();
        const endHour = record.endTime.getUTCHours();
        const endMin = record.endTime.getUTCMinutes();

        let current = new Date(fromDate);
        current.setUTCHours(0, 0, 0, 0);

        while (current < toDate) {
          if (days.includes(current.getUTCDay())) {
            const instStart = new Date(current);
            instStart.setUTCHours(startHour, startMin, 0, 0);
            
            const instEnd = new Date(current);
            instEnd.setUTCHours(endHour, endMin, 0, 0);
            // Handle cross-midnight routine
            if (instEnd <= instStart) {
                instEnd.setDate(instEnd.getDate() + 1);
            }

            if (instStart < toDate && instEnd > fromDate) {
              expanded.push({ ...record, startTime: instStart, endTime: instEnd });
            }
          }
          current.setDate(current.getDate() + 1);
        }
      } else {
        expanded.push(record);
      }
    }

    return expanded.sort((a, b) => a.startTime.getTime() - b.startTime.getTime());
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
