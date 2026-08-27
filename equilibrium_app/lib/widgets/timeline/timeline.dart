import 'package:flutter/material.dart';
import '../../core/theme/tokens.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import 'timeline_grid.dart';
import 'timeline_block_absolute.dart';
import 'sleep_shield_absolute.dart';
import 'current_time_indicator.dart';
import '../../core/theme/theme.dart';

class ScheduleTimeline extends StatelessWidget {
  final ScheduleVersion schedule;
  final List<Task> tasks; // Passed down to enrich TASK blocks

  const ScheduleTimeline({
    super.key, 
    required this.schedule,
    required this.tasks,
  });

  @override
  Widget build(BuildContext context) {
    // 1 minute = 1.5 pixels (so 24 hours = 1440 mins = 2160 pixels)
    const double pixelsPerMinute = 1.5;
    const double totalHeight = 1440 * pixelsPerMinute;

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
  final double pixelsPerMinute;

  const _DayTimeline({
    required this.day,
    required this.blocks,
    required this.tasks,
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
              
              ...blocks.map((block) {
                // Calculate display metrics clamped to this specific day
                final dayStart = day;
                final dayEnd = day.add(const Duration(days: 1));
                
                DateTime effectiveStart = block.startTime.isBefore(dayStart) ? dayStart : block.startTime;
                DateTime effectiveEnd = block.endTime.isAfter(dayEnd) ? dayEnd : block.endTime;
                
                final int displayDuration = effectiveEnd.difference(effectiveStart).inMinutes;
                
                // If the block is strictly zero minutes on this day (e.g. exactly midnight), don't render it again
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
              }),

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
}
