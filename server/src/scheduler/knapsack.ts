import { TaskInput } from './types';

export interface KnapsackItem {
  task: TaskInput;
  priority: number;
  weightSlots: number;
}

export function solveKnapsack(items: KnapsackItem[], capacitySlots: number): Set<string> {
  const n = items.length;
  // Sort items deterministically for tie-breaking:
  // 1. Priority desc, 2. Deadline asc, 3. Academic Weight desc, 4. ID asc
  items.sort((a, b) => {
    if (Math.abs(b.priority - a.priority) > 0.0001) return b.priority - a.priority;
    if (a.task.deadline.getTime() !== b.task.deadline.getTime()) return a.task.deadline.getTime() - b.task.deadline.getTime();
    if (b.task.academicWeight !== a.task.academicWeight) return b.task.academicWeight - a.task.academicWeight;
    return a.task.id.localeCompare(b.task.id);
  });

  // dp[i][w] max value considering first i items up to weight w
  const dp = Array.from({ length: n + 1 }, () => Array(capacitySlots + 1).fill(0));

  for (let i = 1; i <= n; i++) {
    const item = items[i - 1];
    const w = item.weightSlots;
    const v = item.priority;

    for (let wCap = 0; wCap <= capacitySlots; wCap++) {
      if (w <= wCap) {
        dp[i][wCap] = Math.max(dp[i - 1][wCap], dp[i - 1][wCap - w] + v);
      } else {
        dp[i][wCap] = dp[i - 1][wCap];
      }
    }
  }

  // Backtrack to find selected tasks
  let wCap = capacitySlots;
  const selectedIds = new Set<string>();
  
  for (let i = n; i > 0; i--) {
    if (dp[i][wCap] !== dp[i - 1][wCap]) {
      const item = items[i - 1];
      selectedIds.add(item.task.id);
      wCap -= item.weightSlots;
    }
  }

  return selectedIds;
}
