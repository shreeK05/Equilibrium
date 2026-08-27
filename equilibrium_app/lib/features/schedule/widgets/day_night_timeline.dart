import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class DayNightTimelinePainter extends CustomPainter {
  final double sleepStartHour;   // e.g. 23.0 (11 PM)
  final double sleepEndHour;     // e.g. 6.0 (6 AM)

  DayNightTimelinePainter({required this.sleepStartHour, required this.sleepEndHour});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Paint the 24h gradient background: night fading to day
    final gradient = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.inkNavy,
        AppColors.duskIndigo,
        AppColors.duskIndigo,
        AppColors.inkNavy,
      ],
      stops: [0.0, 0.25, 0.75, 1.0],
    );
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..shader = gradient.createShader(rect));

    // 2. Paint the locked Sleep Shield band
    final hourHeight = size.height / 24;
    
    // Helper to draw the glowing band
    void drawGlowBand(double top, double bottom) {
      final bandRect = Rect.fromLTWH(0, top, size.width, bottom - top);
      final bandPaint = Paint()
        ..color = AppColors.restLavender.withOpacity(0.28)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12); // Soft glow
      canvas.drawRect(bandRect, bandPaint);
    }

    // Handle sleep crossing midnight
    if (sleepStartHour > sleepEndHour) {
      drawGlowBand(sleepStartHour * hourHeight, size.height); // Night portion
      drawGlowBand(0, sleepEndHour * hourHeight); // Morning portion
    } else {
      drawGlowBand(sleepStartHour * hourHeight, sleepEndHour * hourHeight);
    }
  }

  @override
  bool shouldRepaint(covariant DayNightTimelinePainter oldDelegate) =>
      oldDelegate.sleepStartHour != sleepStartHour ||
      oldDelegate.sleepEndHour != sleepEndHour;
}