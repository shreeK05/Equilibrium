/**
 * Single source of truth for which IANA timezone a user's constraints are interpreted in.
 *
 * Root cause of the 03:30 IST Sleep Shield violation (Oct 2026): users registered through the
 * mobile app never sent a timezone, so the Prisma default "UTC" was stored. The engine then read
 * a "23:00–07:00" sleep window as 23:00–07:00 *UTC* (= 04:30–12:30 IST), leaving 23:00–04:30 IST
 * open for placement. Every scheduling entry point must resolve the zone through this module.
 */
export const DEFAULT_TIMEZONE = 'Asia/Kolkata';

export function isValidTimezone(tz: unknown): tz is string {
  if (typeof tz !== 'string' || tz.trim() === '') return false;
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: tz });
    return true;
  } catch {
    return false;
  }
}

/** Returns a valid IANA zone, falling back to the product default (IST) for missing/invalid values. */
export function resolveTimezone(tz: unknown): string {
  return isValidTimezone(tz) ? tz : DEFAULT_TIMEZONE;
}
