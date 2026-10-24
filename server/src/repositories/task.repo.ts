import { prisma } from '../db';
import { Prisma } from '@prisma/client';
import { resolveTaskWorkload, computePayloadHash } from '../utils/task-workload.helper';

// ---------------------------------------------------------------------------
// Idempotency helpers (Phase 2B.2.2 / 2B.2.3)
// ---------------------------------------------------------------------------

function idempotencyConflict(): Error {
  const err: any = new Error('Idempotency conflict: operationId already used with different parameters');
  err.code = 'IDEMPOTENCY_CONFLICT';
  return err;
}

/** Returns the stored original response, or throws IDEMPOTENCY_CONFLICT if the operation differs. */
function replayFromOperation(
  op: { userId: string; taskId: string; payloadHash: string; responseBodyJson: string },
  userId: string,
  taskId: string,
  payloadHash: string
) {
  if (op.userId !== userId || op.taskId !== taskId || op.payloadHash !== payloadHash) {
    throw idempotencyConflict();
  }
  return JSON.parse(op.responseBodyJson);
}

/**
 * Runs an idempotent mutation. If two requests carrying the same operationId race, the loser's
 * TaskProgressOperation insert hits the unique constraint (P2002). On PostgreSQL that error aborts
 * the whole interactive transaction (any further query in it fails with 25P02) and every write in
 * it is rolled back - so recovery must happen here, AFTER the transaction, with a fresh query.
 */
async function withIdempotencyRecovery<T>(
  operationId: string | undefined,
  userId: string,
  taskId: string,
  payloadHash: string,
  run: () => Promise<T>
): Promise<T> {
  try {
    return await run();
  } catch (err: any) {
    if (operationId && err?.code === 'P2002') {
      const committed = await prisma.taskProgressOperation.findUnique({ where: { operationId } });
      if (committed) return replayFromOperation(committed, userId, taskId, payloadHash);
    }
    throw err;
  }
}

