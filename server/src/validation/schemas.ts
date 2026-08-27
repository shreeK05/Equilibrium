import { z } from 'zod';

export const registerSchema = z.object({
  email: z.string().email().toLowerCase().max(255),
  password: z.string().min(8, 'Password must be at least 8 characters').max(128)
});

export const taskSchema = z.object({
  title: z.string().min(1).max(255),
  estimateMinutes: z.number().int().positive().max(10000), // reasonable sanity limit
  deadline: z.string().datetime(),
  academicWeight: z.number().min(0).max(1).optional(),
  teamImpactWeight: z.number().min(0).max(1).optional(),
  cognitiveLoad: z.enum(['LOW', 'MEDIUM', 'HIGH']).optional()
});

export const fixedCommitmentSchema = z.object({
  title: z.string().min(1).max(255),
  startTime: z.string().datetime(),
  endTime: z.string().datetime(),
  type: z.enum(['CLASS', 'LAB', 'EXAM', 'PERSONAL', 'CUSTOM']).optional(),
  recurrence: z.string().max(255).optional().nullable(),
  isActive: z.boolean().optional()
}).superRefine((data, ctx) => {
  const start = new Date(data.startTime).getTime();
  const end = new Date(data.endTime).getTime();
  if (end <= start) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'endTime must be strictly after startTime',
      path: ['endTime']
    });
  }
});

const timeRegex = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/;

function parseTime(timeStr: string): number {
  const [h, m] = timeStr.split(':').map(Number);
  return h! + (m! / 60);
}

export const constraintSchema = z.object({
  minSleepHours: z.number().min(7.0).max(12.0),
  sleepStart: z.string().regex(timeRegex, 'Invalid time format (HH:mm)'),
  sleepEnd: z.string().regex(timeRegex, 'Invalid time format (HH:mm)'),
  bufferMinutes: z.number().int().min(0).optional(),
  peakEnergyWindowsJson: z.string().optional()
}).superRefine((data, ctx) => {
  // 1. Validate Sleep Duration Semantics
  const start = parseTime(data.sleepStart);
  const end = parseTime(data.sleepEnd);
  
  let sleepDuration = end - start;
  if (sleepDuration <= 0) {
    sleepDuration += 24; // Overnight logic
  }

  // Prevent absurdly long sleep windows (e.g., 23 hours)
  if (sleepDuration > 16) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Sleep interval cannot exceed 16 hours. Please check your AM/PM logic.',
      path: ['sleepEnd']
    });
  }

  // Ensure window fits the required minimum
  if (sleepDuration < data.minSleepHours) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      message: 'Sleep interval cannot be strictly less than minSleepHours',
      path: ['sleepEnd']
    });
  }

  // 2. Validate Energy Windows JSON Structure
  if (data.peakEnergyWindowsJson) {
    try {
      const parsed = JSON.parse(data.peakEnergyWindowsJson);
      if (!Array.isArray(parsed)) throw new Error('Must be an array of windows');
      
      for (const win of parsed) {
        if (!win.start || !timeRegex.test(win.start)) throw new Error('Invalid window start time');
        if (!win.end || !timeRegex.test(win.end)) throw new Error('Invalid window end time');
        
        const wStart = parseTime(win.start);
        const wEnd = parseTime(win.end);
        
        // Demand same-day windows for energy to prevent ambiguous wrapping logic
        if (wEnd <= wStart) {
          throw new Error('Energy window must start and end on the same day (start < end)');
        }
      }
    } catch (e: any) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        message: `Invalid peakEnergyWindowsJson: ${e.message}`,
        path: ['peakEnergyWindowsJson']
      });
    }
  }
});
