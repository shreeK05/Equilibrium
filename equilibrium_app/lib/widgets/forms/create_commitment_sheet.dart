import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

class CreateCommitmentSheet extends StatefulWidget {
  const CreateCommitmentSheet({super.key});

  @override
  State<CreateCommitmentSheet> createState() => _CreateCommitmentSheetState();
}

class _CreateCommitmentSheetState extends State<CreateCommitmentSheet> {
  final _titleCtrl = TextEditingController();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 2));
  String _type = 'CLASS';
  String? _errorText;

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorText = "Please enter an event title");
      return;
    }
    if (_endTime.isBefore(_startTime) || _endTime.isAtSameMomentAs(_startTime)) {
      setState(() => _errorText = "End time must be after start time");
      return;
    }
    setState(() => _errorText = null);

    final provider = context.read<ScheduleProvider>();
    final success = await provider.createCommitment({
      'title': _titleCtrl.text.trim(),
      'startTime': _startTime.toUtc().toIso8601String(),
      'endTime': _endTime.toUtc().toIso8601String(),
      'type': _type,
      'isActive': true,
    });

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      setState(() => _errorText = provider.errorMessage ?? "Failed to create commitment");
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    final initialDate = isStart ? _startTime : _endTime;
    
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.eqColors.primary,
            surface: context.eqColors.surfaceElevated,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(initialDate),
        builder: (context, child) => Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: context.eqColors.primary,
              surface: context.eqColors.surfaceElevated,
            ),
          ),
          child: child!,
        ),
      );

      if (time != null) {
        setState(() {
          final newDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
          if (isStart) {
            _startTime = newDateTime;
            if (_endTime.isBefore(_startTime)) {
              _endTime = _startTime.add(const Duration(hours: 1));
            }
          } else {
            _endTime = newDateTime;
          }
        });
      }
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
                Text('Add Fixed Commitment', style: text.headlineLarge?.copyWith(color: colors.textPrimary)),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: EqTokens.space24),
            
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Event Title (e.g. Bio Lab)',
                labelStyle: TextStyle(color: colors.textSecondary),
                filled: true,
                fillColor: colors.surface,
                errorText: _errorText,
                border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: EqTokens.border8,
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ).animate().fade().slideY(begin: 0.2, duration: 300.ms),
            
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
                        onTap: () => _pickDateTime(true),
                        borderRadius: EqTokens.border8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                          decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
                          child: Text(
                            DateFormat('MMM d, h:mm a').format(_startTime),
                            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 100.ms),
                ),
                const SizedBox(width: EqTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('End Time', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      InkWell(
                        onTap: () => _pickDateTime(false),
                        borderRadius: EqTokens.border8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                          decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
                          child: Text(
                            DateFormat('MMM d, h:mm a').format(_endTime),
                            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 150.ms),
                ),
              ],
            ),
            
            const SizedBox(height: EqTokens.space24),
            
            Text('Type', style: text.labelSmall?.copyWith(color: colors.textSecondary)).animate().fade(delay: 200.ms),
            const SizedBox(height: EqTokens.space8),
            Container(
              height: 48,
              decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _type,
                  isExpanded: true,
                  dropdownColor: colors.surfaceElevated,
                  icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                  padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                  style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                  items: const [
                    DropdownMenuItem(value: 'CLASS', child: Text('Class')),
                    DropdownMenuItem(value: 'LAB', child: Text('Lab')),
                    DropdownMenuItem(value: 'EXAM', child: Text('Exam')),
                    DropdownMenuItem(value: 'PERSONAL', child: Text('Personal')),
                    DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _type = val);
                  },
                ),
              ),
            ).animate().fade(delay: 250.ms),

            const SizedBox(height: EqTokens.space32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: context.watch<ScheduleProvider>().isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  elevation: 0,
                ),
                child: context.watch<ScheduleProvider>().isLoading 
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                    : Text('Add Commitment', style: text.labelLarge?.copyWith(color: colors.surface)),
              ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }
}
