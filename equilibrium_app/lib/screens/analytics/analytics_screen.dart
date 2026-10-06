import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/colors.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<Map<String, dynamic>>? _insightsFuture;

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  void _fetchInsights() {
    setState(() {
      _insightsFuture = context.read<ApiClient>().get('/insights').then((data) => data as Map<String, dynamic>);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    
    return Scaffold(
      backgroundColor: colors.background,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _insightsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: colors.primary));
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.exclamationmark_triangle, color: colors.warning, size: 48),
                  const SizedBox(height: 16),
                  Text('Failed to load insights', style: TextStyle(color: colors.textPrimary)),
                  TextButton(
                    onPressed: _fetchInsights,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final data = snapshot.data ?? {};
          final double focusScore = (data['focusScore'] as num?)?.toDouble() ?? 0.0;
          final double burnoutRisk = (data['burnoutRisk'] as num?)?.toDouble() ?? 0.0;
          final int tasksCompleted = (data['tasksCompleted'] as num?)?.toInt() ?? 0;
          final double deepWorkHours = (data['deepWorkHours'] as num?)?.toDouble() ?? 0.0;
          
          return RefreshIndicator(
            onRefresh: () async => _fetchInsights(),
            child: ListView(
              padding: const EdgeInsets.all(EqTokens.space24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _buildScoreHero(colors, focusScore),
                const SizedBox(height: EqTokens.space32),
                Text('Key Metrics', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: EqTokens.space16),
                Row(
                  children: [
                    Expanded(child: _buildMetricCard(colors, 'Burnout Risk', '${burnoutRisk.toStringAsFixed(1)}%', CupertinoIcons.flame, colors.warning)),
                    const SizedBox(width: EqTokens.space16),
                    Expanded(child: _buildMetricCard(colors, 'Deep Work', '${deepWorkHours.toStringAsFixed(1)}h', CupertinoIcons.moon_stars, colors.primary)),
                  ],
                ),
                const SizedBox(height: EqTokens.space16),
                _buildMetricCard(colors, 'Tasks Completed', '$tasksCompleted', CupertinoIcons.checkmark_seal, colors.success),
                const SizedBox(height: EqTokens.space32),
                _buildInsightRecommendation(colors, focusScore, burnoutRisk),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildScoreHero(EqColors colors, double focusScore) {
    Color ringColor = colors.primary;
    if (focusScore < 50) ringColor = colors.warning;
    if (focusScore >= 80) ringColor = colors.success;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: EqTokens.space32),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: EqTokens.border24,
      ),
      child: Column(
        children: [
          Text('Overall Focus Score', style: TextStyle(color: colors.textSecondary, fontSize: 16)),
          const SizedBox(height: EqTokens.space16),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: focusScore / 100,
                  strokeWidth: 12,
                  backgroundColor: colors.surfaceElevated.withValues(alpha: 0.5),
                  color: ringColor,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                focusScore.toStringAsFixed(0),
                style: TextStyle(color: colors.textPrimary, fontSize: 36, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            focusScore >= 80 ? 'Exceptional alignment!' : focusScore >= 50 ? 'Steady pace.' : 'Needs adjustment.',
            style: TextStyle(color: ringColor, fontWeight: FontWeight.w600),
          )
        ],
      ),
    );
  }

  Widget _buildMetricCard(EqColors colors, String title, String value, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: EqTokens.border16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: EqTokens.space12),
          Text(value, style: TextStyle(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(color: colors.textSecondary, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildInsightRecommendation(EqColors colors, double focusScore, double burnoutRisk) {
    String message = "Keep up the great work! Your schedule is highly optimized.";
    if (burnoutRisk > 70) {
      message = "Warning: Your burnout risk is critically high. Consider spacing out your hard tasks and utilizing the Sleep Shield.";
    } else if (focusScore < 50) {
      message = "Your focus score is low. Try moving high cognitive tasks into your peak energy windows.";
    }

    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1),
        borderRadius: EqTokens.border16,
        border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(CupertinoIcons.lightbulb, color: colors.primary),
          const SizedBox(width: EqTokens.space16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AI Insight', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(message, style: TextStyle(color: colors.textSecondary, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