export class TaskRepository {
  async create(data: Prisma.TaskUncheckedCreateInput) {
    const status = data.status ?? 'PENDING';
    const remainingMinutes = data.remainingMinutes ?? (status === 'COMPLETED' ? 0 : data.estimateMinutes);
    const actualMinutes = data.actualMinutes ?? (data.completedMinutes ?? 0);
    return prisma.task.create({
      data: {
        ...data,
        actualMinutes,
        remainingMinutes,
        completedMinutes: data.completedMinutes ?? actualMinutes,
      }
    });
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

    // Retain explicit status if provided
    let newStatus = data.status ?? task.status;
    if (typeof newStatus === 'object' && newStatus !== null && 'set' in newStatus) newStatus = (newStatus as any).set;

    let targetRemaining = data.remainingMinutes;
    if (typeof targetRemaining === 'object' && targetRemaining !== null && 'set' in targetRemaining) targetRemaining = (targetRemaining as any).set;

    let targetCompleted = data.completedMinutes;
    if (typeof targetCompleted === 'object' && targetCompleted !== null && 'set' in targetCompleted) targetCompleted = (targetCompleted as any).set;

    let targetActual = data.actualMinutes;
    if (typeof targetActual === 'object' && targetActual !== null && 'set' in targetActual) targetActual = (targetActual as any).set;

    // Synchronize actualMinutes and completedMinutes if only one was passed
    if (targetCompleted != null && targetActual == null) {
      data.actualMinutes = targetCompleted;
    } else if (targetActual != null && targetCompleted == null) {
      data.completedMinutes = targetActual;
    }

    // Never auto-flip to COMPLETED simply because completedMinutes >= estimateMinutes!
    // Status only becomes COMPLETED if explicitly requested or if remainingMinutes is explicitly set to 0.
    if (data.status === undefined) {
      if (targetRemaining === 0) {
        data.status = 'COMPLETED';
      } else if (targetRemaining != null && (targetRemaining as number) > 0 && task.status === 'COMPLETED') {
        data.status = 'IN_PROGRESS';
      } else if (targetCompleted != null && (targetCompleted as number) < task.estimateMinutes && task.status === 'COMPLETED') {
        data.status = 'IN_PROGRESS';
        if (data.remainingMinutes === undefined) {
          data.remainingMinutes = Math.max(0, task.estimateMinutes - (targetCompleted as number));
        }
      }
    } else if (newStatus === 'COMPLETED') {
      if (data.remainingMinutes === undefined) {
        data.remainingMinutes = 0;
      }
    } else if (newStatus === 'IN_PROGRESS' && task.status === 'COMPLETED') {
      if (data.remainingMinutes === undefined && (task.remainingMinutes === 0 || task.remainingMinutes == null)) {
        const effectiveCompleted = targetCompleted ?? task.completedMinutes ?? 0;
        data.remainingMinutes = Math.max(1, task.estimateMinutes - (effectiveCompleted as number));
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

  async complete(id: string, userId: string, actualMinutes?: number, operationId?: string) {
    const payloadHash = computePayloadHash({ status: 'COMPLETED', actualMinutes });
    return withIdempotencyRecovery(operationId, userId, id, payloadHash, () => prisma.$transaction(async (tx) => {
      if (operationId) {
        const existingOp = await tx.taskProgressOperation.findUnique({
          where: { operationId }
        });
        if (existingOp) return replayFromOperation(existingOp, userId, id, payloadHash);
      }

      const task = await tx.task.findFirst({ where: { id, userId } });
      if (!task) throw new Error('Task not found or unauthorized');

      // Idempotency: If task is already COMPLETED, avoid duplicating disruption events
      if (task.status === 'COMPLETED') {
        if (operationId) {
          // A P2002 here propagates to withIdempotencyRecovery (the transaction is rolled back).
          await tx.taskProgressOperation.create({
            data: {
              operationId,
              userId,
              taskId: id,
              payloadHash,
              responseBodyJson: JSON.stringify(task),
            }
          });
        }
        return task;
      }

      const currentWorkload = resolveTaskWorkload(task);

      // If actualMinutes is provided, record it; otherwise preserve current cumulative actual effort
      const recordedActual = actualMinutes != null
        ? Math.max(0, actualMinutes)
        : (currentWorkload.actualMinutes > 0 ? currentWorkload.actualMinutes : task.estimateMinutes);

      await tx.task.update({
        where: { id },
        data: {
          actualMinutes: recordedActual,
          completedMinutes: recordedActual,
          remainingMinutes: 0,
          status: 'COMPLETED'
        }
      });

      // Mark blocks for this task in the latest schedule version as completed
      const latestVersion = await tx.scheduleVersion.findFirst({
        where: { userId },
        orderBy: { generatedAt: 'desc' }
      });
      if (latestVersion) {
        await tx.scheduleBlock.updateMany({
          where: { versionId: latestVersion.id, taskId: id },
          data: { isCompleted: true }
        });
      }

      // Record disruption event if actual effort differs from original estimate
      if (recordedActual !== task.estimateMinutes) {
        await tx.disruptionEvent.create({
          data: {
            userId,
            taskId: id,
            type: recordedActual > task.estimateMinutes ? 'OVERRUN' : 'EARLY_COMPLETION',
            plannedMinutes: task.estimateMinutes,
            actualMinutes: recordedActual
          }
        });
      }

      const completedTask = await tx.task.findUnique({ where: { id } });

      if (operationId) {
        // Recorded in the same transaction as the task update. A P2002 (concurrent duplicate)
        // rolls back this whole transaction and is resolved by withIdempotencyRecovery.
        await tx.taskProgressOperation.create({
          data: {
            operationId,
            userId,
            taskId: id,
            payloadHash,
            responseBodyJson: JSON.stringify(completedTask),
          }
        });
      }

      return completedTask;
    }));
  }

  async recordProgress(
    id: string,
    userId: string,
    params: {
      completedMinutes?: number;
      additionalMinutes?: number;
      actualMinutes?: number;
      remainingMinutes?: number;
      newEstimateMinutes?: number;
      status?: string;
    },
    operationId?: string
  ) {
    const payloadHash = computePayloadHash(params);
    return withIdempotencyRecovery(operationId, userId, id, payloadHash, () => prisma.$transaction(async (tx) => {
      if (operationId) {
        const existingOp = await tx.taskProgressOperation.findUnique({
          where: { operationId }
        });
        if (existingOp) return replayFromOperation(existingOp, userId, id, payloadHash);
      }

      const task = await tx.task.findFirst({ where: { id, userId } });
      if (!task) throw new Error('Task not found or unauthorized');

      const currentWorkload = resolveTaskWorkload(task);

      // 1. Calculate actual cumulative effort spent
      let newActual = currentWorkload.actualMinutes;
      if (params.actualMinutes != null && params.actualMinutes >= 0) {
        newActual = params.actualMinutes;
      } else if (params.additionalMinutes != null && params.additionalMinutes > 0) {
        newActual = currentWorkload.actualMinutes + params.additionalMinutes;
      } else if (params.completedMinutes != null && params.completedMinutes >= 0) {
        newActual = params.completedMinutes;
      }

      // 2. Estimate minutes (original baseline unless updated explicitly)
      let newEstimate = task.estimateMinutes;
      if (params.newEstimateMinutes != null && params.newEstimateMinutes > 0) {
        newEstimate = params.newEstimateMinutes;
      }

      // 3. Calculate remaining work to be scheduled
      let newRemaining = currentWorkload.remainingMinutes;
      if (params.status === 'COMPLETED') {
        newRemaining = 0;
      } else if (params.remainingMinutes != null && params.remainingMinutes >= 0) {
        newRemaining = params.remainingMinutes;
      } else if (params.newEstimateMinutes != null && params.newEstimateMinutes > 0) {
        newRemaining = Math.max(0, params.newEstimateMinutes - newActual);
      } else if (params.additionalMinutes != null && params.additionalMinutes > 0) {
        newRemaining = Math.max(0, currentWorkload.remainingMinutes - params.additionalMinutes);
      } else if (params.completedMinutes != null) {
        if (task.remainingMinutes == null) {
          // Backward compatibility for historical rows without explicit remainingMinutes
          newRemaining = Math.max(0, newEstimate - newActual);
        } else {
          const progressDelta = newActual - currentWorkload.actualMinutes;
          newRemaining = Math.max(0, currentWorkload.remainingMinutes - (progressDelta > 0 ? progressDelta : 0));
        }
      }

      // 4. Status determination
      let newStatus = params.status ?? task.status;
      if (params.status === undefined) {
        if (newRemaining === 0) {
          newStatus = 'COMPLETED';
        } else if (newRemaining > 0 && task.status === 'COMPLETED') {
          newStatus = 'IN_PROGRESS';
        } else if (newActual > 0 && (task.status === 'PENDING' || task.status === 'NOT_STARTED')) {
          newStatus = 'IN_PROGRESS';
        }
      } else if (params.status === 'COMPLETED') {
        newStatus = 'COMPLETED';
        newRemaining = 0;
      } else if (params.status === 'IN_PROGRESS') {
        // Explicit IN_PROGRESS: Must NEVER auto-complete even if newActual >= newEstimate
        newStatus = 'IN_PROGRESS';
      }

      await tx.task.update({
        where: { id },
        data: {
          actualMinutes: newActual,
          completedMinutes: newActual,
          remainingMinutes: newRemaining,
          estimateMinutes: newEstimate,
          status: newStatus
        }
      });

      if (newStatus === 'COMPLETED') {
        const latestVersion = await tx.scheduleVersion.findFirst({
          where: { userId },
          orderBy: { generatedAt: 'desc' }
        });
        if (latestVersion) {
          await tx.scheduleBlock.updateMany({
            where: { versionId: latestVersion.id, taskId: id },
            data: { isCompleted: true }
          });
        }
      }

      const updatedTask = await tx.task.findUnique({ where: { id } });

      if (operationId) {
        // Recorded in the same transaction as the task update. A P2002 (concurrent duplicate)
        // rolls back this whole transaction and is resolved by withIdempotencyRecovery.
        await tx.taskProgressOperation.create({
          data: {
            operationId,
            userId,
            taskId: id,
            payloadHash,
            responseBodyJson: JSON.stringify(updatedTask),
          }
        });
      }

      return updatedTask;
    }));
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
      const workload = resolveTaskWorkload(task);
      const remaining = workload.remainingMinutes;
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
            remainingMinutes: baseMinutes + (index < extraMinutes ? 1 : 0),
            actualMinutes: 0,
            completedMinutes: 0,
            deadline: task.deadline,
            academicWeight: task.academicWeight,
            teamImpactWeight: task.teamImpactWeight,
            cognitiveLoad: task.cognitiveLoad,
            status: 'PENDING'
          }
        }));
      }
      await tx.task.update({ where: { id }, data: { status: 'ARCHIVED', remainingMinutes: 0 } });
      return children;
    });
  }

  async findOperation(operationId: string, taskId: string, userId: string) {
    const op = await prisma.taskProgressOperation.findUnique({
      where: { operationId },
    });
    if (!op || op.userId !== userId || op.taskId !== taskId) {
      return null;
    }
    return {
      operationId: op.operationId,
      taskId: op.taskId,
      userId: op.userId,
      payloadHash: op.payloadHash,
      result: JSON.parse(op.responseBodyJson),
      createdAt: op.createdAt,
    };
  }
}

export const taskRepo = new TaskRepository();
