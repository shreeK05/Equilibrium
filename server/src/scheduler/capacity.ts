import { intervalsIntersect, parseTimeStrToDate } from './guard';
import { ConstraintInput, FixedCommitment, ScheduleBlock } from './types';

export interface Slot {
  index: number;
  start: Date;
  end: Date;
  available: boolean;
  energyBonus: boolean;
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
  // Apply sleep shield for each unique day in horizon
  const days = new Set(slots.map(s => {
    const d = new Date(s.start);
    d.setUTCHours(0, 0, 0, 0);
    return d.toISOString();
  }));

  days.forEach(dayStr => {
    const baseDate = new Date(dayStr);
    let sleepStart = parseTimeStrToDate(baseDate, constraints.sleepStart);
    let sleepEnd = parseTimeStrToDate(baseDate, constraints.sleepEnd);
    
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
      }
    });
  });

  // Apply Fixed Commitments
  fixed.forEach(f => {
    slots.forEach(slot => {
      if (intervalsIntersect(slot.start, slot.end, f.start, f.end)) {
        slot.available = false;
      }
    });
  });

  // Apply Locked Blocks (past chunks)
  lockedBlocks.filter(b => b.isLocked).forEach(b => {
    slots.forEach(slot => {
      if (intervalsIntersect(slot.start, slot.end, b.start, b.end)) {
        slot.available = false;
      }
    });
  });

  // Apply Energy Windows
  days.forEach(dayStr => {
    const baseDate = new Date(dayStr);
    constraints.peakEnergyWindows.forEach(window => {
      let wStart = parseTimeStrToDate(baseDate, window.start);
      let wEnd = parseTimeStrToDate(baseDate, window.end);
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
