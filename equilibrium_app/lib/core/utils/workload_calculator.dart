import '../../models/commitment.dart';
import '../../models/schedule.dart';

/// Represents a continuous time interval [start, end].
class TimeInterval {
  final DateTime start;
  final DateTime end;

  TimeInterval(this.start, this.end) {
    assert(!end.isBefore(start), 'Interval end ($end) must not be before start ($start)');
  }

  int get durationMinutes => end.difference(start).inMinutes;

  /// Clamps interval to [rangeStart, rangeEnd]. Returns null if no intersection.
  TimeInterval? clamp(DateTime rangeStart, DateTime rangeEnd) {
    final s = start.isBefore(rangeStart) ? rangeStart : start;
    final e = end.isAfter(rangeEnd) ? rangeEnd : end;
    if (s.isBefore(e)) {
      return TimeInterval(s, e);
    }
    return null;
  }

  @override
  String toString() => 'TimeInterval(${start.toIso8601String()} -> ${end.toIso8601String()})';
}

/// Holds computed capacity and workload metrics for a local calendar day.
class DayWorkload {
  final int totalDayMinutes;
  final int unavailableMinutes;
  final int availableCapacityMinutes;
  final int plannedMinutes;
  final int remainingCapacityMinutes;
  final double loadRatio;

  const DayWorkload({
    required this.totalDayMinutes,
    required this.unavailableMinutes,
    required this.availableCapacityMinutes,
    required this.plannedMinutes,
    required this.remainingCapacityMinutes,
    required this.loadRatio,
  });

  int get loadPercentage => (loadRatio * 100).round();
  bool get isOverloaded => plannedMinutes > availableCapacityMinutes;
}

/// Mathematically defensible workload capacity calculator.
///
/// Implements union of unavailable intervals (sleep shield, fixed commitments + buffers)
/// across the user's local calendar day to avoid double counting and accurately measure
/// planned load versus available capacity.
class WorkloadCalculator {
  /// Exact backend-supported sleep duration range for students: 7.0h to 12.0h.
  static const double minSleepHours = 7.0;
  static const double maxSleepHours = 12.0;

  /// Checks if sleep duration is within the backend supported range [7.0, 12.0].
  static bool isValidSleepDuration(double sleepHours) {
    return sleepHours >= minSleepHours && sleepHours <= maxSleepHours;
  }

  /// Parses "HH:mm" to minutes since midnight.
  static int _parseTimeToMinutes(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return hour * 60 + minute;
  }

  /// Calculates sleep duration in hours, properly handling overnight windows.
  /// If start == end, returns 0.0.
  static double calculateSleepDurationHours(String sleepStart, String sleepEnd) {
    if (sleepStart == sleepEnd) return 0.0;
    final sm = _parseTimeToMinutes(sleepStart);
    final em = _parseTimeToMinutes(sleepEnd);
    double diff = (em - sm) / 60.0;
    if (diff <= 0) {
      diff += 24.0;
    }
    return diff;
  }

  /// Generates sleep intervals clamped to the specified local calendar day.
  /// Correctly handles overnight sleep (e.g. 23:00 to 07:00), same-day sleep,
  /// equal times (zero duration), and local day boundaries.
  static List<TimeInterval> calculateSleepIntervals(
    DateTime day,
    String sleepStart,
    String sleepEnd,
  ) {
    final dayStart = DateTime(day.year, day.month, day.day, 0, 0, 0);
    final dayEnd = DateTime(day.year, day.month, day.day + 1, 0, 0, 0);

    if (sleepStart == sleepEnd) return [];

    final sm = _parseTimeToMinutes(sleepStart);
    final em = _parseTimeToMinutes(sleepEnd);

    final startHour = sm ~/ 60;
    final startMin = sm % 60;
    final endHour = em ~/ 60;
    final endMin = em % 60;

    final intervals = <TimeInterval>[];

    if (sm > em) {
      // Overnight sleep crossing midnight (e.g., 23:00 to 07:00)
      // Portion 1: Morning sleep from dayStart (00:00) to sleepEnd
      final morningEnd = DateTime(day.year, day.month, day.day, endHour, endMin);
      if (morningEnd.isAfter(dayStart)) {
        final clamped = TimeInterval(dayStart, morningEnd).clamp(dayStart, dayEnd);
        if (clamped != null) intervals.add(clamped);
      }

      // Portion 2: Evening sleep from sleepStart to dayEnd (24:00)
      final eveningStart = DateTime(day.year, day.month, day.day, startHour, startMin);
      if (eveningStart.isBefore(dayEnd)) {
        final clamped = TimeInterval(eveningStart, dayEnd).clamp(dayStart, dayEnd);
        if (clamped != null) intervals.add(clamped);
      }
    } else {
      // Same-day sleep window (e.g., 01:00 to 09:00)
      final start = DateTime(day.year, day.month, day.day, startHour, startMin);
      final end = DateTime(day.year, day.month, day.day, endHour, endMin);
      final clamped = TimeInterval(start, end).clamp(dayStart, dayEnd);
      if (clamped != null) intervals.add(clamped);
    }

    return intervals;
  }

