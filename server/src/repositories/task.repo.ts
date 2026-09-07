import { prisma } from '../db';
import { Prisma } from '@prisma/client';

export class TaskRepository {
  async create(data: Prisma.TaskUncheckedCreateInput) {
    return prisma.task.create({ data });
  }

  async findById(id: string, userId: string) {
    return prisma.task.findFirst({ where: { id, userId } });
  }

  async findMany(userId: string) {
    return prisma.task.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  async safeUpdate(id: string, userId: string, data: Prisma.TaskUpdateInput) {
    const result = await prisma.task.updateMany({
      where: { id, userId },
      data: data as Prisma.TaskUncheckedUpdateManyInput
    });
    if (result.count === 0) throw new Error('Task not found or unauthorized');
    return this.findById(id, userId);
  }

  async delete(id: string, userId: string) {
    const task = await this.findById(id, userId);
    if (!task) throw new Error('Task not found or unauthorized');
    return prisma.task.delete({ where: { id } });
  }

  async findActiveTasks(userId: string) {
    return prisma.task.findMany({
      where: { userId, status: { notIn: ['COMPLETED', 'ARCHIVED'] } }
    });
  }

  async complete(id: string, userId: string, actualMinutes: number) {
    return prisma.$transaction(async (tx) => {
      const task = await tx.task.findFirst({ where: { id, userId } });
      if (!task) throw new Error('Task not found or unauthorized');

      const completedMinutes = Math.min(task.estimateMinutes, Math.max(task.completedMinutes, actualMinutes));
      await tx.task.update({
        where: { id },
        data: { completedMinutes, status: 'COMPLETED' }
      });
      await tx.disruptionEvent.create({
        data: {
          userId,
          taskId: id,
          type: actualMinutes > task.estimateMinutes ? 'OVERRUN' : 'EARLY_COMPLETION',
          plannedMinutes: task.estimateMinutes,
          actualMinutes
        }
      });

      return tx.task.findUnique({ where: { id } });
    });
  }

  async debtLedger(userId: string) {
    return prisma.task.findMany({
      where: { userId, status: { notIn: ['COMPLETED', 'ARCHIVED'] } },
      orderBy: [{ deferralCount: 'desc' }, { deadline: 'asc' }],
      select: {
        id: true,
        title: true,
        deadline: true,
        estimateMinutes: true,
        completedMinutes: true,
        deferralCount: true,
        status: true,
        academicWeight: true,
        teamImpactWeight: true
      }
    });
  }
}

export const taskRepo = new TaskRepository();
