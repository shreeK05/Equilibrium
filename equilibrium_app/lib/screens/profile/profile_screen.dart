import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/auth_provider.dart';
import '../../core/api/api_client.dart';
import '../../services/constraint_repository.dart';
import '../../core/state/schedule_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _sleepStartCtrl = TextEditingController();
  final _sleepEndCtrl = TextEditingController();
  final _minSleepCtrl = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConstraints();
  }

  void _loadConstraints() async {
    try {
      final repo = ConstraintRepository(context.read<ApiClient>());
      final data = await repo.getConstraints();
      if (mounted) {
        setState(() {
          _sleepStartCtrl.text = data['sleepStart']?.toString() ?? '23:00';
          _sleepEndCtrl.text = data['sleepEnd']?.toString() ?? '06:00';
          _minSleepCtrl.text = data['minSleepHours']?.toString() ?? '7';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sleepStartCtrl.text = '23:00';
          _sleepEndCtrl.text = '06:00';
          _minSleepCtrl.text = '7';
          _isLoading = false;
        });
      }
    }
  }

  void _saveConstraints() async {
    setState(() => _isLoading = true);
    try {
      final repo = ConstraintRepository(context.read<ApiClient>());
      await repo.updateConstraints({
        'sleepStart': _sleepStartCtrl.text,
        'sleepEnd': _sleepEndCtrl.text,
        'minSleepHours': int.tryParse(_minSleepCtrl.text) ?? 7,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preferences saved successfully', style: TextStyle(color: context.eqColors.surface))),
        );
        // Regenerate schedule with new constraints
        context.read<ScheduleProvider>().generateSchedule();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Profile & Settings'),
        centerTitle: false,
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(EqTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: colors.primary,
                    child: Text('EQ', style: text.headlineLarge?.copyWith(color: colors.surface)),
                  ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: EqTokens.space16),
                  Text('Student Account', style: text.titleMedium?.copyWith(color: colors.textPrimary))
                      .animate().fade(delay: 200.ms),
                ],
              ),
            ),
            const SizedBox(height: EqTokens.space48),
            
            Text('SLEEP SHIELD CONSTRAINTS', style: text.labelSmall?.copyWith(color: colors.textSecondary))
                .animate().fade(delay: 300.ms),
            const SizedBox(height: EqTokens.space16),
            
            Container(
              padding: const EdgeInsets.all(EqTokens.space24),
              decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border24),
              child: Column(
                children: [
                  _buildTextField('Sleep Start (HH:MM)', _sleepStartCtrl),
                  const SizedBox(height: EqTokens.space16),
                  _buildTextField('Sleep End (HH:MM)', _sleepEndCtrl),
                  const SizedBox(height: EqTokens.space16),
                  _buildTextField('Min Sleep Hours', _minSleepCtrl, keyboardType: TextInputType.number),
                  const SizedBox(height: EqTokens.space24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConstraints,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: colors.surface,
                        padding: const EdgeInsets.all(EqTokens.space16),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                      ),
                      child: _isLoading 
                          ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                          : const Text('Save Constraints'),
                    ),
                  ),
                ],
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.1),

            const SizedBox(height: EqTokens.space48),
            
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => context.read<AuthProvider>().logout(),
                icon: Icon(Icons.logout, color: colors.danger),
                label: Text('Log Out', style: text.labelLarge?.copyWith(color: colors.danger)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
              ),
            ).animate().fade(delay: 500.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    final colors = context.eqColors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: colors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.textSecondary),
        filled: true,
        fillColor: colors.background,
        border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
      ),
    );
  }
}
