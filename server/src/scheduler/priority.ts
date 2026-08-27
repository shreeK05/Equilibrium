import { TaskInput } from './types';

export const MAX_DEFERRALS = 5;
export const ALPHA = 2.0; // Academic
export const BETA = 1.5;  // Urgency
export const GAMMA = 1.0; // Team
export const DELTA = 1.0; // Debt

export function calculatePriority(task: TaskInput, now: Date) {
  const academic = task.academicWeight * ALPHA;
  
  const hoursToDeadline = Math.max(0, (task.deadline.getTime() - now.getTime()) / 3600000);
  const urgency = BETA * (1 / (hoursToDeadline + 1));
  
  const team = task.teamImpact * GAMMA;
  const debt = DELTA * Math.min(task.deferralCount / MAX_DEFERRALS, 1.0);
  
  const score = academic + urgency + team + debt;
  
  return {
    score,
    components: { academic, urgency, team, debt }
  };
}
