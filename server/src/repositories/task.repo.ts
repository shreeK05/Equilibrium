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
    const task = await this.findById(id, userId);
    if (!task) throw new Error('Task not found or unauthorized');
    return prisma.task.update({ where: { id }, data });
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
}

export const taskRepo = new TaskRepository();
