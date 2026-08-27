import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class TimelineGridBackground extends StatelessWidget {
  final double pixelsPerMinute;
  final int totalMinutes;

  const TimelineGridBackground({
    super.key,
    required this.pixelsPerMinute,
    this.totalMinutes = 1440, // 24 hours
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : 1000.0;
        return CustomPaint(
          size: Size(width, totalMinutes * pixelsPerMinute),
          painter: _TimelineGridPainter(
            pixelsPerMinute: pixelsPerMinute,
            totalMinutes: totalMinutes,
            lineColor: context.eqColors.surfaceElevated,
            textColor: context.eqColors.textSecondary,
            textStyle: context.eqText.labelSmall,
          ),
        );
      }
    );
  }

}

class _TimelineGridPainter extends CustomPainter {
  final double pixelsPerMinute;
  final int totalMinutes;
  final Color lineColor;
  final Color textColor;
  final TextStyle? textStyle;

  _TimelineGridPainter({
    required this.pixelsPerMinute,
    required this.totalMinutes,
    required this.lineColor,
    required this.textColor,
    this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1;
      
    final thickLinePaint = Paint()
      ..color = lineColor.withOpacity(0.8)
      ..strokeWidth = 1.5;

    const timeColumnWidth = 50.0;

    for (int min = 0; min <= totalMinutes; min += 30) {
      final y = min * pixelsPerMinute;
      
      final isHour = min % 60 == 0;
      final paint = isHour ? thickLinePaint : linePaint;

      // Draw grid line
      canvas.drawLine(
        Offset(timeColumnWidth, y),
        Offset(size.width, y),
        paint,
      );

      // Draw time label on the hour
      if (isHour) {
        final hour = min ~/ 60;
        final label = '${hour.toString().padLeft(2, '0')}:00';
        
        final textPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: textStyle?.copyWith(color: textColor),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: timeColumnWidth);
        
        // Vertically center text on the line
        textPainter.paint(
          canvas,
          Offset(timeColumnWidth - textPainter.width - 8, y - textPainter.height / 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineGridPainter oldDelegate) {
    return oldDelegate.pixelsPerMinute != pixelsPerMinute ||
           oldDelegate.totalMinutes != totalMinutes ||
           oldDelegate.lineColor != lineColor ||
           oldDelegate.textColor != textColor;
  }
}
