export function intervalsIntersect(startA: Date, endA: Date, startB: Date, endB: Date): boolean {
  return startA < endB && startB < endA;
}

export function parseTimeStrToDate(baseDate: Date, timeStr: string): Date {
  const [hours, minutes] = timeStr.split(':').map(Number);
  const d = new Date(baseDate);
  d.setUTCHours(hours, minutes, 0, 0);
  return d;
}
