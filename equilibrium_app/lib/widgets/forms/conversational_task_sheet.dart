import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/api/api_client.dart';

class ConversationalTaskSheet extends StatefulWidget {
  const ConversationalTaskSheet({super.key});

  @override
  State<ConversationalTaskSheet> createState() => _ConversationalTaskSheetState();
}

class _ConversationalTaskSheetState extends State<ConversationalTaskSheet> {
  final _inputCtrl = TextEditingController();
  final _titleCtrl = TextEditingController();

  bool _isInterpreting = false;
  bool _isSaving = false;
  String? _errorMessage;

  // Parsed state
  Map<String, dynamic>? _parsedData;
  int _estimateMinutes = 60;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _deadlineTime = const TimeOfDay(hour: 23, minute: 59);
  String _category = 'Assignment';
  String? _subjectName;
  String _cognitiveLoad = 'MEDIUM';
  double _academicWeight = 0.5;
  List<dynamic> _ambiguities = [];

  final List<String> _quickSuggestions = [
    'DBMS assignment tomorrow by 5 PM, 90 mins, high priority',
    'OS lab report on Friday for 2 hours, urgent',
    'Math revision tonight for 45 mins, medium priority',
    'Computer Networks quiz this weekend, 1 hour'
  ];

  @override
  void dispose() {
    _inputCtrl.dispose();
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _interpretText(String text) async {
    if (text.trim().isEmpty) return;
    setState(() {
      _isInterpreting = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiClient>();
      final data = await api.post('/nlp/parse-task', body: { 'text': text.trim() }) as Map<String, dynamic>;

      setState(() {
        _parsedData = data;
        _titleCtrl.text = data['title'] as String? ?? 'New Academic Task';
        _subjectName = data['subjectName'] as String?;
        _category = data['category'] as String? ?? 'Assignment';
        _estimateMinutes = (data['estimateMinutes'] as num?)?.toInt() ?? 60;
        _academicWeight = (data['academicWeight'] as num?)?.toDouble() ?? 0.5;
        _cognitiveLoad = data['cognitiveLoad'] as String? ?? 'MEDIUM';
        _ambiguities = (data['ambiguities'] as List<dynamic>?) ?? [];

        if (data['deadlineIso'] != null) {
          final dt = DateTime.parse(data['deadlineIso'] as String).toLocal();
          _deadline = dt;
          _deadlineTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Could not parse text. Please check your network or enter manually.';
      });
    } finally {
      if (mounted) setState(() => _isInterpreting = false);
    }
  }

  Future<void> _saveTask() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a task title.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final fullDeadline = DateTime(
        _deadline.year,
        _deadline.month,
        _deadline.day,
        _deadlineTime.hour,
        _deadlineTime.minute,
      );

      final provider = context.read<ScheduleProvider>();
      await provider.createTask({
        'title': _titleCtrl.text.trim(),
        'description': _subjectName != null ? 'Subject: $_subjectName' : null,
        'estimateMinutes': _estimateMinutes,
        'deadline': fullDeadline.toUtc().toIso8601String(),
        'category': _category,
        'academicWeight': _academicWeight,
        'cognitiveLoad': _cognitiveLoad,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Task '${_titleCtrl.text.trim()}' planned successfully!"),
            backgroundColor: context.eqColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to create task: ${e.toString()}';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(
        EqTokens.space24,
        EqTokens.space20,
        EqTokens.space24,
        EqTokens.space24 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: EqTokens.space16),
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Icon(Icons.auto_awesome, color: colors.primary, size: 24),
                const SizedBox(width: EqTokens.space8),
                Text(
                  'Natural Language Task Entry',
                  style: text.headlineSmall?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space8),
            Text(
              'Type or paste your task naturally. We extract the deadline, duration, and priority automatically.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: EqTokens.space16),

            // Input Field
            TextField(
              controller: _inputCtrl,
              maxLines: 2,
              style: text.bodyMedium?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Finish DBMS assignment tomorrow by 5 PM, 90 mins, high priority',
                hintStyle: text.bodySmall?.copyWith(color: colors.textSecondary.withValues(alpha: 0.7)),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: EqTokens.border12,
                  borderSide: BorderSide(color: colors.cardBorder),
                ),
                contentPadding: const EdgeInsets.all(EqTokens.space16),
              ),
              onSubmitted: _interpretText,
            ),
            const SizedBox(height: EqTokens.space12),

            // Suggestions Chips
            if (_parsedData == null) ...[
              Text(
                'Suggestions:',
                style: text.labelSmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space8),
              Wrap(
                spacing: EqTokens.space8,
                runSpacing: EqTokens.space8,
                children: _quickSuggestions.map((suggestion) {
                  return ActionChip(
                    label: Text(
                      suggestion,
                      style: text.labelSmall?.copyWith(color: colors.textPrimary),
                    ),
                    backgroundColor: colors.background,
                    side: BorderSide(color: colors.cardBorder),
                    onPressed: () {
                      _inputCtrl.text = suggestion;
                      _interpretText(suggestion);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: EqTokens.space16),
            ],

            // Parse Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isInterpreting ? null : () => _interpretText(_inputCtrl.text),
                icon: _isInterpreting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.psychology),
                label: Text(_isInterpreting ? 'Interpreting...' : 'Interpret & Preview'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                ),
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: EqTokens.space12),
              Text(
                _errorMessage!,
                style: text.bodySmall?.copyWith(color: colors.danger),
              ),
            ],

            // Editable Confirmation Card
            if (_parsedData != null) ...[
              const SizedBox(height: EqTokens.space24),
              const Divider(),
              const SizedBox(height: EqTokens.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Interpreted Task (Editable Preview)',
                    style: text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ready to Save',
                      style: text.labelSmall?.copyWith(color: colors.success),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space16),

              // Ambiguities warning banner
              if (_ambiguities.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(EqTokens.space12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: EqTokens.border12,
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.help_outline, color: Colors.amber, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Clarification needed:',
                            style: text.labelMedium?.copyWith(color: Colors.amber.shade800, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final a in _ambiguities)
                        Text('• ${a['question']}', style: text.bodySmall?.copyWith(color: colors.textPrimary)),
                    ],
                  ),
                ),
                const SizedBox(height: EqTokens.space16),
              ],

              // Title TextField
              TextField(
                controller: _titleCtrl,
                style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  filled: true,
                  fillColor: colors.background,
                  border: OutlineInputBorder(borderRadius: EqTokens.border12),
                ),
              ),
              const SizedBox(height: EqTokens.space12),

              // Duration & Category row
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _estimateMinutes,
                      decoration: InputDecoration(
                        labelText: 'Duration',
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(borderRadius: EqTokens.border12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30m')),
                        DropdownMenuItem(value: 45, child: Text('45m')),
                        DropdownMenuItem(value: 60, child: Text('1h (60m)')),
                        DropdownMenuItem(value: 90, child: Text('1.5h (90m)')),
                        DropdownMenuItem(value: 120, child: Text('2h (120m)')),
                        DropdownMenuItem(value: 180, child: Text('3h (180m)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _estimateMinutes = val);
                      },
                    ),
                  ),
                  const SizedBox(width: EqTokens.space12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _category,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        filled: true,
                        fillColor: colors.background,
                        border: OutlineInputBorder(borderRadius: EqTokens.border12),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Assignment', child: Text('Assignment')),
                        DropdownMenuItem(value: 'Lab', child: Text('Lab')),
                        DropdownMenuItem(value: 'Revision', child: Text('Revision')),
                        DropdownMenuItem(value: 'Project', child: Text('Project')),
                        DropdownMenuItem(value: 'Practice', child: Text('Practice')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space12),

              // Deadline date & time picker
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(DateFormat('d MMM yyyy').format(_deadline)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _deadline,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
                        );
                        if (picked != null) setState(() => _deadline = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: EqTokens.space12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.schedule, size: 16),
                      label: Text(_deadlineTime.format(context)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: _deadlineTime,
                        );
                        if (picked != null) setState(() => _deadlineTime = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space20),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveTask,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle),
                  label: Text(_isSaving ? 'Scheduling...' : 'Save & Plan Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
