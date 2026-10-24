import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/services/pending_operation_manager.dart';
import '../../core/utils/uuid_generator.dart';
import '../../models/task.dart';

enum TaskProgressAction {
  finished,
  madeProgress,
  needMoreTime,
  notNow,
}

class TaskProgressResult {
  final TaskProgressAction action;
  final int? actualMinutes;
  final int? additionalMinutes;
  final int? remainingMinutes;
  final int? newEstimateMinutes;
  final ReplanSummary? replanSummary;
  final String? operationId;

  const TaskProgressResult({
    required this.action,
    this.actualMinutes,
    this.additionalMinutes,
    this.remainingMinutes,
    this.newEstimateMinutes,
    this.replanSummary,
    this.operationId,
  });
}

class TaskProgressDialog extends StatefulWidget {
  final Task task;
  final int? scheduledBlockMinutes;

  const TaskProgressDialog({
    super.key,
    required this.task,
    this.scheduledBlockMinutes,
  });

  static Future<TaskProgressResult?> show(
    BuildContext context, {
    required Task task,
    int? scheduledBlockMinutes,
  }) {
    return showModalBottomSheet<TaskProgressResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TaskProgressDialog(
        task: task,
        scheduledBlockMinutes: scheduledBlockMinutes,
      ),
    );
  }

  @override
  State<TaskProgressDialog> createState() => _TaskProgressDialogState();
}

class _TaskProgressDialogState extends State<TaskProgressDialog> {
  TaskProgressAction? _selectedAction;
  late TextEditingController _finishedMinutesController;
  late TextEditingController _progressMinutesController;
  late TextEditingController _needMoreSessionController;
  late TextEditingController _needMoreExtraController;
  bool _replanOnProgress = true;
  bool _isSubmitting = false;
  bool _isAmbiguous = false;
  String? _errorMessage;
  String? _activeOperationId;
  PendingProgressOperation? _pendingOperation;

  @override
  void initState() {
    super.initState();
    final defaultFinishedMinutes = widget.task.actualMinutes > 0
        ? widget.task.actualMinutes
        : (widget.task.completedMinutes > 0
            ? widget.task.completedMinutes
            : (widget.scheduledBlockMinutes ?? widget.task.estimateMinutes));
    _finishedMinutesController = TextEditingController(text: '$defaultFinishedMinutes');

    final defaultSessionMinutes = widget.scheduledBlockMinutes ?? 30;
    _progressMinutesController = TextEditingController(text: '$defaultSessionMinutes');

    _needMoreSessionController = TextEditingController(text: '0');
    final defaultExtra = widget.task.remainingMinutes > 0 ? widget.task.remainingMinutes : 30;
    _needMoreExtraController = TextEditingController(text: '$defaultExtra');

    _finishedMinutesController.addListener(_resetOperationIdOnInputChange);
    _progressMinutesController.addListener(_resetOperationIdOnInputChange);
    _needMoreSessionController.addListener(_resetOperationIdOnInputChange);
    _needMoreExtraController.addListener(_resetOperationIdOnInputChange);

    _checkAndRestorePendingOperation();
  }

  Future<void> _checkAndRestorePendingOperation() async {
    final pending = await PendingOperationManager.getPendingOperation(widget.task.id);
    if (pending != null && mounted) {
      setState(() {
        _pendingOperation = pending;
        _activeOperationId = pending.operationId;
        _isAmbiguous = true;
        if (pending.action == 'COMPLETE') {
          _selectedAction = TaskProgressAction.finished;
          if (pending.actualMinutes != null) {
            _finishedMinutesController.text = '${pending.actualMinutes}';
          }
        } else if (pending.action == 'PROGRESS') {
          if (pending.newEstimateMinutes != null) {
            _selectedAction = TaskProgressAction.needMoreTime;
            if (pending.additionalMinutes != null) {
              _needMoreSessionController.text = '${pending.additionalMinutes}';
            }
            if (pending.remainingMinutes != null) {
              _needMoreExtraController.text = '${pending.remainingMinutes}';
            }
          } else {
            _selectedAction = TaskProgressAction.madeProgress;
            if (pending.additionalMinutes != null) {
              _progressMinutesController.text = '${pending.additionalMinutes}';
            }
          }
        }
      });
    }
  }

  void _resetOperationIdOnInputChange() {
    if (_isAmbiguous) return;
    if (_activeOperationId != null) {
      _activeOperationId = null;
    }
  }

