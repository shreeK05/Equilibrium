import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  int _estimateMinutes = 60;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  String _cognitiveLoad = 'MEDIUM';
  String? _errorText;
  Map<String, dynamic>? _preview;
  bool _isPreviewing = false;

  final List<int> _durationOptions = [30, 60, 90, 120, 180];

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorText = "Please enter a task title");
      return;
    }
    setState(() => _errorText = null);

    final provider = context.read<ScheduleProvider>();
    final success = await provider.createTask({
      'title': _titleCtrl.text.trim(),
      'estimateMinutes': _estimateMinutes,
      'deadline': _deadline.toUtc().toIso8601String(),
      'cognitiveLoad': _cognitiveLoad,
      'academicWeight': 0.5,
      'teamImpactWeight': 0.0,
    });

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      setState(() => _errorText = provider.errorMessage ?? "Failed to create task");
    }
  }

  Future<void> _previewImpact() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorText = 'Enter a task title to preview its impact.');
      return;
    }
    setState(() {
      _errorText = null;
      _isPreviewing = true;
    });
    final preview = await context.read<ScheduleProvider>().simulateTask({
      'title': _titleCtrl.text.trim(),
      'estimateMinutes': _estimateMinutes,
      'deadline': _deadline.toUtc().toIso8601String(),
      'cognitiveLoad': _cognitiveLoad,
      'academicWeight': 0.5,
      'teamImpactWeight': 0.0,
    });
    if (mounted) {
      setState(() {
        _preview = preview;
        _isPreviewing = false;
      });
    }
  }

  Future<void> _pickDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: context.eqColors.primary,
            onPrimary: context.eqColors.surface,
            surface: context.eqColors.surfaceElevated,
            onSurface: context.eqColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline),
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
          _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
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
                Text('Add Responsibility', style: text.headlineLarge?.copyWith(color: colors.textPrimary)),
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
                labelText: 'What do you need to do?',
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
            
            Text('Estimated Effort', style: text.labelSmall?.copyWith(color: colors.textSecondary))
                .animate().fade(delay: 100.ms),
            const SizedBox(height: EqTokens.space8),
            Wrap(
              spacing: EqTokens.space8,
              runSpacing: EqTokens.space8,
              children: _durationOptions.map((mins) {
                final isSelected = _estimateMinutes == mins;
                return ChoiceChip(
                  label: Text(mins % 60 == 0 ? '${mins ~/ 60}h' : '${mins ~/ 60}h ${mins % 60}m'),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _estimateMinutes = mins);
                  },
                  selectedColor: colors.primary,
                  backgroundColor: colors.surfaceElevated,
                  labelStyle: TextStyle(color: isSelected ? colors.surface : colors.textPrimary),
                );
              }).toList(),
            ).animate().fade(delay: 150.ms),
            
            const SizedBox(height: EqTokens.space24),
            
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Deadline', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      InkWell(
                        onTap: _pickDeadline,
                        borderRadius: EqTokens.border8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: EqTokens.border8,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: colors.primary),
                              const SizedBox(width: EqTokens.space8),
                              Text(
                                DateFormat('MMM d, h:mm a').format(_deadline),
                                style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 200.ms),
                ),
                const SizedBox(width: EqTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Cognitive Load', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      Container(
                        height: 48, // Match the height of the date picker
                        decoration: BoxDecoration(
                          color: colors.surfaceElevated,
                          borderRadius: EqTokens.border8,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _cognitiveLoad,
                            isExpanded: true,
                            dropdownColor: colors.surfaceElevated,
                            icon: Icon(Icons.arrow_drop_down, color: colors.textSecondary),
                            padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'LOW', child: Text('Low')),
                              DropdownMenuItem(value: 'MEDIUM', child: Text('Medium')),
                              DropdownMenuItem(value: 'HIGH', child: Text('High')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _cognitiveLoad = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 250.ms),
                ),
              ],
            ),

            const SizedBox(height: EqTokens.space32),
            if (_preview != null) _buildPreview(context),
            if (_preview != null) const SizedBox(height: EqTokens.space16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isPreviewing ? null : _previewImpact,
                icon: _isPreviewing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.visibility_outlined),
                label: const Text('Preview impact before adding'),
              ),
            ),
            const SizedBox(height: EqTokens.space12),
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
                    : Text('Add to Workload', style: text.labelLarge?.copyWith(color: colors.surface)),
              ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    final fits = _preview!['fits'] == true;
    final scheduled = (_preview!['scheduledMinutes'] as num?)?.toInt() ?? 0;
    final deferredTasks = (_preview!['deferredTaskCount'] as num?)?.toInt() ?? 0;
    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: (fits ? colors.success : colors.warning).withValues(alpha: 0.12),
        borderRadius: EqTokens.border12,
        border: Border.all(color: (fits ? colors.success : colors.warning).withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(fits ? Icons.check_circle_outline : Icons.warning_amber_outlined, color: fits ? colors.success : colors.warning),
          const SizedBox(width: EqTokens.space12),
          Expanded(
            child: Text(
              fits
                  ? 'This task fits safely. About $scheduled minutes can be placed before the deadline.'
                  : 'This task may be deferred or split. $deferredTasks task(s) would remain under pressure, and sleep stays protected.',
              style: text.bodyMedium?.copyWith(color: colors.textPrimary, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
