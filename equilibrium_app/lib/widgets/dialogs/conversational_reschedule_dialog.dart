import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/api/api_client.dart';

class ConversationalRescheduleSheet extends StatefulWidget {
  final String? targetTaskId;
  final String? initialPrompt;

  const ConversationalRescheduleSheet({
    super.key,
    this.targetTaskId,
    this.initialPrompt,
  });

  static Future<void> show(BuildContext context, {String? targetTaskId, String? initialPrompt}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConversationalRescheduleSheet(
        targetTaskId: targetTaskId,
        initialPrompt: initialPrompt,
      ),
    );
  }

  @override
  State<ConversationalRescheduleSheet> createState() => _ConversationalRescheduleSheetState();
}

typedef ConversationalRescheduleDialog = ConversationalRescheduleSheet;

class _ConversationalRescheduleSheetState extends State<ConversationalRescheduleSheet> {
  final _messageCtrl = TextEditingController();
  bool _isAnalyzing = false;
  bool _isApplying = false;
  String? _errorMessage;

  Map<String, dynamic>? _proposal;

  final List<String> _quickPrompts = [
    'I am unable to study tonight',
    'I couldn\'t finish this task today',
    'Move this assignment to the next available slot',
    'I have only 1 hour free today',
    'I have an extra college lecture tomorrow'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt != null && widget.initialPrompt!.isNotEmpty) {
      _messageCtrl.text = widget.initialPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyzeIntent(widget.initialPrompt!);
      });
    }
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _analyzeIntent(String message) async {
    if (message.trim().isEmpty) return;
    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _proposal = null;
    });

    try {
      final api = context.read<ApiClient>();
      final data = await api.post('/nlp/reschedule-intent', body: {
        'message': message.trim(),
        if (widget.targetTaskId != null) 'targetTaskId': widget.targetTaskId,
      }) as Map<String, dynamic>;

      setState(() => _proposal = data);
    } catch (e) {
      setState(() => _errorMessage = 'Failed to analyze request: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _applyProposal() async {
    if (_proposal == null) return;
    setState(() {
      _isApplying = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiClient>();
      await api.post('/nlp/apply-reschedule', body: {
        'intent': _proposal!['intent'] ?? 'GENERAL_RESCHEDULE',
        if (widget.targetTaskId != null) 'targetTaskId': widget.targetTaskId,
      });

      // Refresh schedule in state
      if (mounted) {
        final colors = context.eqColors;
        await context.read<ScheduleProvider>().fetchDashboardData();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Schedule rescheduled successfully!'),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to apply schedule: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isApplying = false);
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
            // Handle
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
                Icon(Icons.forum_outlined, color: colors.primary, size: 24),
                const SizedBox(width: EqTokens.space8),
                Text(
                  'Conversational Rescheduling',
                  style: text.headlineSmall?.copyWith(color: colors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space8),
            Text(
              'Tell Equilibrium how your plans changed. We will propose a realistic alternative without sacrificing sleep or meals.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: EqTokens.space16),

            // Message text field
            TextField(
              controller: _messageCtrl,
              maxLines: 2,
              style: text.bodyMedium?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. I am unable to study tonight, move to tomorrow',
                hintStyle: text.bodySmall?.copyWith(color: colors.textSecondary.withValues(alpha: 0.7)),
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(borderRadius: EqTokens.border12),
                contentPadding: const EdgeInsets.all(EqTokens.space16),
              ),
              onSubmitted: _analyzeIntent,
            ),
            const SizedBox(height: EqTokens.space12),

            // Quick suggestion chips
            if (_proposal == null) ...[
              Wrap(
                spacing: EqTokens.space8,
                runSpacing: EqTokens.space8,
                children: _quickPrompts.map((prompt) {
                  return ActionChip(
                    label: Text(
                      prompt,
                      style: text.labelSmall?.copyWith(color: colors.textPrimary),
                    ),
                    backgroundColor: colors.background,
                    side: BorderSide(color: colors.cardBorder),
                    onPressed: () {
                      _messageCtrl.text = prompt;
                      _analyzeIntent(prompt);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: EqTokens.space16),
            ],

            // Analyze button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : () => _analyzeIntent(_messageCtrl.text),
                icon: _isAnalyzing
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_fix_high),
                label: Text(_isAnalyzing ? 'Analyzing proposal...' : 'Analyze & Propose Solution'),
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

            // Proposal details
            if (_proposal != null) ...[
              const SizedBox(height: EqTokens.space24),
              const Divider(),
              const SizedBox(height: EqTokens.space12),
              Text(
                'Proposed Schedule Adjustments',
                style: text.titleMedium?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: EqTokens.space8),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(EqTokens.space16),
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: EqTokens.border12,
                  border: Border.all(color: colors.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _proposal!['summary'] as String? ?? '',
                      style: text.bodyMedium?.copyWith(color: colors.textPrimary),
                    ),
                    if ((_proposal!['consequences'] as List<dynamic>?)?.isNotEmpty ?? false) ...[
                      const SizedBox(height: EqTokens.space12),
                      for (final cons in _proposal!['consequences'] as List<dynamic>)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                cons.toString(),
                                style: text.bodySmall?.copyWith(color: Colors.orange.shade800),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: EqTokens.space20),

              // Confirm and Cancel buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _proposal = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                      ),
                      child: const Text('Edit Request'),
                    ),
                  ),
                  const SizedBox(width: EqTokens.space12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isApplying ? null : _applyProposal,
                      icon: _isApplying
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: Text(_isApplying ? 'Applying...' : 'Confirm & Replan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
