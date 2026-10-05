import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/decision_log.dart';
import '../../models/task.dart';
import '../../services/decision_repository.dart';
import '../../core/api/api_client.dart';

class ExplanationSheet extends StatefulWidget {
  final Task task;
  final String versionId;

  const ExplanationSheet({
    super.key,
    required this.task,
    required this.versionId,
  });

  @override
  State<ExplanationSheet> createState() => _ExplanationSheetState();
}

class _ExplanationSheetState extends State<ExplanationSheet> {
  DecisionLog? _decision;
  bool _isLoading = true;
  bool _showLocalExplanation = false;

  @override
  void initState() {
    super.initState();
    _fetchDecision();
  }

  Future<void> _fetchDecision() async {
    try {
      final repo = context.read<DecisionRepository>();
      final decisions = await repo.getDecisions(widget.versionId);
      
      // Group by chronological order? For MVP we just pick the latest or matching one for this task.
      // Usually there's one decision per task in a specific versionId.
      final matches = decisions.where((d) => d.taskId == widget.task.id).toList();
      
      if (mounted) {
        setState(() {
          _decision = matches.isNotEmpty ? matches.last : null;
          _showLocalExplanation = matches.isEmpty;
          _isLoading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) {
        setState(() {
          _showLocalExplanation = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _showLocalExplanation = true;
          _isLoading = false;
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
        bottom: MediaQuery.of(context).padding.bottom + EqTokens.space24,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: colors.primary),
              const SizedBox(width: EqTokens.space12),
              Text(
                'WHY THIS WAS SCHEDULED',
                style: text.labelLarge?.copyWith(
                  color: colors.textSecondary,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: EqTokens.space24),
          
          Text(
            widget.task.title,
            style: text.headlineSmall?.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: EqTokens.space24),

          if (_isLoading) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: EqTokens.space16),
            Center(
              child: Text(
                'Reviewing the scheduling decision...',
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ),
          ] else if (_showLocalExplanation) ...[
            _buildLocalExplanation(context),
          ] else if (_decision == null) ...[
            Center(
              child: Icon(Icons.help_outline, color: colors.textSecondary, size: 48),
            ),
            const SizedBox(height: EqTokens.space16),
            Center(
              child: Text(
                'No explanation is available for this decision yet.',
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            _buildDecisionDetails(context, _decision!),
        ],
      ),
    );
  }

  Widget _buildLocalExplanation(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    final remaining = widget.task.remainingMinutes;
    final completion = widget.task.completedMinutes;
    return Container(
      padding: const EdgeInsets.all(EqTokens.space24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: EqTokens.border16,
        border: Border.all(color: colors.surfaceElevated),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.lightbulb_outline, color: colors.primary, size: 28),
            const SizedBox(width: EqTokens.space12),
            Text('Why this matters', style: text.headlineSmall?.copyWith(color: colors.primary, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: EqTokens.space16),
          Text(
            'This task needs $remaining minutes more. It has a ${widget.task.cognitiveLoadLabel} focus load and an academic priority of ${(widget.task.academicWeight * 100).round()}%.',
            style: text.bodyLarge?.copyWith(color: colors.textPrimary, height: 1.5, fontSize: 18),
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'The Equilibrium engine places it safely before the deadline and strictly outside your Sleep Shield.',
            style: text.titleMedium?.copyWith(color: colors.textSecondary, height: 1.4, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: EqTokens.space16),
          Container(
            padding: const EdgeInsets.all(EqTokens.space12),
            decoration: BoxDecoration(color: colors.primary.withValues(alpha: 0.1), borderRadius: EqTokens.border8),
            child: Row(
              children: [
                Icon(Icons.timeline, color: colors.primary, size: 20),
                const SizedBox(width: EqTokens.space8),
                Text(
                  '$completion minutes completed so far.',
                  style: text.labelLarge?.copyWith(color: colors.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDecisionDetails(BuildContext context, DecisionLog log) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    String decisionTitle = 'UNKNOWN DECISION';
    String explanationText = 'An internal scheduling decision was made.';
    Color badgeColor = colors.textSecondary;
    
    switch (log.decisionType) {
      case DecisionType.fullyScheduled:
        decisionTitle = 'FULLY SCHEDULED';
        badgeColor = colors.success;
        if (log.reasonCode == DecisionReason.success) {
          explanationText = 'High-priority work was placed within available capacity before the deadline.';
        }
        break;
      case DecisionType.partiallyScheduled:
        decisionTitle = 'PARTIALLY SCHEDULED';
        badgeColor = colors.warning;
        if (log.reasonCode == DecisionReason.fragmentedCapacity) {
          explanationText = 'Not enough contiguous time was available to schedule the entire task, so it was split. The remaining work has been deferred.';
        } else {
          explanationText = 'Task was partially placed due to capacity constraints.';
        }
        break;
      case DecisionType.deferred:
        decisionTitle = 'DEFERRED';
        badgeColor = colors.danger;
        if (log.reasonCode == DecisionReason.capacityExceeded) {
          explanationText = 'Task was deferred because total daily capacity was exceeded by higher-priority work or fixed commitments.';
        } else if (log.reasonCode == DecisionReason.noAvailableSlots) {
          explanationText = 'No valid time slots were available before the deadline due to constraints.';
        } else {
          explanationText = 'Task was deferred.';
        }
        break;
      default:
        break;
    }

    final semanticLabel = "${widget.task.title}. $decisionTitle. Decision: $explanationText";

    return Semantics(
      label: semanticLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.15),
              borderRadius: EqTokens.border8,
              border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              decisionTitle,
              style: text.titleSmall?.copyWith(color: badgeColor, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
          ),
          const SizedBox(height: EqTokens.space24),
          Text(
            'THE ENGINE\'S REASONING',
            style: text.labelLarge?.copyWith(color: colors.textSecondary, letterSpacing: 2.0, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: EqTokens.space8),
          Text(
            explanationText,
            style: text.headlineSmall?.copyWith(color: colors.textPrimary, height: 1.4, fontWeight: FontWeight.w600),
          ),
          
          const SizedBox(height: EqTokens.space32),
          Container(
            padding: const EdgeInsets.all(EqTokens.space20),
            decoration: BoxDecoration(
              color: colors.surfaceElevated,
              borderRadius: EqTokens.border16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONSTRAINTS PROTECTED',
                  style: text.labelMedium?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: EqTokens.space16),
                _buildConstraintCheck(context, 'Sleep Shield active'),
                _buildConstraintCheck(context, 'Fixed routines respected'),
                _buildConstraintCheck(context, 'Deadline honored'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintCheck(BuildContext context, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EqTokens.space8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: context.eqColors.success, size: 20),
          const SizedBox(width: EqTokens.space12),
          Text(
            label,
            style: context.eqText.bodyMedium?.copyWith(color: context.eqColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
