import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class CurrentTimeIndicator extends StatefulWidget {
  final double pixelsPerMinute;
  final DateTime referenceDate;

  const CurrentTimeIndicator({
    super.key,
    required this.pixelsPerMinute,
    required this.referenceDate,
  });

  @override
  State<CurrentTimeIndicator> createState() => _CurrentTimeIndicatorState();
}

class _CurrentTimeIndicatorState extends State<CurrentTimeIndicator> {
  late Timer _timer;
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only show if the current day matches the reference date (ignoring time)
    if (_now.year != widget.referenceDate.year ||
        _now.month != widget.referenceDate.month ||
        _now.day != widget.referenceDate.day) {
      return const SizedBox.shrink();
    }

    final minutesSinceMidnight = _now.hour * 60 + _now.minute;
    final topOffset = minutesSinceMidnight * widget.pixelsPerMinute;

    return Positioned(
      top: topOffset - 4, // Center the 8px dot on the line
      left: 46, // Aligned with the end of the time labels
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: context.eqColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              color: context.eqColors.primary.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
