import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/commitment.dart';

class RoutineBuilderSheet extends StatefulWidget {
  final FixedCommitment? routine;

  const RoutineBuilderSheet({super.key, this.routine});

  @override
  State<RoutineBuilderSheet> createState() => _RoutineBuilderSheetState();
}

class _RoutineBuilderSheetState extends State<RoutineBuilderSheet> {
  final _titleCtrl = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  String _flexibility = 'FIXED';
  String _color = '#10B981';
  bool _isSaving = false;
  String? _errorText;

  // Day of week selection (0=Sun, 1=Mon, ..., 6=Sat)
  final Set<int> _selectedDays = {};

  final List<String> _dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  void initState() {
    super.initState();
    if (widget.routine != null) {
      _titleCtrl.text = widget.routine!.title;
      _startTime = TimeOfDay.fromDateTime(widget.routine!.startTime);
      _endTime = TimeOfDay.fromDateTime(widget.routine!.endTime);
      _flexibility = widget.routine!.flexibility;
      _color = widget.routine!.color ?? _color;
      if (widget.routine!.daysOfWeek != null) {
        try {
          final List<dynamic> days = jsonDecode(widget.routine!.daysOfWeek!);
          _selectedDays.addAll(days.cast<int>());
        } catch (_) {}
      }
    } else {
      // Default to weekdays
      _selectedDays.addAll([1, 2, 3, 4, 5]);
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorText = 'Please enter a routine title');
      return;
    }
    if (_selectedDays.isEmpty) {
      setState(() => _errorText = 'Please select at least one day');
      return;
    }

    setState(() {
      _errorText = null;
      _isSaving = true;
    });

    try {
      final api = context.read<ApiClient>();
      
      final now = DateTime.now();
      // Calculate dummy start and end times that reflect the correct times (the date part is not critical for ROUTINE)
      final startDt = DateTime(now.year, now.month, now.day, _startTime.hour, _startTime.minute);
      var endDt = DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);
      if (endDt.isBefore(startDt)) {
        endDt = endDt.add(const Duration(days: 1));
      }

      final body = {
        'title': _titleCtrl.text.trim(),
        'startTime': startDt.toUtc().toIso8601String(),
        'endTime': endDt.toUtc().toIso8601String(),
        'type': 'ROUTINE',
        'recurrence': 'WEEKLY',
        'daysOfWeek': jsonEncode(_selectedDays.toList()),
        'flexibility': _flexibility,
        'color': _color,
      };

      if (widget.routine == null) {
        await api.post('/commitments', body: body);
      } else {
        await api.patch('/commitments/${widget.routine!.id}', body: body);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _errorText = 'Failed to save routine. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Container(
      padding: EdgeInsets.only(
        left: EqTokens.space24,
        right: EqTokens.space24,
        top: EqTokens.space24,
        bottom: MediaQuery.of(context).viewInsets.bottom + EqTokens.space24,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.routine == null ? 'Create Routine' : 'Edit Routine', style: text.headlineLarge?.copyWith(color: colors.textPrimary)),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: EqTokens.space24),
            
            TextField(
              controller: _titleCtrl,
              autofocus: widget.routine == null,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Routine Title',
                hintText: 'e.g. Morning Workout',
                errorText: _errorText,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: EqTokens.space24),

            Text('Days of the Week', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: EqTokens.space8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (index) {
                final isSelected = _selectedDays.contains(index);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedDays.remove(index);
                      } else {
                        _selectedDays.add(index);
                      }
                    });
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelected ? colors.primary : colors.surfaceElevated,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        _dayNames[index],
                        style: text.bodyMedium?.copyWith(
                          color: isSelected ? colors.surface : colors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: EqTokens.space24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Start Time', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      InkWell(
                        onTap: () => _pickTime(true),
                        borderRadius: EqTokens.border8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                          decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
                          child: Text(_startTime.format(context), style: text.bodyMedium?.copyWith(color: colors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: EqTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Time', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      InkWell(
                        onTap: () => _pickTime(false),
                        borderRadius: EqTokens.border8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                          decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
                          child: Text(_endTime.format(context), style: text.bodyMedium?.copyWith(color: colors.textPrimary)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space24),

            Text('Flexibility', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: EqTokens.space8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
              decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _flexibility,
                  isExpanded: true,
                  dropdownColor: colors.surfaceElevated,
                  style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'FIXED', child: Text('Fixed (Must happen)')),
                    DropdownMenuItem(value: 'FLEXIBLE', child: Text('Flexible (Can move)')),
                    DropdownMenuItem(value: 'SOFT', child: Text('Soft (Optional/Routine)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _flexibility = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: EqTokens.space32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: _isSaving 
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                    : Text('Save Routine', style: text.labelLarge?.copyWith(color: colors.surface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
