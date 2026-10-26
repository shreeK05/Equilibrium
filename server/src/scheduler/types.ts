export interface TaskInput {
  id: string;
  title: string;
  estimateMinutes: number;
  completedMinutes: number;
  remainingMinutes: number;
  deadline: Date;
  academicWeight: number; // 0.0 - 1.0
  teamImpact: number; // 0.0 - 1.0
  cognitiveLoad: 'LOW' | 'MEDIUM' | 'HIGH';
  deferralCount: number;
  dailyTargetMinutes?: number | null; // Optional: cap minutes scheduled per day
}

export interface RoutineInput {
  id?: string;
  title: string;
  category: 'MEAL' | 'BREAK' | 'EXERCISE' | 'COMMUTE' | 'PERSONAL';
  startTime: string; // "13:00"
  endTime: string;   // "14:00"
  daysOfWeek?: number[]; // [0-6], 0=Sun, 1=Mon, etc. If empty, applies daily
  isEnabled: boolean;
}

export interface ConstraintInput {
  sleepStart: string; // "23:00"
  sleepEnd: string;   // "06:00"
  minSleepHours: number; // >= 7.0
  bufferMinutes: number;
  peakEnergyWindows: Array<{ start: string, end: string }>;
  timezone?: string; // e.g. "Asia/Kolkata"
  routines?: RoutineInput[];
  maxDailyStudyMinutes?: number; // Configurable daily workload cap
  preferredStudyHours?: { start: string; end: string }; // e.g. "08:00" to "22:00"
  maxFocusSessionMinutes?: number; // e.g. 90 or 120 mins before a break
  breakDurationMinutes?: number; // e.g. 15 mins transition buffer
}

export interface FixedCommitment {
  id: string;
  start: Date;
  end: Date;
  title?: string;
  type?: string;
}

export interface ScheduleBlock {
  taskId?: string;
  type: 'TASK' | 'SLEEP' | 'FIXED' | 'BUFFER' | 'ROUTINE' | 'MEAL' | 'BREAK';
  start: Date;
  end: Date;
  durationMinutes: number;
  isLocked: boolean;
  title?: string;
}

export interface DecisionLog {
  taskId: string;
  decisionType: 'FULLY_SCHEDULED' | 'PARTIALLY_SCHEDULED' | 'DEFERRED';
  priorityScore: number;
  priorityComponents: any;
  scheduledMinutes: number;
  deferredMinutes: number;
  reasonCode: 'SUCCESS' | 'NO_AVAILABLE_SLOTS' | 'CAPACITY_EXCEEDED' | 'DAILY_TARGET_PACING' | 'FRAGMENTED_CAPACITY' | 'MEAL_ROUTINE_CONFLICT' | 'DEADLINE_IN_PAST' | string;
  humanReadable: string;
}

