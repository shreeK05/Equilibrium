import { format } from 'date-fns-tz';
import { intervalsIntersect, parseTimeStrToDate } from './guard';
import { ConstraintInput, FixedCommitment, ScheduleBlock } from './types';

export interface Slot {
  index: number;
  start: Date;
  end: Date;
  available: boolean;
  energyBonus: boolean;
  blockedReason?: string;
  blockedTitle?: string;
}

export function generateSlots(horizonStart: Date, horizonEnd: Date): Slot[] {
  const slots: Slot[] = [];
  let current = new Date(horizonStart);
  let index = 0;
  while (current < horizonEnd) {
    const next = new Date(current.getTime() + 30 * 60000);
    slots.push({ index, start: current, end: next, available: true, energyBonus: false });
    current = next;
    index++;
  }
  return slots;
}

export function applyConstraints(
  slots: Slot[],
  constraints: ConstraintInput,
  fixed: FixedCommitment[],
  lockedBlocks: ScheduleBlock[]
) {
  const tz = constraints.timezone || 'Asia/Kolkata';

  // Apply sleep shield for each unique day in horizon
  const days = new Set(slots.map(s => {
    return format(s.start, 'yyyy-MM-dd', { timeZone: tz });
  }));

  days.forEach(dayStr => {
    let sleepStart = parseTimeStrToDate(dayStr, constraints.sleepStart, tz);
    let sleepEnd = parseTimeStrToDate(dayStr, constraints.sleepEnd, tz);
    
    // Handle midnight crossing
    if (sleepEnd <= sleepStart) {
      sleepEnd = new Date(sleepEnd.getTime() + 24 * 60 * 60000);
    }
    // Also apply previous day's crossing sleep if applicable
    const prevSleepStart = new Date(sleepStart.getTime() - 24 * 60 * 60000);
    const prevSleepEnd = new Date(sleepEnd.getTime() - 24 * 60 * 60000);

    slots.forEach(slot => {
      if (intervalsIntersect(slot.start, slot.end, sleepStart, sleepEnd) ||
          intervalsIntersect(slot.start, slot.end, prevSleepStart, prevSleepEnd)) {
        slot.available = false;
        slot.blockedReason = 'SLEEP';
      }
    });
  });

  // Apply Enabled Routines (Meals, Personal Essentials, Breaks)
  if (constraints.routines && constraints.routines.length > 0) {
    const enabledRoutines = constraints.routines.filter(r => r.isEnabled);
    days.forEach(dayStr => {
      const dayDate = parseTimeStrToDate(dayStr, '12:00', tz);
      const dayOfWeek = dayDate.getDay();

      enabledRoutines.forEach(routine => {
        if (routine.daysOfWeek && routine.daysOfWeek.length > 0 && !routine.daysOfWeek.includes(dayOfWeek)) {
          return;
        }
        let rStart = parseTimeStrToDate(dayStr, routine.startTime, tz);
        let rEnd = parseTimeStrToDate(dayStr, routine.endTime, tz);
        if (rEnd <= rStart) {
          rEnd = new Date(rEnd.getTime() + 24 * 60 * 60000);
        }
        const prevRStart = new Date(rStart.getTime() - 24 * 60 * 60000);
        const prevREnd = new Date(rEnd.getTime() - 24 * 60 * 60000);

        slots.forEach(slot => {
          if (intervalsIntersect(slot.start, slot.end, rStart, rEnd) ||
              intervalsIntersect(slot.start, slot.end, prevRStart, prevREnd)) {
            slot.available = false;
            slot.blockedReason = routine.category || 'ROUTINE';
            slot.blockedTitle = routine.title;
          }
        });
      });
    });
  }

  // Apply Preferred Study Hours (if configured)
  if (constraints.preferredStudyHours) {
    const { start: pStartStr, end: pEndStr } = constraints.preferredStudyHours;
    days.forEach(dayStr => {
      let pStart = parseTimeStrToDate(dayStr, pStartStr, tz);
      let pEnd = parseTimeStrToDate(dayStr, pEndStr, tz);
      if (pEnd <= pStart) {
        pEnd = new Date(pEnd.getTime() + 24 * 60 * 60000);
      }
      slots.forEach(slot => {
        // Slot must be entirely within preferred study hours
        if (slot.start < pStart || slot.end > pEnd) {
          slot.available = false;
          if (!slot.blockedReason) slot.blockedReason = 'OUTSIDE_PREFERRED_HOURS';
        }
      });
    });
  }

  // Apply Fixed Commitments
  const bufferMinutes = constraints.bufferMinutes ?? 0;
  fixed.forEach(f => {
    const bufferBefore = new Date(f.start.getTime() - bufferMinutes * 60000);
    const bufferAfter = new Date(f.end.getTime() + bufferMinutes * 60000);
    slots.forEach(slot => {
      if (intervalsIntersect(slot.start, slot.end, bufferBefore, bufferAfter)) {
        slot.available = false;
        slot.blockedReason = 'FIXED';
        slot.blockedTitle = f.title;
      }
    });
  });

  // Apply Locked Blocks (past chunks)
  lockedBlocks.filter(b => b.isLocked).forEach(b => {
    slots.forEach(slot => {
      if (intervalsIntersect(slot.start, slot.end, b.start, b.end)) {
        slot.available = false;
        slot.blockedReason = 'LOCKED';
      }
    });
  });

  // Apply Energy Windows
  days.forEach(dayStr => {
    (constraints.peakEnergyWindows || []).forEach(window => {
      let wStart = parseTimeStrToDate(dayStr, window.start, tz);
      let wEnd = parseTimeStrToDate(dayStr, window.end, tz);
      if (wEnd <= wStart) {
          wEnd = new Date(wEnd.getTime() + 24 * 60 * 60000);
      }
      slots.forEach(slot => {
        if (intervalsIntersect(slot.start, slot.end, wStart, wEnd)) {
          slot.energyBonus = true;
        }
      });
    });
  });
}

