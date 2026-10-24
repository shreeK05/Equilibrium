import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/exam_provider.dart';

// Standard student duration presets
const _kDurationOptions = [15, 30, 45, 60, 90, 120];

String _durationLabel(int mins) {
  if (mins < 60) return '${mins}m';
  final h = mins ~/ 60;
  final m = mins % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _customDurationCtrl = TextEditingController();
  final _dailyTargetCtrl = TextEditingController();

  int _estimateMinutes = 60;
  bool _useCustomDuration = false;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  final String _cognitiveLoad = 'MEDIUM';
  String _deadlineType = 'HARD';
  String? _errorText;
  Map<String, dynamic>? _preview;
  bool _isPreviewing = false;
  bool _showAdditionalOptions = false;
  bool _showDailyTarget = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().fetchAll();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _customDurationCtrl.dispose();
    _dailyTargetCtrl.dispose();
    super.dispose();
  }

  int get _effectiveEstimateMinutes {
    if (_useCustomDuration) {
      final val = int.tryParse(_customDurationCtrl.text.trim());
      return (val != null && val > 0) ? val : _estimateMinutes;
    }
    return _estimateMinutes;
  }

  String? _validateForm() {
    if (_titleCtrl.text.trim().isEmpty) return 'Please enter a task title';
    if (_useCustomDuration) {
      final val = int.tryParse(_customDurationCtrl.text.trim());
      if (val == null || val <= 0) return 'Custom duration must be a positive number';
      if (val > 10000) return 'Duration cannot exceed 10,000 minutes';
    }
    if (_deadline.isBefore(DateTime.now().subtract(const Duration(minutes: 1)))) {
      return 'Deadline cannot be in the past';
    }
    if (_showDailyTarget && _dailyTargetCtrl.text.trim().isNotEmpty) {
      final dv = int.tryParse(_dailyTargetCtrl.text.trim());
      if (dv == null || dv <= 0) return 'Daily target must be a positive number';
      if (dv > 720) return 'Daily target cannot exceed 720 minutes (12 hours)';
      final estimate = _effectiveEstimateMinutes;
      if (dv >= estimate) return 'Daily target should be less than total estimate';
    }
    return null;
  }

  void _submit() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    setState(() => _errorText = null);

    final effectiveMinutes = _effectiveEstimateMinutes;
    final Map<String, dynamic> payload = {
      'title': _titleCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_categoryCtrl.text.trim().isNotEmpty) 'category': _categoryCtrl.text.trim(),
      'estimateMinutes': effectiveMinutes,
      'deadline': _deadline.toUtc().toIso8601String(),
      'deadlineType': _deadlineType,
      'cognitiveLoad': _cognitiveLoad,
      'academicWeight': 0.5,
      'teamImpactWeight': 0.0,
    };

    if (_showDailyTarget && _dailyTargetCtrl.text.trim().isNotEmpty) {
      final dv = int.tryParse(_dailyTargetCtrl.text.trim());
      if (dv != null && dv > 0) payload['dailyTargetMinutes'] = dv;
    }

    final provider = context.read<ScheduleProvider>();
    final success = await provider.createTask(payload);

    if (success && mounted) {
      Navigator.pop(context);
    } else if (mounted) {
      setState(() => _errorText = provider.errorMessage ?? 'Failed to create task. Please try again.');
    }
  }

  Future<void> _previewImpact() async {
    final validationError = _validateForm();
    if (validationError != null) {
      setState(() => _errorText = validationError);
      return;
    }
    setState(() {
      _errorText = null;
      _isPreviewing = true;
    });
    final preview = await context.read<ScheduleProvider>().simulateTask({
      'title': _titleCtrl.text.trim(),
      'estimateMinutes': _effectiveEstimateMinutes,
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

  Future<void> _pickCustomDeadline() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final initial = _deadline.isBefore(startOfToday) ? startOfToday : _deadline;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: startOfToday,
      lastDate: startOfToday.add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline),
      );

      if (time != null && mounted) {
        final chosen = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        setState(() {
          _deadline = chosen;
          if (chosen.isBefore(DateTime.now())) {
            _errorText = 'Deadline is in the past. Please select an upcoming date and time.';
          } else {
            _errorText = null;
          }
        });
      }
    }
  }

  void _setPresetDeadline(int daysOffset) {
    final now = DateTime.now();
    final targetDay = now.add(Duration(days: daysOffset));
    setState(() {
      _deadline = DateTime(targetDay.year, targetDay.month, targetDay.day, 23, 59);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    final now = DateTime.now();
    final isTodayPreset = _deadline.day == now.day && _deadline.month == now.month && _deadline.year == now.year;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrowPreset = _deadline.day == tomorrow.day && _deadline.month == tomorrow.month && _deadline.year == tomorrow.year;
    final in3Days = now.add(const Duration(days: 3));
    final isIn3DaysPreset = _deadline.day == in3Days.day && _deadline.month == in3Days.month && _deadline.year == in3Days.year;

    return Container(
      padding: EdgeInsets.only(
        left: EqTokens.space24,
        right: EqTokens.space24,
        top: EqTokens.space20,
        bottom: MediaQuery.of(context).viewInsets.bottom + EqTokens.space24,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: EqTokens.border4,
                ),
              ),
            ),
            const SizedBox(height: EqTokens.space16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Responsibility',
                        style: text.titleLarge?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Quickly capture a task with smart scheduling defaults',
                        style: text.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(CupertinoIcons.xmark_circle_fill, color: colors.textTertiary),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: EqTokens.space20),

            // 1. Task Title (Primary input)
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                labelText: 'What do you need to do?',
                hintText: 'e.g. Algorithms Problem Set 3',
                errorText: _errorText,
                prefixIcon: Icon(CupertinoIcons.check_mark_circled, color: colors.primary, size: 20),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: EqTokens.space20),

            // 2. Estimated Effort (Fast preset chips)
            Text(
              'ESTIMATED EFFORT',
              style: text.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EqTokens.space8),
            Wrap(
              spacing: EqTokens.space8,
              runSpacing: EqTokens.space8,
              children: [
                ..._kDurationOptions.map((mins) {
                  final isSelected = !_useCustomDuration && _estimateMinutes == mins;
                  return ChoiceChip(
                    label: Text(_durationLabel(mins)),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _estimateMinutes = mins;
                          _useCustomDuration = false;
                          _customDurationCtrl.clear();
                        });
                      }
                    },
                    selectedColor: colors.primary,
                    backgroundColor: colors.surfaceElevated,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : colors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  );
                }),
                ChoiceChip(
                  label: const Text('Custom'),
                  selected: _useCustomDuration,
                  onSelected: (val) {
                    setState(() {
                      _useCustomDuration = val;
                      if (!val) _customDurationCtrl.clear();
                    });
                  },
                  selectedColor: colors.primary,
                  backgroundColor: colors.surfaceElevated,
                  labelStyle: TextStyle(
                    color: _useCustomDuration ? Colors.white : colors.textPrimary,
                    fontWeight: _useCustomDuration ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ],
            ),

            if (_useCustomDuration) ...[
              const SizedBox(height: EqTokens.space12),
              TextField(
                controller: _customDurationCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Custom duration (minutes)',
                  hintText: 'e.g. 180',
                  suffixText: 'min',
                  prefixIcon: Icon(CupertinoIcons.time, color: colors.primary, size: 20),
                ),
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                  setState(() {});
                },
              ),
            ],

            const SizedBox(height: EqTokens.space20),

            // 3. Deadline (Quick presets)
            Text(
              'DEADLINE',
              style: text.labelSmall?.copyWith(
                color: colors.textSecondary,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: EqTokens.space8),
            Wrap(
              spacing: EqTokens.space8,
              runSpacing: EqTokens.space8,
              children: [
                ActionChip(
                  label: const Text('Today 11:59 PM'),
                  onPressed: () => _setPresetDeadline(0),
                  backgroundColor: isTodayPreset ? colors.primary.withValues(alpha: 0.15) : colors.surfaceElevated,
                  side: BorderSide(color: isTodayPreset ? colors.primary : colors.cardBorder),
                  labelStyle: TextStyle(
                    color: isTodayPreset ? colors.primary : colors.textPrimary,
                    fontWeight: isTodayPreset ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ActionChip(
                  label: const Text('Tomorrow'),
                  onPressed: () => _setPresetDeadline(1),
                  backgroundColor: isTomorrowPreset ? colors.primary.withValues(alpha: 0.15) : colors.surfaceElevated,
                  side: BorderSide(color: isTomorrowPreset ? colors.primary : colors.cardBorder),
                  labelStyle: TextStyle(
                    color: isTomorrowPreset ? colors.primary : colors.textPrimary,
                    fontWeight: isTomorrowPreset ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
                ActionChip(
                  label: const Text('In 3 Days'),
                  onPressed: () => _setPresetDeadline(3),
                  backgroundColor: isIn3DaysPreset ? colors.primary.withValues(alpha: 0.15) : colors.surfaceElevated,
                  side: BorderSide(color: isIn3DaysPreset ? colors.primary : colors.cardBorder),
                  labelStyle: TextStyle(
                    color: isIn3DaysPreset ? colors.primary : colors.textPrimary,
                    fontWeight: isIn3DaysPreset ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space8),
            InkWell(
              onTap: _pickCustomDeadline,
              borderRadius: EqTokens.border12,
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: EqTokens.border12,
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(CupertinoIcons.calendar, size: 18, color: colors.primary),
                    const SizedBox(width: EqTokens.space12),
                    Expanded(
                      child: Text(
                        DateFormat('EEE, MMM d, yyyy • h:mm a').format(_deadline),
                        style: text.bodyMedium?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      'Change',
                      style: text.labelSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: EqTokens.space16),

            // 4. Collapsible Additional Options
            InkWell(
              onTap: () => setState(() => _showAdditionalOptions = !_showAdditionalOptions),
              borderRadius: EqTokens.border12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: EqTokens.border12,
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(
                      _showAdditionalOptions ? CupertinoIcons.slider_horizontal_below_rectangle : CupertinoIcons.slider_horizontal_3,
                      size: 18,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Additional options (Category, Notes, Pacing)',
                        style: text.bodySmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Icon(
                      _showAdditionalOptions ? CupertinoIcons.chevron_up : CupertinoIcons.chevron_down,
                      size: 16,
                      color: colors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),

            if (_showAdditionalOptions) ...[
              const SizedBox(height: EqTokens.space16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: _categoryCtrl.text.isEmpty ? null : _categoryCtrl.text,
                decoration: const InputDecoration(
                  labelText: 'Category (optional)',
                  prefixIcon: Icon(CupertinoIcons.tag, size: 18),
                ),
                items: const [
                  DropdownMenuItem(value: 'Assignment', child: Text('Assignment')),
                  DropdownMenuItem(value: 'Project', child: Text('Project')),
                  DropdownMenuItem(value: 'Lab Record', child: Text('Lab Record')),
                  DropdownMenuItem(value: 'Internal Prep', child: Text('Internal Prep')),
                  DropdownMenuItem(value: 'End Sem Prep', child: Text('End Sem Prep')),
                  DropdownMenuItem(value: 'Viva Prep', child: Text('Viva Prep')),
                  DropdownMenuItem(value: 'Tutorial', child: Text('Tutorial')),
                  DropdownMenuItem(value: 'Placement Prep', child: Text('Placement Prep')),
                  DropdownMenuItem(value: 'Other', child: Text('Other')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _categoryCtrl.text = val);
                },
              ),
              const SizedBox(height: EqTokens.space12),

              // Description
              TextField(
                controller: _descCtrl,
                maxLines: 2,
                style: TextStyle(color: colors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  labelText: 'Notes or instructions (optional)',
                  prefixIcon: Icon(CupertinoIcons.text_alignleft, size: 18),
                ),
              ),
              const SizedBox(height: EqTokens.space12),

              // Flexibility
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _deadlineType,
                      decoration: const InputDecoration(
                        labelText: 'Deadline Flexibility',
                        prefixIcon: Icon(CupertinoIcons.alarm, size: 18),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'HARD', child: Text('Hard Deadline')),
                        DropdownMenuItem(value: 'FLEXIBLE', child: Text('Flexible Deadline')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _deadlineType = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space12),

              // Daily Target Pacing
              InkWell(
                onTap: () => setState(() {
                  _showDailyTarget = !_showDailyTarget;
                  if (!_showDailyTarget) _dailyTargetCtrl.clear();
                }),
                child: Row(
                  children: [
                    Checkbox(
                      value: _showDailyTarget,
                      onChanged: (val) => setState(() {
                        _showDailyTarget = val ?? false;
                        if (!_showDailyTarget) _dailyTargetCtrl.clear();
                      }),
                      activeColor: colors.primary,
                    ),
                    Text(
                      'Pace across multiple days with a daily target',
                      style: text.bodySmall?.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
              ),
              if (_showDailyTarget) ...[
                const SizedBox(height: EqTokens.space8),
                TextField(
                  controller: _dailyTargetCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: colors.textPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Daily study target',
                    hintText: 'e.g. 60 (for 1 hour/day)',
                    suffixText: 'min/day',
                  ),
                ),
              ],
            ],

            const SizedBox(height: EqTokens.space24),

            // 5. Working What-If Preview
            if (_preview != null) ...[
              _buildPreview(context),
              const SizedBox(height: EqTokens.space12),
            ],

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isPreviewing ? null : _previewImpact,
                icon: _isPreviewing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(CupertinoIcons.sparkles, size: 16),
                label: const Text('Preview schedule fit before adding'),
              ),
            ),
            const SizedBox(height: EqTokens.space12),

            // 6. Primary Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: context.watch<ScheduleProvider>().isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                ),
                child: context.watch<ScheduleProvider>().isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        'Add to Workload',
                        style: text.labelLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
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
        border: Border.all(color: (fits ? colors.success : colors.warning).withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            fits ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.exclamationmark_triangle_fill,
            color: fits ? colors.success : colors.warning,
            size: 20,
          ),
          const SizedBox(width: EqTokens.space12),
          Expanded(
            child: Text(
              fits
                  ? 'This task fits cleanly. About $scheduled minutes can be scheduled before the deadline without encroaching on bedtime.'
                  : 'This task may cause workload pressure ($deferredTasks task(s) deferred). Protected sleep remains guarded.',
              style: text.bodySmall?.copyWith(color: colors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
