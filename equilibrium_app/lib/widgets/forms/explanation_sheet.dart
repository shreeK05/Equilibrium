import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/decision_log.dart';
import '../../models/task.dart';
import '../../services/decision_repository.dart';
import '../../core/api/api_error_mapper.dart';
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
  String? _error;

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
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiErrorMapper.getUserFacingMessage(e.code);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
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
          ] else if (_error != null) ...[
            Center(
              child: Icon(Icons.error_outline, color: colors.danger, size: 48),
            ),
            const SizedBox(height: EqTokens.space16),
            Center(
              child: Text(
                'Couldn\'t load the scheduling explanation.\n$_error',
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
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
            padding: const EdgeInsets.symmetric(horizontal: EqTokens.space12, vertical: EqTokens.space4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.1),
              borderRadius: EqTokens.border4,
            ),
            child: Text(
              decisionTitle,
              style: text.labelSmall?.copyWith(color: badgeColor, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: EqTokens.space16),
          Text(
            'Reason:',
            style: text.labelLarge?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: EqTokens.space4),
          Text(
            explanationText,
            style: text.bodyLarge?.copyWith(color: colors.textPrimary),
          ),
          
          const SizedBox(height: EqTokens.space32),
          Text(
            'CONSTRAINTS PROTECTED',
            style: text.labelMedium?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: EqTokens.space12),
          _buildConstraintCheck(context, 'Sleep protected'),
          _buildConstraintCheck(context, 'Fixed commitments respected'),
          _buildConstraintCheck(context, 'Deadline considered'),
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
