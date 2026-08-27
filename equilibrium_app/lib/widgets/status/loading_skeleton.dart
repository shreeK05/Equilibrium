import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class EquilibriumLoadingState extends StatefulWidget {
  final List<String> steps;
  
  const EquilibriumLoadingState({
    super.key,
    this.steps = const [
      "Checking constraints...",
      "Optimizing your workload...",
      "Placing your tasks...",
      "Finalizing your schedule...",
    ],
  });

  @override
  State<EquilibriumLoadingState> createState() => _EquilibriumLoadingStateState();
}

class _EquilibriumLoadingStateState extends State<EquilibriumLoadingState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _cycleSteps();
  }
  
  Future<void> _cycleSteps() async {
    while (mounted) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) break;
      setState(() {
        _currentStep = (_currentStep + 1) % widget.steps.length;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * 3.1415927,
                child: Icon(Icons.sync, color: colors.primary, size: 48),
              );
            },
          ),
          const SizedBox(height: EqTokens.space24),
          Text(
            'Balancing your workload...',
            style: text.titleLarge?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: EqTokens.space8),
          AnimatedSwitcher(
            duration: EqTokens.durationNormal,
            child: Text(
              widget.steps[_currentStep],
              key: ValueKey<int>(_currentStep),
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
          )
        ],
      ),
    );
  }
}
