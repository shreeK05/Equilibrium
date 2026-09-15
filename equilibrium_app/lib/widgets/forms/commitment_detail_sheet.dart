import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/state/schedule_provider.dart';
import '../../models/commitment.dart';
import 'create_commitment_sheet.dart';
import 'routine_builder_sheet.dart';

class CommitmentDetailSheet extends StatefulWidget {
  final FixedCommitment commitment;

  const CommitmentDetailSheet({super.key, required this.commitment});

  @override
  State<CommitmentDetailSheet> createState() => _CommitmentDetailSheetState();
}

class _CommitmentDetailSheetState extends State<CommitmentDetailSheet> {
  bool _isDeleting = false;

  void _editCommitment() {
    Navigator.pop(context); // Close detail view
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => widget.commitment.type == CommitmentType.routine
          ? RoutineBuilderSheet(routine: widget.commitment)
          : CreateCommitmentSheet(commitment: widget.commitment),
    );
  }

  Future<void> _deleteCommitment() async {
    setState(() => _isDeleting = true);
    try {
      await context.read<ApiClient>().delete('/commitments/${widget.commitment.id}');
      if (mounted) {
        context.read<ScheduleProvider>().fetchDashboardData();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete commitment')),
        );
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    final startTimeStr = DateFormat('h:mm a').format(widget.commitment.startTime);
    final endTimeStr = DateFormat('h:mm a').format(widget.commitment.endTime);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + EqTokens.space24,
        left: EqTokens.space24,
        right: EqTokens.space24,
        top: EqTokens.space16,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: EqTokens.space24),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.commitment.title,
                    style: text.headlineSmall?.copyWith(color: colors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: colors.textSecondary),
                  onPressed: _editCommitment,
                ),
              ],
            ),
            
            const SizedBox(height: EqTokens.space16),

            Container(
              padding: const EdgeInsets.all(EqTokens.space16),
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.05),
                borderRadius: EqTokens.border8,
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildMetric(context, 'Time', '$startTimeStr - $endTimeStr', Icons.schedule),
                      _buildMetric(context, 'Type', widget.commitment.type == CommitmentType.routine ? 'Routine' : 'Fixed', Icons.event),
                    ],
                  ),
                  if (widget.commitment.type == CommitmentType.routine && widget.commitment.recurrence != null) ...[
                    const SizedBox(height: EqTokens.space16),
                    Row(
                      children: [
                        Icon(Icons.repeat, size: 14, color: colors.primary),
                        const SizedBox(width: EqTokens.space8),
                        Text(
                          'Recurs: ${widget.commitment.recurrence}',
                          style: text.bodySmall?.copyWith(color: colors.textSecondary),
                        )
                      ],
                    )
                  ]
                ],
              ),
            ),

            const SizedBox(height: EqTokens.space24),
            
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _isDeleting ? null : _deleteCommitment,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.danger,
                  side: BorderSide(color: colors.danger),
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: _isDeleting
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.danger, strokeWidth: 2))
                    : const Text('Delete'),
              ),
            ),
            const SizedBox(height: EqTokens.space12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: const Text('Close'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            const SizedBox(width: EqTokens.space4),
            Text(label, style: text.bodySmall?.copyWith(color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: EqTokens.space4),
        Text(value, style: text.bodyLarge?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
