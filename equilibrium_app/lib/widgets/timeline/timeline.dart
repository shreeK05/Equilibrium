import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import 'timeline_grid.dart';
import 'timeline_block_absolute.dart';
import 'sleep_shield_absolute.dart';
import 'current_time_indicator.dart';
import '../../core/theme/theme.dart';

import '../../models/commitment.dart';

class ScheduleTimeline extends StatelessWidget {
  final ScheduleVersion schedule;
  final List<Task> tasks; // Passed down to enrich TASK blocks
  final List<FixedCommitment> commitments;
  final Map<String, dynamic>? constraints;

  const ScheduleTimeline({
    super.key, 
    required this.schedule,
    required this.tasks,
    required this.commitments,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    // Find all distinct days in the schedule horizon
    final Set<DateTime> daysSet = {};
    for (var b in schedule.blocks) {
      daysSet.add(DateTime(b.startTime.year, b.startTime.month, b.startTime.day));
      if (b.endTime.hour > 0 || b.endTime.minute > 0) {
        // If a block crosses midnight, ensure the next day is also registered
        daysSet.add(DateTime(b.endTime.year, b.endTime.month, b.endTime.day));
      }
    }
    
    // Default to at least today if empty
    if (daysSet.isEmpty) {
      final now = DateTime.now();
      daysSet.add(DateTime(now.year, now.month, now.day));
    }

    final sortedDays = daysSet.toList()..sort();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800), // Desktop responsiveness: don't stretch infinitely
        child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: EqTokens.space16),
          itemCount: sortedDays.length,
          itemBuilder: (context, index) {
            final day = sortedDays[index];
            
            // Find blocks that overlap with this day
            // A block overlaps if it starts on this day, OR if it starts before this day and ends after the start of this day
            final dayStart = day;
            final dayEnd = day.add(const Duration(days: 1));
            
            final dayBlocks = schedule.blocks.where((b) {
              return b.startTime.isBefore(dayEnd) && b.endTime.isAfter(dayStart);
            }).toList();

            return _DayTimeline(
              day: day,
              blocks: dayBlocks,
              tasks: tasks,
              commitments: commitments,
              constraints: constraints,
              pixelsPerMinute: 1.5,
            );
          },
        ),
      ),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  final DateTime day;
  final List<ScheduleBlock> blocks;
  final List<Task> tasks;
  final List<FixedCommitment> commitments;
  final Map<String, dynamic>? constraints;
  final double pixelsPerMinute;

  const _DayTimeline({
    required this.day,
    required this.blocks,
    required this.tasks,
    required this.commitments,
    required this.constraints,
    required this.pixelsPerMinute,
  });

  @override
  Widget build(BuildContext context) {
    const double totalHeight = 1440 * 1.5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
          child: Text(
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            style: context.eqText.titleMedium?.copyWith(
              color: context.eqColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          height: totalHeight,
          margin: const EdgeInsets.only(bottom: EqTokens.space24),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: TimelineGridBackground(
                  pixelsPerMinute: pixelsPerMinute,
                  totalMinutes: 1440,
                ),
              ),
              
              ..._buildBlocks(day, blocks, pixelsPerMinute),

              CurrentTimeIndicator(
                pixelsPerMinute: pixelsPerMinute,
                referenceDate: day,
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildBlocks(DateTime day, List<ScheduleBlock> originalBlocks, double pixelsPerMinute) {
    final List<ScheduleBlock> syntheticBlocks = [...originalBlocks];

    // Add Fixed Commitments
    final dayStart = day;
    final dayEnd = day.add(const Duration(days: 1));
    
    for (var c in commitments) {
      if (c.endTime.isAfter(dayStart) && c.startTime.isBefore(dayEnd)) {
        syntheticBlocks.add(ScheduleBlock(
          id: c.id,
          versionId: '',
          startTime: c.startTime,
          endTime: c.endTime,
          durationMinutes: c.endTime.difference(c.startTime).inMinutes,
          isLocked: true,
          type: 'FIXED',
        ));
      }
    }

    // Add Sleep Shield
    if (constraints != null) {
      final startStr = constraints!['sleepStart'] as String? ?? '23:00';
      final endStr = constraints!['sleepEnd'] as String? ?? '06:00';
      
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      
      var sleepStart = DateTime(day.year, day.month, day.day, int.parse(startParts[0]), int.parse(startParts[1]));
      var sleepEnd = DateTime(day.year, day.month, day.day, int.parse(endParts[0]), int.parse(endParts[1]));
      
      if (sleepEnd.isBefore(sleepStart) || sleepEnd.isAtSameMomentAs(sleepStart)) {
        sleepEnd = sleepEnd.add(const Duration(days: 1));
      }

      // Also check previous day's crossing sleep
      var prevSleepStart = sleepStart.subtract(const Duration(days: 1));
      var prevSleepEnd = sleepEnd.subtract(const Duration(days: 1));

      if (sleepEnd.isAfter(dayStart) && sleepStart.isBefore(dayEnd)) {
        syntheticBlocks.add(ScheduleBlock(
          id: 'sleep_1', versionId: '', startTime: sleepStart, endTime: sleepEnd,
          durationMinutes: sleepEnd.difference(sleepStart).inMinutes, isLocked: true, type: 'SLEEP'
        ));
      }
      if (prevSleepEnd.isAfter(dayStart) && prevSleepStart.isBefore(dayEnd)) {
        syntheticBlocks.add(ScheduleBlock(
          id: 'sleep_2', versionId: '', startTime: prevSleepStart, endTime: prevSleepEnd,
          durationMinutes: prevSleepEnd.difference(prevSleepStart).inMinutes, isLocked: true, type: 'SLEEP'
        ));
      }
    }

    return syntheticBlocks.map((block) {
      DateTime effectiveStart = block.startTime.isBefore(dayStart) ? dayStart : block.startTime;
      DateTime effectiveEnd = block.endTime.isAfter(dayEnd) ? dayEnd : block.endTime;
      
      final int displayDuration = effectiveEnd.difference(effectiveStart).inMinutes;
      if (displayDuration <= 0) return const SizedBox.shrink();

      if (block.type == 'SLEEP') {
        return AbsoluteSleepShield(
          block: block,
          displayStart: effectiveStart,
          displayDurationMinutes: displayDuration,
          pixelsPerMinute: pixelsPerMinute,
        );
      }
    
      Task? matchedTask;
      if (block.taskId != null) {
        try {
          matchedTask = tasks.firstWhere((t) => t.id == block.taskId);
        } catch (_) {}
      }

      return AbsoluteTimelineBlock(
        block: block,
        displayStart: effectiveStart,
        displayDurationMinutes: displayDuration,
        pixelsPerMinute: pixelsPerMinute,
        task: matchedTask,
      );
    }).toList();
  }
}
