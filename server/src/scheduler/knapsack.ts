import { TaskInput } from './types';

export interface KnapsackItem {
  task: TaskInput;
  priority: number;
  weightSlots: number;
  deadlineCapacity?: number;
  deadlineSlots?: number; // backwards-compatible alias
}

export function solveKnapsack(items: KnapsackItem[], capacitySlots: number): Set<string> {
  const n = items.length;
  if (n === 0 || capacitySlots <= 0) return new Set<string>();

  // Sort items deterministically for EDF and tie-breaking:
  // 1. deadlineCapacity asc (EDF order enforces chronological prefix deadline feasibility)
  // 2. deadline timestamp asc (chronological tie-breaking when two tasks have same available slot count)
  // 3. priority desc
  // 4. academic weight desc
  // 5. task ID asc
  items.sort((a, b) => {
    const dLimitA = a.deadlineCapacity ?? a.deadlineSlots ?? capacitySlots;
    const dLimitB = b.deadlineCapacity ?? b.deadlineSlots ?? capacitySlots;
    if (dLimitA !== dLimitB) return dLimitA - dLimitB;
    if (a.task.deadline.getTime() !== b.task.deadline.getTime()) return a.task.deadline.getTime() - b.task.deadline.getTime();
    if (Math.abs(b.priority - a.priority) > 0.0001) return b.priority - a.priority;
    if (b.task.academicWeight !== a.task.academicWeight) return b.task.academicWeight - a.task.academicWeight;
    return a.task.id.localeCompare(b.task.id);
  });

  // dp[i][w] = max priority considering first i items using exactly w slots (-1 if unreachable)
  const dp = Array.from({ length: n + 1 }, () => Array(capacitySlots + 1).fill(-1));
  const taken = Array.from({ length: n + 1 }, () => Array(capacitySlots + 1).fill(false));
  dp[0][0] = 0;

  for (let i = 1; i <= n; i++) {
    const item = items[i - 1];
    const w = item.weightSlots;
    const v = item.priority;
    const dLimit = Math.min(item.deadlineCapacity ?? item.deadlineSlots ?? capacitySlots, capacitySlots);

    // 1. Option: do not include item i
    for (let c = 0; c <= capacitySlots; c++) {
      dp[i][c] = dp[i - 1][c];
      taken[i][c] = false;
    }

    // 2. Option: include item i
    // In EDF order, all items in 1..i have deadline limit <= dLimit.
    // Thus the cumulative slots used up through item i cannot exceed dLimit.
    if (w > 0 && w <= dLimit) {
      for (let prevW = 0; prevW <= dLimit - w; prevW++) {
        if (dp[i - 1][prevW] < 0) continue;
        const newW = prevW + w;
        const candidateVal = dp[i - 1][prevW] + v;
        if (candidateVal > dp[i][newW] + 0.000001) {
          dp[i][newW] = candidateVal;
          taken[i][newW] = true;
        }
      }
    }
  }

  // Find the reachable weight that maximizes total priority
  let maxScore = 0;
  let bestW = 0;
  for (let c = 0; c <= capacitySlots; c++) {
    if (dp[n][c] > maxScore + 0.000001) {
      maxScore = dp[n][c];
      bestW = c;
    }
  }

  // Backtrack to find selected tasks
  let currW = bestW;
  const selectedIds = new Set<string>();

  for (let i = n; i > 0; i--) {
    if (taken[i][currW]) {
      const item = items[i - 1];
      selectedIds.add(item.task.id);
      currW -= item.weightSlots;
    }
  }

  return selectedIds;
}