  /// Computes the union of overlapping or contiguous intervals.
  /// Prevents double-counting overlapping blocked time.
  static List<TimeInterval> mergeIntervals(List<TimeInterval> intervals) {
    if (intervals.isEmpty) return [];

    // Sort by start time ascending, then by end time ascending
    final sorted = List<TimeInterval>.from(intervals)
      ..sort((a, b) {
        final cmp = a.start.compareTo(b.start);
        return cmp != 0 ? cmp : a.end.compareTo(b.end);
      });

    final merged = <TimeInterval>[sorted.first];

    for (int i = 1; i < sorted.length; i++) {
      final curr = sorted[i];
      final last = merged.last;

      if (!curr.start.isAfter(last.end)) {
        // Overlapping or adjacent
        if (curr.end.isAfter(last.end)) {
          merged[merged.length - 1] = TimeInterval(last.start, curr.end);
        }
      } else {
        merged.add(curr);
      }
    }

    return merged;
  }

  /// Calculates the day's capacity and planned workload.
  static DayWorkload calculateCapacity({
    required DateTime date,
    required String sleepStart,
    required String sleepEnd,
    List<FixedCommitment>? commitments,
    int bufferMinutes = 0,
    List<ScheduleBlock>? blocks,
  }) {
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day + 1, 0, 0, 0);
    final totalDayMinutes = dayEnd.difference(dayStart).inMinutes;

    final blocked = <TimeInterval>[];

    // 1. Sleep intervals
    blocked.addAll(calculateSleepIntervals(date, sleepStart, sleepEnd));

    // 2. Fixed commitments + buffers
    if (commitments != null) {
      for (final c in commitments) {
        if (!c.isActive) continue;

        final bufferedStart = c.startTime.subtract(Duration(minutes: bufferMinutes));
        final bufferedEnd = c.endTime.add(Duration(minutes: bufferMinutes));

        final clamped = TimeInterval(bufferedStart, bufferedEnd).clamp(dayStart, dayEnd);
        if (clamped != null) {
          blocked.add(clamped);
        }
      }
    }

    // 3. Union of all unavailable intervals
    final mergedUnavailable = mergeIntervals(blocked);
    final unavailableMinutes = mergedUnavailable.fold<int>(
      0,
      (sum, i) => sum + i.durationMinutes,
    );

    final availableCapacityMinutes = (totalDayMinutes - unavailableMinutes).clamp(0, totalDayMinutes);

    // 4. Planned minutes for TASK blocks overlapping today
    int plannedMinutes = 0;
    if (blocks != null) {
      for (final b in blocks) {
        if (b.type != 'TASK') continue;

        // Clip block to [dayStart, dayEnd]
        final s = b.startTime.isBefore(dayStart) ? dayStart : b.startTime;
        final e = b.endTime.isAfter(dayEnd) ? dayEnd : b.endTime;
        if (s.isBefore(e)) {
          plannedMinutes += e.difference(s).inMinutes;
        }
      }
    }

    final remainingCapacityMinutes = availableCapacityMinutes - plannedMinutes;
    final loadRatio = availableCapacityMinutes > 0
        ? (plannedMinutes / availableCapacityMinutes)
        : (plannedMinutes > 0 ? 1.0 : 0.0);

    return DayWorkload(
      totalDayMinutes: totalDayMinutes,
      unavailableMinutes: unavailableMinutes,
      availableCapacityMinutes: availableCapacityMinutes,
      plannedMinutes: plannedMinutes,
      remainingCapacityMinutes: remainingCapacityMinutes,
      loadRatio: loadRatio,
    );
  }
}
