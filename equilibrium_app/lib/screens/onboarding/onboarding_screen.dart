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

  // Sleep Shield state
  String _sleepStart = "23:00";
  String _sleepEnd = "06:00";

  void _nextPage() async {
    if (_currentPage == 1) {
      try {
        await context.read<ConstraintRepository>().updateConstraints({
          'sleepStart': _sleepStart,
          'sleepEnd': _sleepEnd,
          'minSleepHours': 7.0,
        });
        _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
      } catch (e) {
        // Ignored for UI flow robustness if offline.
        _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
      }
    } else if (_currentPage < 2) {
      _pageCtrl.nextPage(duration: EqTokens.durationNormal, curve: Curves.easeInOut);
    } else {
      // Finish onboarding
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
                  // Indicators
                  Row(
                    children: List.generate(3, (index) => Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index ? colors.primary : colors.surfaceElevated,
                      ),
                    )),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.surface,
                      elevation: 0,
                    ),
                    onPressed: _nextPage,
                    child: Text(_currentPage == 2 ? 'Let\'s Go' : 'Next'),
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
          Icon(Icons.balance, size: 64, color: colors.primary),
          const SizedBox(height: EqTokens.space24),
          Text(
            'Welcome to Equilibrium',
            style: text.headlineLarge?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'We don\'t just ask what you want to do. We mathematically balance your responsibilities against your real capacity.',
            style: text.bodyLarge?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
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
          Icon(Icons.shield_moon_outlined, size: 64, color: colors.sleepShield),
          const SizedBox(height: EqTokens.space24),
          Text(
            'Protect your sleep',
            style: text.headlineLarge?.copyWith(color: colors.sleepShield),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'Equilibrium will never schedule work inside this window.',
            style: text.bodyLarge?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeField('Sleep Start', _sleepStart, (v) => setState(() => _sleepStart = v)),
              Text('→', style: text.titleLarge),
              _buildTimeField('Wake Up', _sleepEnd, (v) => setState(() => _sleepEnd = v)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTimeField(String label, String value, ValueChanged<String> onChanged) {
    return Column(
      children: [
        Text(label, style: context.eqText.labelSmall?.copyWith(color: context.eqColors.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: context.eqColors.surface,
            borderRadius: EqTokens.border8,
          ),
          child: Text(value, style: context.eqText.titleLarge),
        )
      ],
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
          Icon(Icons.auto_awesome, size: 64, color: colors.primary),
          const SizedBox(height: EqTokens.space24),
          Text(
            'Your workload is ready',
            style: text.headlineLarge?.copyWith(color: colors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'We have configured your peak energy windows to Morning & Afternoon.\n\nAdd your first assignments on the next screen, and we will build your first balanced schedule.',
            style: text.bodyLarge?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
