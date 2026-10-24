/**
 * Task Workload Semantics Helper (Equilibrium Phase 2B.2.1)
 *
 * Clearly separates:
 * 1. Original task estimate (estimateMinutes)
 * 2. Actual cumulative effort spent (actualMinutes)
 * 3. Current estimated work remaining to be scheduled (remainingMinutes)
 * 4. Explicit task status (status: PENDING, IN_PROGRESS, COMPLETED, ARCHIVED)
 */

export interface TaskWorkloadFields {
  estimateMinutes: number;
  completedMinutes?: number | null;
  actualMinutes?: number | null;
  remainingMinutes?: number | null;
  status?: string | null;
}

export interface ResolvedTaskWorkload {
  estimateMinutes: number;
  actualMinutes: number;
  remainingMinutes: number;
  completedMinutes: number;
  status: string;
}

/**
 * Resolves trustworthy workload dimensions for any task record.
 * Handles existing/legacy rows gracefully without fabricating historical effort.
 */
export function resolveTaskWorkload(task: TaskWorkloadFields): ResolvedTaskWorkload {
  const status = task.status ?? 'PENDING';
  const isCompleted = status === 'COMPLETED';

  // Actual effort spent (defaults to actualMinutes, or completedMinutes for legacy rows)
  const actualMinutes = task.actualMinutes != null
    ? Math.max(0, task.actualMinutes)
    : Math.max(0, task.completedMinutes ?? 0);

  // Remaining work to be scheduled
  let remainingMinutes: number;
  if (isCompleted) {
    remainingMinutes = 0;
  } else if (task.remainingMinutes != null) {
    remainingMinutes = Math.max(0, task.remainingMinutes);
  } else {
    // Backward compatibility for historical rows
    remainingMinutes = Math.max(0, task.estimateMinutes - (task.completedMinutes ?? 0));
  }

  return {
    estimateMinutes: task.estimateMinutes,
    actualMinutes,
    remainingMinutes,
    completedMinutes: task.completedMinutes ?? actualMinutes,
    status
  };
}

import { createHash } from 'crypto';

export function computePayloadHash(params: {
  completedMinutes?: number;
  additionalMinutes?: number;
  actualMinutes?: number;
  remainingMinutes?: number | null;
  newEstimateMinutes?: number;
  status?: string;
}): string {
  const canonical = {
    completedMinutes: params.completedMinutes ?? null,
    additionalMinutes: params.additionalMinutes ?? null,
    actualMinutes: params.actualMinutes ?? null,
    remainingMinutes: params.remainingMinutes ?? null,
    newEstimateMinutes: params.newEstimateMinutes ?? null,
    status: params.status ?? null,
  };
  return createHash('sha256').update(JSON.stringify(canonical)).digest('hex');
}
