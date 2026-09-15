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

    let newStatus = data.status ?? task.status;
    let newCompleted = data.completedMinutes ?? task.completedMinutes;
    let newEstimate = data.estimateMinutes ?? task.estimateMinutes;

    if (typeof newCompleted === 'object' && newCompleted !== null && 'set' in newCompleted) newCompleted = newCompleted.set;
    if (typeof newEstimate === 'object' && newEstimate !== null && 'set' in newEstimate) newEstimate = newEstimate.set;

    if (typeof newCompleted === 'number' && typeof newEstimate === 'number') {
      if (newStatus === 'COMPLETED' && newCompleted < newEstimate && (data.status === undefined || data.status === 'COMPLETED')) {
        data.status = newCompleted > 0 ? 'IN_PROGRESS' : 'NOT_STARTED';
      } else if (newStatus !== 'COMPLETED' && newCompleted >= newEstimate && (data.status === undefined || data.status !== 'COMPLETED')) {
        data.status = 'COMPLETED';
      } else if (newStatus === 'NOT_STARTED' && newCompleted > 0 && newCompleted < newEstimate && (data.status === undefined || data.status === 'NOT_STARTED')) {
        data.status = 'IN_PROGRESS';
      } else if (newStatus === 'IN_PROGRESS' && newCompleted === 0 && (data.status === undefined || data.status === 'IN_PROGRESS')) {
        data.status = 'NOT_STARTED';
      }
    }

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

  async split(id: string, userId: string, parts: number) {
    return prisma.$transaction(async (tx) => {
      const task = await tx.task.findFirst({ where: { id, userId } });
      if (!task) throw new Error('Task not found or unauthorized');
      const remaining = Math.max(0, task.estimateMinutes - task.completedMinutes);
      if (remaining < parts) throw new Error('Task does not have enough remaining minutes to split');

      const baseMinutes = Math.floor(remaining / parts);
      const extraMinutes = remaining % parts;
      const children = [];
      for (let index = 0; index < parts; index += 1) {
        children.push(await tx.task.create({
          data: {
            userId,
            parentTaskId: task.id,
            title: `${task.title} (Part ${index + 1}/${parts})`,
            estimateMinutes: baseMinutes + (index < extraMinutes ? 1 : 0),
            deadline: task.deadline,
            academicWeight: task.academicWeight,
            teamImpactWeight: task.teamImpactWeight,
            cognitiveLoad: task.cognitiveLoad,
            status: 'PENDING'
          }
        }));
      }
      await tx.task.update({ where: { id }, data: { status: 'ARCHIVED' } });
      return children;
    });
  }
}

export const taskRepo = new TaskRepository();
