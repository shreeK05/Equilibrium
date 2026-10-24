/**
 * Workload and Capacity Calculation Helpers (Equilibrium Phase 2B.1.3)
 *
 * Centralizes the calculation of actual daily sleep duration from [sleepStart, sleepEnd]
 * and the safe daily capacity calculation for workload insights.
 */

export const TIME_REGEX = /^([0-1][0-9]|2[0-3]):[0-5][0-9]$/;

export interface ConstraintLike {
  sleepStart?: string | null;
  sleepEnd?: string | null;
  minSleepHours?: number | null;
  bufferMinutes?: number | null;
}

/**
 * Parses a 24-hour time string in "HH:mm" format to minutes since midnight (0..1439).
 * Returns null if the string is not a valid 24-hour time.
 */
export function parseTimeToMinutes(timeStr?: string | null): number | null {
  if (!timeStr || typeof timeStr !== 'string') return null;
  const trimmed = timeStr.trim();
  if (!TIME_REGEX.test(trimmed)) return null;
  const [h, m] = trimmed.split(':').map(Number);
  return h! * 60 + m!;
}

/**
 * Calculates the actual daily sleep duration in minutes from sleepStart and sleepEnd.
 *
 * Overnight rules:
 * - When end <= start, the interval crosses midnight into the next day (adds 24 hours / 1440 minutes).
 *   Example: 23:00 to 07:00 -> 8 hours (480 minutes).
 *   Example: 22:00 to 07:00 -> 9 hours (540 minutes).
 * - Equal start and end times (e.g. 07:00 to 07:00) represent a degenerate 0h/24h interval and return null.
 * - Windows strictly exceeding 16 hours (960 minutes) exceed the product protocol ceiling and return null.
 * - Missing or malformed times return null.
 */
export function calculateSleepDurationMinutes(
  sleepStart?: string | null,
  sleepEnd?: string | null
): number | null {
  if (!sleepStart || !sleepEnd) return null;
  if (sleepStart === sleepEnd) return null;

  const startMin = parseTimeToMinutes(sleepStart);
  const endMin = parseTimeToMinutes(sleepEnd);
  if (startMin === null || endMin === null) return null;

  let durationMinutes = endMin - startMin;
  if (durationMinutes <= 0) {
    durationMinutes += 1440; // Overnight window wrapping across midnight
  }

  // Windows exceeding 16 hours (960 min) are disallowed per constraintSchema
  if (durationMinutes > 16 * 60) {
    return null;
  }

  return durationMinutes;
}

/**
 * Resolves safe daily available minutes based on actual sleep duration (or fallback) and buffer.
 *
 * Fallback semantics (preserving existing API contract):
 * - If actual sleep duration is available from sleepStart and sleepEnd, use that duration.
 * - If constraints is missing, fall back to 420 minutes (7.0 hours default).
 * - If sleepStart/sleepEnd are equal, missing, or malformed, fall back to minSleepHours * 60 (or 420).
 * - Buffer defaults to 30 minutes if not specified.
 * - Safe daily capacity = max(0, 1440 - sleepMinutes - bufferMinutes).
 */
export function computeSafeDailyMinutes(constraints?: ConstraintLike | null): number {
  const actualSleepMinutes = constraints
    ? calculateSleepDurationMinutes(constraints.sleepStart, constraints.sleepEnd)
    : null;

  const sleepMinutes =
    actualSleepMinutes ??
    (constraints?.minSleepHours != null
      ? Math.round(constraints.minSleepHours * 60)
      : 420);

  const bufferMinutes = constraints?.bufferMinutes ?? 30;

  return Math.max(0, 1440 - sleepMinutes - bufferMinutes);
}
