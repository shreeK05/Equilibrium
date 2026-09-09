import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(EqTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ANALYTICS',
              style: text.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.2,
              ),
            ).animate().fade().slideY(begin: -0.2),
            const SizedBox(height: EqTokens.space8),
            Text(
              'Your Productivity',
              style: text.headlineLarge?.copyWith(
                color: colors.textPrimary,
              ),
            ).animate().fade(delay: 100.ms).slideY(begin: -0.2),
            const SizedBox(height: EqTokens.space32),
            
            _buildChartCard(context).animate().fade(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
            
            const SizedBox(height: EqTokens.space24),
            _buildStatGrid(context).animate().fade(delay: 300.ms).slideY(begin: 0.1),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Container(
      height: 250,
      padding: const EdgeInsets.all(EqTokens.space24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: EqTokens.border24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Workload Capacity', style: text.titleMedium?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: EqTokens.space24),
          Expanded(
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, _) {
                final schedule = provider.currentSchedule;
                final planned = (provider.insights?['remainingMinutes'] as num?)?.toInt() ?? 0;

                int capacity = 0;
                if (schedule != null) {
                  for (var b in schedule.blocks) {
                    if (b.type == 'FREE' || b.type == 'TASK') {
                      capacity += b.durationMinutes;
                    }
                  }
                }
                capacity = (provider.insights?['safeDailyMinutes'] as num?)?.toInt() ?? capacity;
                if (capacity == 0) capacity = planned;

                return BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: (capacity > planned ? capacity : planned).toDouble() + 60,
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final style = text.labelSmall?.copyWith(color: colors.textSecondary);
                            String title = value == 0 ? 'Planned' : 'Capacity';
                            return Padding(padding: const EdgeInsets.only(top: 8), child: Text(title, style: style));
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: [
                      BarChartGroupData(
                        x: 0,
                        barRods: [
                          BarChartRodData(
                            toY: planned.toDouble(),
                            color: colors.primary,
                            width: 32,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ],
                      ),
                      BarChartGroupData(
                        x: 1,
                        barRods: [
                          BarChartRodData(
                            toY: capacity.toDouble(),
                            color: colors.surfaceElevated,
                            width: 32,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  duration: const Duration(milliseconds: 500),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(BuildContext context) {
    return Consumer<ScheduleProvider>(
      builder: (context, provider, _) {
        final tasks = provider.activeTasks;
        final pending = tasks.where((t) => t.status != TaskStatus.completed && t.status != TaskStatus.archived).length;
        final completed = tasks.where((t) => t.status == TaskStatus.completed).length;
        final deferred = (provider.insights?['deferredCount'] as num?)?.toInt() ?? 0;
        
        return Row(
          children: [
            Expanded(child: _buildStatCard(context, 'Pending Tasks', pending.toString())),
            const SizedBox(width: EqTokens.space16),
            Expanded(child: _buildStatCard(context, 'Done', completed.toString())),
            const SizedBox(width: EqTokens.space16),
            Expanded(child: _buildStatCard(context, 'Debt', deferred.toString())),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return Container(
      padding: const EdgeInsets.all(EqTokens.space24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: EqTokens.border24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: text.labelSmall?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: EqTokens.space8),
          Text(value, style: text.headlineLarge?.copyWith(color: colors.primary)),
        ],
      ),
    );
  }
}
