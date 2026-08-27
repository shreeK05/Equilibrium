import { prisma } from '../db';
import { Prisma } from '@prisma/client';

export class ScheduleRepository {
  async getLatestVersion(userId: string) {
    return prisma.scheduleVersion.findFirst({
      where: { userId },
      orderBy: { generatedAt: 'desc' },
      include: { blocks: true, decisionLogs: true }
    });
  }

  async getVersion(id: string, userId: string) {
    return prisma.scheduleVersion.findFirst({
      where: { id, userId },
      include: { blocks: true, decisionLogs: true }
    });
  }

  async getHistory(userId: string) {
    return prisma.scheduleVersion.findMany({
      where: { userId },
      orderBy: { generatedAt: 'desc' },
      take: 10
    });
  }

  async getLockedBlocks(versionId: string) {
    return prisma.scheduleBlock.findMany({
      where: { versionId, isLocked: true }
    });
  }

  async createSchedule(
    userId: string,
    triggerType: string,
    capacityMinutes: number,
    blocks: any[],
    logs: any[],
    previousVersionId?: string
  ) {
    return prisma.$transaction(async (tx) => {
      const version = await tx.scheduleVersion.create({
        data: {
          userId,
          triggerType,
          capacityMinutes,
          previousVersionId,
          blocks: {
            create: blocks.map(b => ({
              taskId: b.taskId,
              startTime: b.start,
              endTime: b.end,
              durationMinutes: b.durationMinutes,
              blockType: b.type,
              isLocked: b.isLocked,
              isCompleted: b.isCompleted || false
            }))
          },
          decisionLogs: {
            create: logs.map(l => ({
              taskId: l.taskId,
              decisionType: l.decisionType,
              priorityScore: l.priorityScore,
              priorityComponentsJson: JSON.stringify(l.priorityComponents),
              reasonCode: l.reasonCode,
              humanReadable: l.reasonCode
            }))
          }
        },
        include: { blocks: true, decisionLogs: true }
      });

      // Update deferral counts for tasks that were deferred or partially scheduled
      const deferredLogs = logs.filter(l => l.decisionType === 'DEFERRED' || l.decisionType === 'PARTIALLY_SCHEDULED');
      for (const log of deferredLogs) {
        await tx.task.update({
          where: { id: log.taskId },
          data: { deferralCount: { increment: 1 } }
        });
      }

      return version;
    });
  }
}

export const scheduleRepo = new ScheduleRepository();
