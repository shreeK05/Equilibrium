import { toDate } from 'date-fns-tz';

export function intervalsIntersect(startA: Date, endA: Date, startB: Date, endB: Date): boolean {
  return startA < endB && startB < endA;
}

export function parseTimeStrToDate(dateStr: string, timeStr: string, timezone: string = 'Asia/Kolkata'): Date {
  const [hours, minutes] = timeStr.split(':');
  const isoStr = `${dateStr}T${hours}:${minutes}:00`;
  return toDate(isoStr, { timeZone: timezone });
}
