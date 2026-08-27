export interface TaskInput {
  id: string;
  estimateMinutes: number;
  completedMinutes: number;
  remainingMinutes: number;
  deadline: Date;
  academicWeight: number; // 0.0 - 1.0
  teamImpact: number; // 0.0 - 1.0
  cognitiveLoad: 'LOW' | 'MEDIUM' | 'HIGH';
  deferralCount: number;
}

export interface ConstraintInput {
  sleepStart: string; // "23:00"
  sleepEnd: string;   // "06:00"
  minSleepHours: number; // >= 7.0
  peakEnergyWindows: Array<{ start: string, end: string }>;
}

export interface FixedCommitment {
  id: string;
  start: Date;
  end: Date;
}

export interface ScheduleBlock {
  taskId?: string;
  type: 'TASK' | 'SLEEP' | 'FIXED' | 'BUFFER';
  start: Date;
  end: Date;
  durationMinutes: number;
  isLocked: boolean;
}

export interface DecisionLog {
  taskId: string;
  decisionType: 'FULLY_SCHEDULED' | 'PARTIALLY_SCHEDULED' | 'DEFERRED';
  priorityScore: number;
  priorityComponents: any;
  scheduledMinutes: number;
  deferredMinutes: number;
  reasonCode: string;
}
