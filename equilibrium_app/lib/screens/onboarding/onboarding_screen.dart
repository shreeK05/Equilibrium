import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import 'package:provider/provider.dart';
import '../../core/state/auth_provider.dart';
import '../../services/constraint_repository.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  bool _isSaving = false;
  String? _errorMessage;

  // Sleep Shield state — stored as HH:mm strings
  String _sleepStart = '23:00';
  String _sleepEnd = '07:00';

  /// Parses "HH:mm" into a TimeOfDay
  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// Formats TimeOfDay to "HH:mm"
  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  /// Display label for a time string — shows 12h format for readability
  String _displayTime(String hhmm) {
    final parts = hhmm.split(':');
    int h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final suffix = h < 12 ? 'AM' : 'PM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickTime(String label, String currentValue, ValueChanged<String> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(currentValue),
      helpText: 'Set $label',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      onPicked(_formatTime(picked));
    }
  }

  bool _validateSleepTimes() {
    // Both times are valid HH:mm
    if (_sleepStart == _sleepEnd) {
      setState(() => _errorMessage = 'Sleep start and wake-up time cannot be the same.');
      return false;
    }
    // Calculate sleep duration (handles overnight)
    final startParts = _sleepStart.split(':');
    final endParts = _sleepEnd.split(':');
    final startMins = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMins = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    double sleepHours = (endMins - startMins) / 60.0;
    if (sleepHours <= 0) sleepHours += 24; // overnight
    if (sleepHours > 16) {
      setState(() => _errorMessage = 'Sleep window exceeds 16 hours. Please check your times.');
      return false;
    }
    if (sleepHours < 5) {
      setState(() => _errorMessage = 'Sleep window is less than 5 hours. Please check your times.');
      return false;
    }
    setState(() => _errorMessage = null);
    return true;
  }

  void _nextPage() async {
    if (_currentPage == 1) {
      // Validate sleep times before proceeding
      if (!_validateSleepTimes()) return;

      setState(() => _isSaving = true);
      try {
        await context.read<ConstraintRepository>().updateConstraints({
          'sleepStart': _sleepStart,
          'sleepEnd': _sleepEnd,
          'minSleepHours': 7.0,
          'bufferMinutes': 15,
          'peakEnergyWindowsJson': '[{"start":"09:00","end":"12:00"},{"start":"15:00","end":"17:00"}]',
        });
        if (mounted) {
          _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
        }
      } catch (e) {
        // Show error but still allow progression so UX isn't blocked offline
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Could not save sleep schedule. You can update it later from Profile.',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: context.eqColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
          _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
        }
      } finally {
        if (mounted) setState(() => _isSaving = false);
      }
    } else if (_currentPage < 2) {
      _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
    } else {
      context.read<AuthProvider>().completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                physics: const NeverScrollableScrollPhysics(), // Only advance via button
                children: [
                  _buildWelcome(context),
                  _buildSleepShield(context),
                  _buildFinalSetup(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(EqTokens.space24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(3, (index) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: _currentPage == index ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: EqTokens.border8,
                        color: _currentPage == index ? colors.primary : colors.surfaceElevated,
                      ),
                    )),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                    ),
                    onPressed: _isSaving ? null : _nextPage,
                    child: _isSaving
                        ? SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                        : Text(_currentPage == 2 ? "Let's Go" : 'Next'),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Padding(
      padding: const EdgeInsets.all(EqTokens.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.balance, size: 48, color: colors.primary),
          ),
          const SizedBox(height: EqTokens.space32),
          Text(
            'Welcome to Equilibrium',
            style: text.headlineLarge?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            "We don't just ask what you want to do.\nWe mathematically balance your responsibilities against your real capacity.",
            style: text.bodyLarge?.copyWith(color: colors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space32),
          Container(
            padding: const EdgeInsets.all(EqTokens.space16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: EqTokens.border16,
            ),
            child: Column(
              children: [
                _buildFeatureRow(context, Icons.shield_moon_outlined, 'Sleep is protected', 'Never scheduled over'),
                const SizedBox(height: 12),
                _buildFeatureRow(context, Icons.auto_graph, 'Priority-based', 'Deadlines drive the plan'),
                const SizedBox(height: 12),
                _buildFeatureRow(context, Icons.balance, 'Adaptive rescheduling', 'Changes are handled for you'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String title, String subtitle) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: colors.primary),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: text.bodySmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
            Text(subtitle, style: text.labelSmall?.copyWith(color: colors.textSecondary)),
          ],
        ),
      ],
    );
  }

  Widget _buildSleepShield(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Padding(
      padding: const EdgeInsets.all(EqTokens.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.sleepShield.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shield_moon_outlined, size: 48, color: colors.sleepShield),
          ),
          const SizedBox(height: EqTokens.space24),
          Text(
            'Protect Your Sleep',
            style: text.headlineLarge?.copyWith(color: colors.sleepShield),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space12),
          Text(
            'Equilibrium will never schedule study work inside your sleep window. Tap the times below to set yours.',
            style: text.bodyLarge?.copyWith(color: colors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space32),

          // Interactive sleep time pickers
          Row(
            children: [
              Expanded(child: _buildTimeButton(
                context,
                label: 'Sleep Time',
                value: _displayTime(_sleepStart),
                icon: Icons.bedtime_outlined,
                onTap: () => _pickTime('Sleep Time', _sleepStart,
                    (v) => setState(() { _sleepStart = v; _errorMessage = null; })),
              )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('→', style: TextStyle(fontSize: 24)),
              ),
              Expanded(child: _buildTimeButton(
                context,
                label: 'Wake Up',
                value: _displayTime(_sleepEnd),
                icon: Icons.wb_sunny_outlined,
                onTap: () => _pickTime('Wake Up', _sleepEnd,
                    (v) => setState(() { _sleepEnd = v; _errorMessage = null; })),
              )),
            ],
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: EqTokens.space16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.danger.withValues(alpha: 0.1),
                borderRadius: EqTokens.border8,
                border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: colors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: text.bodySmall?.copyWith(color: colors.danger)),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: EqTokens.space24),
          Container(
            padding: const EdgeInsets.all(EqTokens.space12),
            decoration: BoxDecoration(
              color: colors.sleepShield.withValues(alpha: 0.08),
              borderRadius: EqTokens.border12,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colors.sleepShield),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Overnight schedules (e.g. 11:30 PM → 7:00 AM) are fully supported.',
                    style: text.labelSmall?.copyWith(color: colors.sleepShield),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colors = context.eqColors;
    final text = context.eqText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: EqTokens.border12,
          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: colors.primary),
            const SizedBox(height: 6),
            Text(label, style: text.labelSmall?.copyWith(color: colors.textSecondary, fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: text.titleMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Tap to edit', style: text.labelSmall?.copyWith(color: colors.primary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSetup(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Padding(
      padding: const EdgeInsets.all(EqTokens.space32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome, size: 48, color: colors.success),
          ),
          const SizedBox(height: EqTokens.space24),
          Text(
            'You\'re all set!',
            style: text.headlineLarge?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'Your sleep schedule has been saved.\n\nAdd your assignments and exams on the next screen, then tap Generate Schedule to build your first balanced plan.',
            style: text.bodyLarge?.copyWith(color: colors.textSecondary, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space32),
          Container(
            padding: const EdgeInsets.all(EqTokens.space16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: EqTokens.border16,
            ),
            child: Row(
              children: [
                Icon(Icons.shield_moon_outlined, color: colors.sleepShield, size: 20),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sleep Shield Active', style: text.bodySmall?.copyWith(
                      color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    Text('${_displayTime(_sleepStart)} → ${_displayTime(_sleepEnd)}',
                      style: text.labelSmall?.copyWith(color: colors.sleepShield)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
