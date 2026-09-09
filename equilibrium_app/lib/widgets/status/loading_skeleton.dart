import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class Skeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const Skeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = EqTokens.radius8,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: const Duration(milliseconds: 1500), color: colors.surface.withValues(alpha: 0.5));
  }
}

class EquilibriumLoadingState extends StatelessWidget {
  final bool showTasks;
  
  const EquilibriumLoadingState({
    super.key,
    this.showTasks = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(EqTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header skeleton
            const Skeleton(width: 120, height: 16),
            const SizedBox(height: EqTokens.space8),
            const Skeleton(width: 200, height: 32),
            const SizedBox(height: EqTokens.space32),
            
            // Progress ring skeleton
            Center(
              child: const Skeleton(width: 180, height: 180, borderRadius: 90),
            ),
            const SizedBox(height: EqTokens.space48),
            
            // Section title skeleton
            const Skeleton(width: 100, height: 20),
            const SizedBox(height: EqTokens.space16),
            
            // Cards skeleton
            if (showTasks) ...[
              const Skeleton(width: double.infinity, height: 100, borderRadius: EqTokens.radius24),
              const SizedBox(height: EqTokens.space16),
              const Skeleton(width: double.infinity, height: 100, borderRadius: EqTokens.radius24),
            ]
          ],
        ),
      ),
    );
  }
}
