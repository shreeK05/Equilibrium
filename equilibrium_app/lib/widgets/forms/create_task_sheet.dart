import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/exam_provider.dart';

class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  int _estimateMinutes = 60;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  final String _cognitiveLoad = 'MEDIUM';
  String _deadlineType = 'HARD';
  String? _subjectId;
  String? _errorText;
  Map<String, dynamic>? _preview;
  bool _isPreviewing = false;

  final List<int> _durationOptions = [30, 60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().fetchAll(); // Fetch subjects
    });
  }

  void _submit() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorText = "Please enter a task title");
      return;
    }
    setState(() => _errorText = null);

    final provider = context.read<ScheduleProvider>();
    final success = await provider.createTask({
      'title': _titleCtrl.text.trim(),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_categoryCtrl.text.trim().isNotEmpty) 'category': _categoryCtrl.text.trim(),
      if (_subjectId != null) 'subjectId': _subjectId,
      'estimateMinutes': _estimateMinutes,
      'deadline': _deadline.toUtc().toIso8601String(),
      'deadlineType': _deadlineType,
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
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_deadline),
      );

      if (time != null && mounted) {
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
            
            // Title
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              style: TextStyle(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'What do you need to do?',
                errorText: _errorText,
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ).animate().fade().slideY(begin: 0.2, duration: 300.ms),
            const SizedBox(height: EqTokens.space12),

            // Description
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
              ),
            ).animate().fade().slideY(begin: 0.2, duration: 300.ms),
            const SizedBox(height: EqTokens.space16),

            // Subject & Category row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Consumer<ExamProvider>(
                    builder: (context, provider, _) {
                      return DropdownButtonFormField<String>(
                        initialValue: _subjectId,
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          filled: true,
                          fillColor: colors.surface,
                          border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('General')),
                          ...provider.subjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                        ],
                        onChanged: (val) => setState(() => _subjectId = val),
                      );
                    },
                  ),
                ),
                const SizedBox(width: EqTokens.space12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _categoryCtrl,
                    style: TextStyle(color: colors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Category',
                      hintText: 'e.g. Assignment',
                      filled: true,
                      fillColor: colors.surface,
                      border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ).animate().fade().slideY(begin: 0.2, duration: 300.ms),
            const SizedBox(height: EqTokens.space24),
            
            Text('Estimated Effort', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
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
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                          decoration: BoxDecoration(
                            color: colors.surfaceElevated,
                            borderRadius: EqTokens.border8,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 16, color: colors.primary),
                              const SizedBox(width: EqTokens.space8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM d, h:mm a').format(_deadline),
                                  style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                      Text('Flexibility', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space8),
                      Container(
                        height: 48,
                        decoration: BoxDecoration(color: colors.surfaceElevated, borderRadius: EqTokens.border8),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _deadlineType,
                            isExpanded: true,
                            dropdownColor: colors.surfaceElevated,
                            padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16),
                            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'HARD', child: Text('Hard')),
                              DropdownMenuItem(value: 'FLEXIBLE', child: Text('Flexible')),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _deadlineType = val);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ).animate().fade(delay: 200.ms),

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
