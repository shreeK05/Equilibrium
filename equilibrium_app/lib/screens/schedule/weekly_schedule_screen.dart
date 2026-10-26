import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../widgets/timeline/timeline.dart';
import '../../widgets/dialogs/conversational_reschedule_dialog.dart';
import '../../widgets/forms/conversational_task_sheet.dart';
import '../imports/timetable_import_screen.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('7-Day Workload Planner'),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_outlined),
            tooltip: 'Import Timetable',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TimetableImportScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Natural Language Add',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ConversationalTaskSheet(),
              );
            },
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, _) {
          final schedule = provider.currentSchedule;
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);

          // Build 7-day strip starting from today
          final weekDays = List.generate(7, (i) => today.add(Duration(days: i)));

          if (provider.isLoading && schedule == null) {
            return const Center(child: CircularProgressIndicator());
          }

          if (schedule == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_month_outlined, size: 48, color: colors.primary),
                  const SizedBox(height: 16),
                  Text('No schedule generated yet', style: text.headlineSmall?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.generateSchedule,
                    child: const Text('Generate Plan'),
                  ),
                ],
              ),
            );
          }

          // Calculate daily minutes for each day in week
          final Map<String, int> dayMinutes = {};
          for (final b in schedule.blocks) {
            final dayKey = DateFormat('yyyy-MM-dd').format(b.startTime);
            dayMinutes[dayKey] = (dayMinutes[dayKey] ?? 0) + b.durationMinutes;
          }

          return Column(
            children: [
              // 7-Day Horizontal Selector Strip
              Container(
                color: colors.surface,
                padding: const EdgeInsets.symmetric(vertical: EqTokens.space12),
                child: SizedBox(
                  height: 72,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                    itemCount: weekDays.length,
                    itemBuilder: (context, index) {
                      final day = weekDays[index];
                      final isSelected = day.year == _selectedDate.year &&
                          day.month == _selectedDate.month &&
                          day.day == _selectedDate.day;
                      final dayKey = DateFormat('yyyy-MM-dd').format(day);
                      final minutes = dayMinutes[dayKey] ?? 0;
                      final isOverloaded = minutes > 360; // > 6h

                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedDate = day);
                          provider.setSelectedDate(day);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 10),
                          width: 58,
                          decoration: BoxDecoration(
                            color: isSelected ? colors.primary : colors.background,
                            borderRadius: EqTokens.border12,
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : (isOverloaded ? Colors.orange.withValues(alpha: 0.6) : colors.cardBorder),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('E').format(day).toUpperCase(),
                                style: text.labelSmall?.copyWith(
                                  color: isSelected ? Colors.white : colors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${day.day}',
                                style: text.titleMedium?.copyWith(
                                  color: isSelected ? Colors.white : colors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.white
                                      : (isOverloaded
                                          ? Colors.orange
                                          : (minutes > 0 ? colors.primary : Colors.transparent)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Date Header & Reschedule Action
              Container(
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space20, vertical: EqTokens.space12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  border: Border(bottom: BorderSide(color: colors.cardBorder)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('EEEE, d MMMM').format(_selectedDate),
                          style: text.titleMedium?.copyWith(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${dayMinutes[DateFormat('yyyy-MM-dd').format(_selectedDate)] ?? 0}m total scheduled',
                          style: text.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const ConversationalRescheduleSheet(),
                        );
                      },
                      icon: const Icon(Icons.forum_outlined, size: 16),
                      label: const Text('Reschedule'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                      ),
                    ),
                  ],
                ),
              ),

              // Timeline
              Expanded(
                child: ScheduleTimeline(
                  schedule: schedule,
                  tasks: provider.activeTasks,
                  commitments: provider.commitments,
                  constraints: provider.constraints,
                  selectedDate: _selectedDate,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