  @override
  void dispose() {
    _finishedMinutesController.removeListener(_resetOperationIdOnInputChange);
    _progressMinutesController.removeListener(_resetOperationIdOnInputChange);
    _needMoreSessionController.removeListener(_resetOperationIdOnInputChange);
    _needMoreExtraController.removeListener(_resetOperationIdOnInputChange);
    _finishedMinutesController.dispose();
    _progressMinutesController.dispose();
    _needMoreSessionController.dispose();
    _needMoreExtraController.dispose();
    super.dispose();
  }

  Future<void> _retryPendingOperation() async {
    if (_pendingOperation == null) return;
    final op = _pendingOperation!;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final provider = context.read<ScheduleProvider>();

    // Step 1: Probe authenticated operation-status reconciliation endpoint
    Map<String, dynamic>? reconciledData;
    try {
      reconciledData = await provider.getTaskOperation(widget.task.id, op.operationId);
    } catch (_) {
      // If network drop prevents query, proceed to replay directly
    }

    if (reconciledData != null) {
      // Reconciled server commit!
      await PendingOperationManager.clearPendingOperation(widget.task.id);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _isAmbiguous = false;
        _pendingOperation = null;
      });
      Navigator.pop(
        context,
        TaskProgressResult(
          action: op.action == 'COMPLETE'
              ? TaskProgressAction.finished
              : (_selectedAction ?? TaskProgressAction.madeProgress),
          actualMinutes: op.actualMinutes,
          additionalMinutes: op.additionalMinutes,
          remainingMinutes: op.remainingMinutes,
          newEstimateMinutes: op.newEstimateMinutes,
          operationId: op.operationId,
        ),
      );
      return;
    }

    // Step 2: Replay exact payload with original operationId
    if (op.action == 'COMPLETE') {
      await _submitFinished();
    } else if (op.newEstimateMinutes != null) {
      await _submitNeedMoreTime();
    } else {
      await _submitMadeProgress();
    }
  }

  Future<void> _submitFinished() async {
    final actual = int.tryParse(_finishedMinutesController.text.trim());
    if (actual == null || actual < 0) {
      setState(() => _errorMessage = 'Please enter a valid number of minutes (>= 0)');
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final opId = _isAmbiguous && _pendingOperation != null
        ? _pendingOperation!.operationId
        : (_activeOperationId ??= generateUuidV4());

    final pendingOp = PendingProgressOperation(
      taskId: widget.task.id,
      operationId: opId,
      action: 'COMPLETE',
      actualMinutes: actual,
      remainingMinutes: 0,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await PendingOperationManager.savePendingOperation(pendingOp);
    _pendingOperation = pendingOp;

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await provider.completeTask(widget.task.id, actual, opId);
    if (!mounted) return;

    if (success) {
      await PendingOperationManager.clearPendingOperation(widget.task.id);
      if (!mounted) return;
      _pendingOperation = null;
      _isAmbiguous = false;
      Navigator.pop(
        context,
        TaskProgressResult(
          action: TaskProgressAction.finished,
          actualMinutes: actual,
          remainingMinutes: 0,
          operationId: opId,
        ),
      );
    } else {
      final isAmbiguous = provider.isLastFailureAmbiguous || (provider.lastApiException?.isAmbiguous ?? false);
      if (isAmbiguous) {
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = true;
          _errorMessage = provider.errorMessage ?? 'Network timeout / connection lost. Your update may have been saved. Tap "Retry Pending Update" to safely reconcile.';
        });
      } else {
        await PendingOperationManager.clearPendingOperation(widget.task.id);
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = false;
          _pendingOperation = null;
          _errorMessage = provider.errorMessage ?? 'Could not mark task as completed';
        });
      }
    }
  }

  Future<void> _submitMadeProgress() async {
    final additional = int.tryParse(_progressMinutesController.text.trim());
    if (additional == null || additional <= 0) {
      setState(() => _errorMessage = 'Please enter positive minutes worked (>= 1)');
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final opId = _isAmbiguous && _pendingOperation != null
        ? _pendingOperation!.operationId
        : (_activeOperationId ??= generateUuidV4());

    final newRemaining = (widget.task.remainingMinutes - additional).clamp(0, 100000);

    final pendingOp = PendingProgressOperation(
      taskId: widget.task.id,
      operationId: opId,
      action: 'PROGRESS',
      additionalMinutes: additional,
      remainingMinutes: newRemaining,
      status: 'IN_PROGRESS',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await PendingOperationManager.savePendingOperation(pendingOp);
    _pendingOperation = pendingOp;

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await provider.recordTaskProgress(
      widget.task.id,
      additionalMinutes: additional,
      remainingMinutes: newRemaining,
      status: 'IN_PROGRESS',
      operationId: opId,
    );
    if (!mounted) return;

    if (success) {
      await PendingOperationManager.clearPendingOperation(widget.task.id);
      _pendingOperation = null;
      _isAmbiguous = false;
      ReplanSummary? replanSummary;
      if (_replanOnProgress) {
        replanSummary = await provider.reschedule();
      }
      if (mounted) {
        Navigator.pop(
          context,
          TaskProgressResult(
            action: TaskProgressAction.madeProgress,
            additionalMinutes: additional,
            remainingMinutes: newRemaining,
            replanSummary: replanSummary,
            operationId: opId,
          ),
        );
      }
    } else {
      final isAmbiguous = provider.isLastFailureAmbiguous || (provider.lastApiException?.isAmbiguous ?? false);
      if (isAmbiguous) {
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = true;
          _errorMessage = provider.errorMessage ?? 'Network timeout / connection lost. Your update may have been saved. Tap "Retry Pending Update" to safely reconcile.';
        });
      } else {
        await PendingOperationManager.clearPendingOperation(widget.task.id);
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = false;
          _pendingOperation = null;
          _errorMessage = provider.errorMessage ?? 'Could not record progress';
        });
      }
    }
  }

  Future<void> _submitNeedMoreTime() async {
    final sessionMinutes = int.tryParse(_needMoreSessionController.text.trim()) ?? 0;
    final extraNeeded = int.tryParse(_needMoreExtraController.text.trim());

    if (sessionMinutes < 0) {
      setState(() => _errorMessage = 'Session minutes cannot be negative');
      return;
    }
    if (extraNeeded == null || extraNeeded <= 0) {
      setState(() => _errorMessage = 'Please enter positive additional minutes needed (>= 1)');
      return;
    }

    final provider = context.read<ScheduleProvider>();
    final newTotalEstimate = widget.task.completedMinutes + sessionMinutes + extraNeeded;
    final opId = _isAmbiguous && _pendingOperation != null
        ? _pendingOperation!.operationId
        : (_activeOperationId ??= generateUuidV4());

    final pendingOp = PendingProgressOperation(
      taskId: widget.task.id,
      operationId: opId,
      action: 'PROGRESS',
      additionalMinutes: sessionMinutes > 0 ? sessionMinutes : null,
      remainingMinutes: extraNeeded,
      newEstimateMinutes: newTotalEstimate,
      status: 'IN_PROGRESS',
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
    await PendingOperationManager.savePendingOperation(pendingOp);
    _pendingOperation = pendingOp;

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final success = await provider.recordTaskProgress(
      widget.task.id,
      additionalMinutes: sessionMinutes > 0 ? sessionMinutes : null,
      remainingMinutes: extraNeeded,
      newEstimateMinutes: newTotalEstimate,
      status: 'IN_PROGRESS',
      operationId: opId,
    );
    if (!mounted) return;

    if (success) {
      await PendingOperationManager.clearPendingOperation(widget.task.id);
      _pendingOperation = null;
      _isAmbiguous = false;
      final replanSummary = await provider.reschedule();
      if (mounted) {
        Navigator.pop(
          context,
          TaskProgressResult(
            action: TaskProgressAction.needMoreTime,
            additionalMinutes: sessionMinutes,
            remainingMinutes: extraNeeded,
            newEstimateMinutes: newTotalEstimate,
            replanSummary: replanSummary,
            operationId: opId,
          ),
        );
      }
    } else {
      final isAmbiguous = provider.isLastFailureAmbiguous || (provider.lastApiException?.isAmbiguous ?? false);
      if (isAmbiguous) {
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = true;
          _errorMessage = provider.errorMessage ?? 'Network timeout / connection lost. Your update may have been saved. Tap "Retry Pending Update" to safely reconcile.';
        });
      } else {
        await PendingOperationManager.clearPendingOperation(widget.task.id);
        setState(() {
          _isSubmitting = false;
          _isAmbiguous = false;
          _pendingOperation = null;
          _errorMessage = provider.errorMessage ?? 'Could not update task estimate';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Material(
      color: colors.background,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      child: Padding(
        padding: EdgeInsets.only(
          left: EqTokens.space24,
          right: EqTokens.space24,
          top: EqTokens.space24,
          bottom: MediaQuery.of(context).viewInsets.bottom + EqTokens.space24,
        ),
        child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.surface.withValues(alpha: 0.3),
                  borderRadius: EqTokens.border4,
                ),
              ),
            ),
            const SizedBox(height: EqTokens.space16),

            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TASK PROGRESS',
                        style: text.labelSmall?.copyWith(
                          color: colors.textSecondary,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: EqTokens.space4),
                      Text(
                        widget.task.title,
                        style: text.headlineSmall?.copyWith(
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: EqTokens.space4),
                      Text(
                        '${widget.task.actualMinutes}m effort logged • ${widget.task.remainingMinutes}m remaining',
                        style: text.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: colors.textSecondary),
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context, null),
                ),
              ],
            ),

            if (_isAmbiguous) ...[
              const SizedBox(height: EqTokens.space12),
              Container(
                key: const Key('ambiguous_recovery_banner'),
                width: double.infinity,
                padding: const EdgeInsets.all(EqTokens.space12),
                decoration: BoxDecoration(
                  color: colors.warning.withValues(alpha: 0.15),
                  borderRadius: EqTokens.border8,
                  border: Border.all(color: colors.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sync_problem_rounded, size: 20, color: colors.warning),
                    const SizedBox(width: EqTokens.space8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pending update outcome unconfirmed',
                            style: text.labelMedium?.copyWith(
                              color: colors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: EqTokens.space4),
                          Text(
                            'The server may have already committed this update. Inputs are locked to prevent double-counting. Tap "Retry Pending Update" below to safely verify and reconcile.',
                            style: text.bodySmall?.copyWith(color: colors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_errorMessage != null) ...[
              const SizedBox(height: EqTokens.space12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(EqTokens.space12),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.1),
                  borderRadius: EqTokens.border8,
                  border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, size: 16, color: colors.danger),
                    const SizedBox(width: EqTokens.space8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: text.bodySmall?.copyWith(color: colors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: EqTokens.space20),

            // Mode Selector / Details
            if (_selectedAction == null) ...[
              _buildActionTile(
                action: TaskProgressAction.finished,
                icon: Icons.check_circle_outline,
                iconColor: colors.success,
                title: 'Finished',
                subtitle: 'Task is complete. Mark as done and keep actual effort history.',
                onTap: () => setState(() {
                  _selectedAction = TaskProgressAction.finished;
                  _activeOperationId = null;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: EqTokens.space12),
              _buildActionTile(
                action: TaskProgressAction.madeProgress,
                icon: Icons.trending_up,
                iconColor: colors.primary,
                title: 'Made Progress',
                subtitle: 'Record time spent on this session. Unfinished workload remains active.',
                onTap: () => setState(() {
                  _selectedAction = TaskProgressAction.madeProgress;
                  _activeOperationId = null;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: EqTokens.space12),
              _buildActionTile(
                action: TaskProgressAction.needMoreTime,
                icon: Icons.more_time,
                iconColor: colors.warning,
                title: 'Need More Time',
                subtitle: 'Task took longer than estimated. Increase workload and re-plan your day.',
                onTap: () => setState(() {
                  _selectedAction = TaskProgressAction.needMoreTime;
                  _activeOperationId = null;
                  _errorMessage = null;
                }),
              ),
              const SizedBox(height: EqTokens.space12),
              _buildActionTile(
                action: TaskProgressAction.notNow,
                icon: Icons.schedule,
                iconColor: colors.textSecondary,
                title: 'Not Now',
                subtitle: 'Keep task active without marking it complete or changing progress.',
                onTap: () => Navigator.pop(context, null),
              ),
            ] else if (_selectedAction == TaskProgressAction.finished) ...[
              _buildFinishedForm(context),
            ] else if (_selectedAction == TaskProgressAction.madeProgress) ...[
              _buildMadeProgressForm(context),
            ] else if (_selectedAction == TaskProgressAction.needMoreTime) ...[
              _buildNeedMoreTimeForm(context),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildActionTile({
    required TaskProgressAction action,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.eqColors;
    final text = context.eqText;

    return InkWell(
      onTap: (_isSubmitting || _isAmbiguous) ? null : onTap,
      borderRadius: EqTokens.border12,
      child: Container(
        padding: const EdgeInsets.all(EqTokens.space16),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: EqTokens.border12,
          border: Border.all(color: colors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(EqTokens.space8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: EqTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.labelLarge?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: EqTokens.space4),
                  Text(
                    subtitle,
                    style: text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishedForm(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackHeader('Mark as Finished'),
        const SizedBox(height: EqTokens.space16),
        Text(
          'Total actual time spent (minutes):',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: EqTokens.space8),
        TextField(
          controller: _finishedMinutesController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isSubmitting && !_isAmbiguous,
          decoration: InputDecoration(
            hintText: 'e.g. 45',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: EqTokens.border8),
            helperText: 'Reflects total effort spent, whether shorter or longer than the estimate.',
          ),
        ),
        const SizedBox(height: EqTokens.space24),
        SizedBox(
          width: double.infinity,
          child: _isAmbiguous
              ? ElevatedButton(
                  key: const Key('retry_pending_button'),
                  onPressed: _isSubmitting ? null : _retryPendingOperation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Retry Pending Update', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                )
              : ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitFinished,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Confirm Task Finished', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ),
      ],
    );
  }

  Widget _buildMadeProgressForm(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackHeader('Record Session Progress'),
        const SizedBox(height: EqTokens.space16),
        Text(
          'Minutes completed in this session:',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: EqTokens.space8),
        TextField(
          controller: _progressMinutesController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isSubmitting && !_isAmbiguous,
          decoration: InputDecoration(
            hintText: 'e.g. 30',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: EqTokens.border8),
            helperText: 'Added to your total logged time. Unfinished workload remains scheduled.',
          ),
        ),
        const SizedBox(height: EqTokens.space16),
        SwitchListTile(
          value: _replanOnProgress,
          onChanged: (_isSubmitting || _isAmbiguous) ? null : (val) => setState(() => _replanOnProgress = val),
          title: Text(
            'Re-plan remaining schedule',
            style: text.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          subtitle: Text(
            'Adapts your remaining tasks to current time and saved progress.',
            style: text.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          contentPadding: EdgeInsets.zero,
          activeThumbColor: colors.primary,
          activeTrackColor: colors.primary.withValues(alpha: 0.5),
        ),
        const SizedBox(height: EqTokens.space24),
        SizedBox(
          width: double.infinity,
          child: _isAmbiguous
              ? ElevatedButton(
                  key: const Key('retry_pending_button'),
                  onPressed: _isSubmitting ? null : _retryPendingOperation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Retry Pending Update', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                )
              : ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitMadeProgress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: colors.surface,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2),
                        )
                      : const Text('Save Progress', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ),
      ],
    );
  }

  Widget _buildNeedMoreTimeForm(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBackHeader('Need More Time'),
        const SizedBox(height: EqTokens.space16),
        Text(
          'Minutes worked in this session:',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: EqTokens.space8),
        TextField(
          controller: _needMoreSessionController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isSubmitting && !_isAmbiguous,
          decoration: InputDecoration(
            hintText: '0',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: EqTokens.border8),
            helperText: 'Untracked effort (leave 0 if already recorded by focus timer).',
          ),
        ),
        const SizedBox(height: EqTokens.space16),
        Text(
          'Additional minutes needed to finish:',
          style: text.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        const SizedBox(height: EqTokens.space8),
        TextField(
          controller: _needMoreExtraController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          enabled: !_isSubmitting && !_isAmbiguous,
          decoration: InputDecoration(
            hintText: '30',
            suffixText: 'min',
            border: OutlineInputBorder(borderRadius: EqTokens.border8),
            helperText: 'Estimated work remaining to be scheduled in future slots.',
          ),
        ),
        const SizedBox(height: EqTokens.space16),
        Container(
          padding: const EdgeInsets.all(EqTokens.space12),
          decoration: BoxDecoration(
            color: colors.warning.withValues(alpha: 0.1),
            borderRadius: EqTokens.border8,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: colors.warning),
              const SizedBox(width: EqTokens.space8),
              Expanded(
                child: Text(
                  'We will update the task workload and automatically re-plan your remaining day.',
                  style: text.bodySmall?.copyWith(color: colors.warning),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: EqTokens.space24),
        SizedBox(
          width: double.infinity,
          child: _isAmbiguous
              ? ElevatedButton(
                  key: const Key('retry_pending_button'),
                  onPressed: _isSubmitting ? null : _retryPendingOperation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh_rounded, size: 20),
                            SizedBox(width: 8),
                            Text('Retry Pending Update', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                )
              : ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitNeedMoreTime,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.warning,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.all(EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                        )
                      : const Text('Save & Re-plan My Remaining Day', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
        ),
      ],
    );
  }

  Widget _buildBackHeader(String title) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back),
          color: colors.textSecondary,
          onPressed: (_isSubmitting || _isAmbiguous) ? null : () => setState(() {
            _selectedAction = null;
            _activeOperationId = null;
            _errorMessage = null;
          }),
        ),
        const SizedBox(width: EqTokens.space8),
        Text(
          title,
          style: text.headlineSmall?.copyWith(
            color: colors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
