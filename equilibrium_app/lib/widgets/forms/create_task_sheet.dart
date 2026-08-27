import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

class CreateTaskSheet extends StatefulWidget {
  const CreateTaskSheet({super.key});

  @override
  State<CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends State<CreateTaskSheet> {
  final _titleCtrl = TextEditingController();
  int _estimateMinutes = 60;
  DateTime _deadline = DateTime.now().add(const Duration(days: 1));
  String _cognitiveLoad = 'MEDIUM';

  final List<int> _durationOptions = [30, 60, 90, 120, 180, 240];

  void _submit() async {
    if (_titleCtrl.text.isEmpty) return;

    final provider = context.read<ScheduleProvider>();
    final success = await provider.createTask({
      'title': _titleCtrl.text.trim(),
      'estimateMinutes': _estimateMinutes,
      'deadline': _deadline.toUtc().toIso8601String(),
      'cognitiveLoad': _cognitiveLoad,
      'academicWeight': 0.5,
      'teamImpactWeight': 0.0,
    });

    if (success && mounted) {
      Navigator.pop(context);
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
            Text('Add Responsibility', style: text.headlineLarge?.copyWith(color: colors.textPrimary)),
            const SizedBox(height: EqTokens.space24),
            
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'What do you need to do?',
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
              ),
            ),
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
                  labelStyle: TextStyle(color: isSelected ? colors.surface : colors.textPrimary),
                );
              }).toList(),
            ),
            
            const SizedBox(height: EqTokens.space24),
            
            Text('Cognitive Load', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: EqTokens.space8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'LOW', label: Text('Low')),
                ButtonSegment(value: 'MEDIUM', label: Text('Medium')),
                ButtonSegment(value: 'HIGH', label: Text('High')),
              ],
              selected: {_cognitiveLoad},
              onSelectionChanged: (set) => setState(() => _cognitiveLoad = set.first),
            ),

            const SizedBox(height: EqTokens.space32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: Text('Add to Workload', style: text.labelLarge?.copyWith(color: colors.surface)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
