import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _upcomingAlerts = true;
  bool _overloadAlerts = true;
  bool _rescheduleAlerts = true;
  bool _dailyBrief = true;

  @override
  void initState() {
    super.initState();
    _loadConstraints();
  }

  void _loadConstraints() async {
    try {
      final api = context.read<ApiClient>();
      final repo = ConstraintRepository(api);
      final data = await repo.getConstraints();
      final notifications = await api.get('/notifications/preferences');
      if (mounted) {
        setState(() {
          _sleepStartCtrl.text = data['sleepStart']?.toString() ?? '23:00';
          _sleepEndCtrl.text = data['sleepEnd']?.toString() ?? '06:00';
          _minSleepCtrl.text = data['minSleepHours']?.toString() ?? '7';
          _upcomingAlerts = notifications['upcomingTaskAlerts'] == true;
          _overloadAlerts = notifications['overloadAlerts'] == true;
          _rescheduleAlerts = notifications['rescheduleAlerts'] == true;
          _dailyBrief = notifications['dailyBrief'] == true;
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

  Future<void> _saveNotifications() async {
    final api = context.read<ApiClient>();
    await api.patch('/notifications/preferences', body: {
      'upcomingTaskAlerts': _upcomingAlerts,
      'overloadAlerts': _overloadAlerts,
      'rescheduleAlerts': _rescheduleAlerts,
      'dailyBrief': _dailyBrief,
    });
  }

  Future<void> _importSyllabus() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import syllabus text'),
        content: TextField(
          controller: controller,
          maxLines: 8,
          decoration: const InputDecoration(hintText: 'One task per line, for example:\nResearch report - 2026-10-20 180m'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Find tasks')),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    try {
      final api = context.read<ApiClient>();
      final scheduleProvider = context.read<ScheduleProvider>();
      final job = await api.postText('/imports/syllabus', text);
      if (!mounted) return;
      final candidates = (job['candidates'] as List).cast<Map<String, dynamic>>();
      final selected = await showDialog<List<Map<String, dynamic>>>(
        context: context,
        builder: (context) => _CandidateDialog(candidates: candidates),
      );
      if (selected != null && selected.isNotEmpty && mounted) {
        await api.post('/imports/syllabus/${job['id']}/confirm', body: {'candidates': selected});
        await scheduleProvider.fetchDashboardData();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Confirmed tasks added to your workload.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Syllabus import could not be completed.')));
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

  Future<void> _createShareLink() async {
    try {
      final response = await context.read<ApiClient>().post('/team/shares', body: {'expiresInHours': 24});
      final token = response['token'] as String;
      final link = 'https://equilibrium-42g8.onrender.com/team/$token';
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Read-only link copied'),
          content: SelectableText(link),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done'))],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not create a share link.')));
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

            const SizedBox(height: EqTokens.space24),
            Text('NOTIFICATIONS', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: EqTokens.space8),
            _notificationSwitch('Upcoming task alerts', _upcomingAlerts, (value) { setState(() => _upcomingAlerts = value); _saveNotifications(); }),
            _notificationSwitch('Overload warnings', _overloadAlerts, (value) { setState(() => _overloadAlerts = value); _saveNotifications(); }),
            _notificationSwitch('Reschedule updates', _rescheduleAlerts, (value) { setState(() => _rescheduleAlerts = value); _saveNotifications(); }),
            _notificationSwitch('Daily readiness brief', _dailyBrief, (value) { setState(() => _dailyBrief = value); _saveNotifications(); }),
            const SizedBox(height: EqTokens.space16),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: _importSyllabus, icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Import syllabus text'))),

            const SizedBox(height: EqTokens.space24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _createShareLink,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share read-only schedule'),
              ),
            ),

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

  Widget _notificationSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    final colors = context.eqColors;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: colors.textPrimary)),
      value: value,
      onChanged: onChanged,
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

class _CandidateDialog extends StatefulWidget {
  final List<Map<String, dynamic>> candidates;
  const _CandidateDialog({required this.candidates});

  @override
  State<_CandidateDialog> createState() => _CandidateDialogState();
}

class _CandidateDialogState extends State<_CandidateDialog> {
  late final Set<String> _selected = widget.candidates.map((candidate) => candidate['id'] as String).toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review imported tasks'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(shrinkWrap: true, children: widget.candidates.map((candidate) => CheckboxListTile(
          value: _selected.contains(candidate['id']),
          title: Text(candidate['title'].toString()),
          subtitle: Text('Estimated ${candidate['estimateMinutes']} minutes'),
          onChanged: (value) => setState(() => value == true ? _selected.add(candidate['id']) : _selected.remove(candidate['id'])),
        )).toList()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, widget.candidates.map((candidate) => {...candidate, 'confirmed': _selected.contains(candidate['id'])}).toList()), child: const Text('Confirm selected')),
      ],
    );
  }
}
