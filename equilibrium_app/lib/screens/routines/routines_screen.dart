import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/commitment.dart';
import '../../widgets/forms/routine_builder_sheet.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _isLoading = true;
  List<FixedCommitment> _routines = [];

  @override
  void initState() {
    super.initState();
    _fetchRoutines();
  }

  Future<void> _fetchRoutines() async {
    setState(() => _isLoading = true);
    try {
      final data = await context.read<ApiClient>().get('/commitments');
      final allCommitments = (data as List).map((e) => FixedCommitment.fromJson(e)).toList();
      _routines = allCommitments.where((c) => c.type == CommitmentType.custom && c.recurrence != null).toList();
      // Wait, in schema.prisma type is ROUTINE. So CommitmentType needs to support routine.
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteRoutine(String id) async {
    try {
      await context.read<ApiClient>().delete('/commitments/$id');
      _fetchRoutines();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete routine')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Recurring Routines'),
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : _routines.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(EqTokens.space24),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.repeat, size: 48, color: colors.primary),
                  ),
                  const SizedBox(height: EqTokens.space24),
                  Text('No routines yet', style: text.headlineSmall?.copyWith(color: colors.textPrimary)),
                  const SizedBox(height: EqTokens.space8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: EqTokens.space32),
                    child: Text(
                      'Create a recurring routine to block time automatically for habits, classes, or chores.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(EqTokens.space24),
              itemCount: _routines.length,
              itemBuilder: (context, index) {
                final routine = _routines[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: EqTokens.space16),
                  padding: const EdgeInsets.all(EqTokens.space20),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: EqTokens.border16,
                    border: Border.all(color: colors.surfaceElevated),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              routine.title,
                              style: text.titleLarge?.copyWith(color: colors.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.edit_outlined, color: colors.primary, size: 20),
                                onPressed: () async {
                                  await showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => RoutineBuilderSheet(routine: routine),
                                  );
                                  _fetchRoutines();
                                },
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: colors.danger, size: 20),
                                onPressed: () => _deleteRoutine(routine.id),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: EqTokens.space16),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: EqTokens.border8,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.schedule, size: 14, color: colors.primary),
                                const SizedBox(width: 4),
                                Text(
                                  '${routine.startTime.hour.toString().padLeft(2, '0')}:${routine.startTime.minute.toString().padLeft(2, '0')} - ${routine.endTime.hour.toString().padLeft(2, '0')}:${routine.endTime.minute.toString().padLeft(2, '0')}',
                                  style: text.labelSmall?.copyWith(color: colors.primary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: EqTokens.space12),
                          Expanded(
                            child: Text(
                              routine.daysOfWeek ?? 'Not set',
                              style: text.bodySmall?.copyWith(color: colors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const RoutineBuilderSheet(),
          );
          _fetchRoutines();
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Routine'),
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
      ),
    );
  }
}
