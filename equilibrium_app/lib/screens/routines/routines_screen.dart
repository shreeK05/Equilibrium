import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

class RoutineItemModel {
  String id;
  String title;
  String startTime;
  String endTime;
  bool isEnabled;
  String category;

  RoutineItemModel({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.isEnabled,
    required this.category,
  });

  factory RoutineItemModel.fromJson(Map<String, dynamic> json) {
    return RoutineItemModel(
      id: json['id'] as String? ?? 'routine_${DateTime.now().millisecondsSinceEpoch}',
      title: json['title'] as String? ?? 'Routine',
      startTime: json['startTime'] as String? ?? '08:00',
      endTime: json['endTime'] as String? ?? '08:45',
      isEnabled: json['isEnabled'] as bool? ?? true,
      category: json['category'] as String? ?? 'MEAL',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime,
    'endTime': endTime,
    'isEnabled': isEnabled,
    'category': category,
  };
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<RoutineItemModel> _routines = [];

  final List<RoutineItemModel> _defaults = [
    RoutineItemModel(
      id: 'routine_breakfast',
      title: 'Breakfast',
      startTime: '08:00',
      endTime: '08:45',
      isEnabled: true,
      category: 'MEAL',
    ),
    RoutineItemModel(
      id: 'routine_lunch',
      title: 'Lunch',
      startTime: '13:00',
      endTime: '14:00',
      isEnabled: true,
      category: 'MEAL',
    ),
    RoutineItemModel(
      id: 'routine_evening_break',
      title: 'Evening Break / Exercise',
      startTime: '17:30',
      endTime: '18:00',
      isEnabled: true,
      category: 'BREAK',
    ),
    RoutineItemModel(
      id: 'routine_dinner',
      title: 'Dinner',
      startTime: '20:00',
      endTime: '21:00',
      isEnabled: true,
      category: 'MEAL',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final provider = context.read<ScheduleProvider>();
    final list = await provider.getRoutines();
    if (!mounted) return;

    setState(() {
      if (list.isEmpty) {
        _routines = List.from(_defaults);
      } else {
        _routines = list.map((m) => RoutineItemModel.fromJson(m)).toList();
      }
      _isLoading = false;
    });
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final routine = _routines[index];
    final currentStr = isStart ? routine.startTime : routine.endTime;
    final parts = currentStr.split(':');
    final initialTime = TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );

    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (picked != null && mounted) {
      final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        if (isStart) {
          routine.startTime = formatted;
        } else {
          routine.endTime = formatted;
        }
      });
    }
  }

  Future<void> _saveRoutines() async {
    setState(() => _isSaving = true);
    final provider = context.read<ScheduleProvider>();
    final payload = _routines.map((r) => r.toJson()).toList();
    final ok = await provider.updateRoutines(payload);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Daily routines & meals saved! Schedule rebalanced. 🥗'),
          backgroundColor: context.eqColors.success,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to save routines.'),
          backgroundColor: context.eqColors.danger,
        ),
      );
    }
  }

  void _addCustomRoutine() {
    showDialog(
      context: context,
      builder: (ctx) {
        final titleController = TextEditingController();
        String category = 'PERSONAL';
        return AlertDialog(
          title: const Text('Add Routine / Break'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Routine Name',
                  hintText: 'e.g. Gym Workout, Commute',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: const [
                  DropdownMenuItem(value: 'MEAL', child: Text('Meal / Snack')),
                  DropdownMenuItem(value: 'BREAK', child: Text('Short / Energy Break')),
                  DropdownMenuItem(value: 'PERSONAL', child: Text('Personal Routine / Commute')),
                ],
                onChanged: (val) {
                  if (val != null) category = val;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = titleController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _routines.add(RoutineItemModel(
                      id: 'routine_${DateTime.now().millisecondsSinceEpoch}',
                      title: name,
                      startTime: '18:00',
                      endTime: '19:00',
                      isEnabled: true,
                      category: category,
                    ));
                  });
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Meals & Daily Routines'),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Routine',
            onPressed: _addCustomRoutine,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(EqTokens.space20),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(EqTokens.space16),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    borderRadius: EqTokens.border12,
                    border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: colors.primary, size: 24),
                      const SizedBox(width: EqTokens.space12),
                      Expanded(
                        child: Text(
                          'Equilibrium guarantees your meal times, short breaks, and daily personal routines are protected. The scheduler will never place study sessions over these times.',
                          style: text.bodySmall?.copyWith(color: colors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade().slideY(begin: -0.1),

                const SizedBox(height: EqTokens.space20),

                ...List.generate(_routines.length, (idx) {
                  final routine = _routines[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: EqTokens.space12),
                    shape: RoundedRectangleBorder(
                      borderRadius: EqTokens.border12,
                      side: BorderSide(color: colors.cardBorder),
                    ),
                    color: colors.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(EqTokens.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    routine.category == 'MEAL'
                                        ? Icons.restaurant
                                        : (routine.category == 'BREAK'
                                            ? Icons.free_breakfast
                                            : Icons.fitness_center),
                                    color: routine.isEnabled ? colors.primary : colors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: EqTokens.space8),
                                  Text(
                                    routine.title,
                                    style: text.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: routine.isEnabled ? colors.textPrimary : colors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                              Switch(
                                value: routine.isEnabled,
                                activeThumbColor: colors.primary,
                                onChanged: (val) {
                                  setState(() => routine.isEnabled = val);
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: EqTokens.space8),
                          Row(
                            children: [
                              Text(
                                'Time Window:',
                                style: text.bodySmall?.copyWith(color: colors.textSecondary),
                              ),
                              const Spacer(),
                              InkWell(
                                onTap: () => _pickTime(idx, true),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.cardBorder),
                                  ),
                                  child: Text(
                                    routine.startTime,
                                    style: text.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text('to'),
                              ),
                              InkWell(
                                onTap: () => _pickTime(idx, false),
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceElevated,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: colors.cardBorder),
                                  ),
                                  child: Text(
                                    routine.endTime,
                                    style: text.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ),
                              if (idx >= _defaults.length) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.delete_outline, size: 18, color: colors.danger),
                                  onPressed: () {
                                    setState(() => _routines.removeAt(idx));
                                  },
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ).animate().fade(delay: (50 * idx).ms);
                }),

                const SizedBox(height: EqTokens.space24),

                ElevatedButton(
                  onPressed: _isSaving ? null : _saveRoutines,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: EqTokens.space16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Save & Protect Routines',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(height: EqTokens.space40),
              ],
            ),
    );
  }
}
