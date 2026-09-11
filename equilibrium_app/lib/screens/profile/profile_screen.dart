import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/auth_provider.dart';
import '../../core/state/profile_provider.dart';
import '../../core/api/api_client.dart';
import '../../services/constraint_repository.dart';
import '../../core/state/schedule_provider.dart';
import '../routines/routines_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Profile fields
  final _nameCtrl = TextEditingController();
  final _collegeCtrl = TextEditingController();
  final _degreeCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _semesterCtrl = TextEditingController();

  // Sleep shield — store as HH:mm strings
  String _sleepStart = '23:00';
  String _sleepEnd = '07:00';
  double _minSleepHours = 7.0;
  bool _profileLoading = true;
  bool _sleepLoading = true;
  bool _savingProfile = false;

  // Notifications
  bool _upcomingAlerts = true;
  bool _overloadAlerts = true;
  bool _rescheduleAlerts = true;
  bool _dailyBrief = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _collegeCtrl.dispose();
    _degreeCtrl.dispose();
    _branchCtrl.dispose();
    _semesterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final profileProvider = context.read<ProfileProvider>();
    final api = context.read<ApiClient>();
    await profileProvider.fetchProfile();
    if (mounted && profileProvider.profile != null) {
      final p = profileProvider.profile!;
      setState(() {
        _nameCtrl.text = p.name ?? '';
        _collegeCtrl.text = p.college ?? '';
        _degreeCtrl.text = p.degree ?? '';
        _branchCtrl.text = p.branch ?? '';
        _semesterCtrl.text = p.semester ?? '';
        _profileLoading = false;
      });
    } else if (mounted) {
      setState(() => _profileLoading = false);
    }

    try {
      final repo = ConstraintRepository(api);
      final data = await repo.getConstraints();
      final notifications = await api.get('/notifications/preferences');
      if (mounted) {
        setState(() {
          _sleepStart = data['sleepStart']?.toString() ?? '23:00';
          _sleepEnd = data['sleepEnd']?.toString() ?? '07:00';
          _minSleepHours = double.tryParse(data['minSleepHours']?.toString() ?? '7') ?? 7.0;
          _upcomingAlerts = notifications['upcomingTaskAlerts'] == true;
          _overloadAlerts = notifications['overloadAlerts'] == true;
          _rescheduleAlerts = notifications['rescheduleAlerts'] == true;
          _dailyBrief = notifications['dailyBrief'] == true;
          _sleepLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sleepStart = '23:00';
          _sleepEnd = '07:00';
          _minSleepHours = 7.0;
          _sleepLoading = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _savingProfile = true);
    final updates = <String, dynamic>{};
    if (_nameCtrl.text.trim().isNotEmpty) updates['name'] = _nameCtrl.text.trim();
    if (_collegeCtrl.text.trim().isNotEmpty) updates['college'] = _collegeCtrl.text.trim();
    if (_degreeCtrl.text.trim().isNotEmpty) updates['degree'] = _degreeCtrl.text.trim();
    if (_branchCtrl.text.trim().isNotEmpty) updates['branch'] = _branchCtrl.text.trim();
    if (_semesterCtrl.text.trim().isNotEmpty) updates['semester'] = _semesterCtrl.text.trim();

    if (updates.isEmpty) {
      setState(() => _savingProfile = false);
      return;
    }

    final ok = await context.read<ProfileProvider>().updateProfile(updates);
    if (mounted) {
      setState(() => _savingProfile = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Profile saved!' : 'Could not save profile.'),
        backgroundColor: ok ? context.eqColors.success : context.eqColors.danger,
      ));
    }
  }

  Future<void> _saveNotifications() async {
    final api = context.read<ApiClient>();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('upcoming_task_alerts', _upcomingAlerts);
    try {
      await api.patch('/notifications/preferences', body: {
        'upcomingTaskAlerts': _upcomingAlerts,
        'overloadAlerts': _overloadAlerts,
        'rescheduleAlerts': _rescheduleAlerts,
        'dailyBrief': _dailyBrief,
      });
    } catch (_) {}
  }

  void _saveConstraints() async {
    setState(() => _sleepLoading = true);
    try {
      final repo = ConstraintRepository(context.read<ApiClient>());
      await repo.updateConstraints({
        'sleepStart': _sleepStart,
        'sleepEnd': _sleepEnd,
        'minSleepHours': _minSleepHours,
        'bufferMinutes': 15,
        'peakEnergyWindowsJson': '[{"start":"09:00","end":"12:00"},{"start":"15:00","end":"17:00"}]',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sleep Shield saved!', style: TextStyle(color: context.eqColors.surface)),
            backgroundColor: context.eqColors.success),
        );
        context.read<ScheduleProvider>().generateSchedule();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e'), backgroundColor: context.eqColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _sleepLoading = false);
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _displayTime(String hhmm) {
    final parts = hhmm.split(':');
    int h = int.parse(parts[0]);
    final m = int.parse(parts[1]);
    final suffix = h < 12 ? 'AM' : 'PM';
    if (h == 0) h = 12;
    if (h > 12) h -= 12;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickProfileTime(String label, String current, ValueChanged<String> onPicked) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseTime(current),
      helpText: 'Set $label',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      onPicked(_formatTime(picked));
    }
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
          decoration: const InputDecoration(hintText: 'One task per line, e.g.:\nDBMS Assignment - 2026-10-20 90m'),
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
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks imported!')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Import could not be completed.')));
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
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, _) {
          final profile = profileProvider.profile;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(EqTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Avatar + Name ─────────────────────────────────
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: colors.primary,
                        child: Text(
                          profile?.initials ?? 'EQ',
                          style: text.headlineLarge?.copyWith(color: colors.surface),
                        ),
                      ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                      const SizedBox(height: EqTokens.space12),
                      if (profile?.displayName != null)
                        Text(profile!.displayName,
                          style: text.titleMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700))
                            .animate().fade(delay: 200.ms),
                      Text(profile?.email ?? '',
                        style: text.bodySmall?.copyWith(color: colors.textSecondary))
                          .animate().fade(delay: 250.ms),
                    ],
                  ),
                ),
                const SizedBox(height: EqTokens.space32),

                // ── Student Profile ─────────────────────────────────
                _sectionLabel('STUDENT PROFILE'),
                const SizedBox(height: EqTokens.space12),
                Container(
                  padding: const EdgeInsets.all(EqTokens.space20),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border16),
                  child: Column(
                    children: [
                      _buildTextField('Full Name', _nameCtrl, hint: 'e.g. Shreya Kulkarni'),
                      _buildTextField('College / University', _collegeCtrl, hint: 'e.g. VIT Vellore'),
                      _buildTextField('Degree', _degreeCtrl, hint: 'e.g. B.Tech'),
                      _buildTextField('Branch / Programme', _branchCtrl, hint: 'e.g. CSE (AI & ML)'),
                      _buildTextField('Semester / Year', _semesterCtrl, hint: 'e.g. Semester 5'),
                      const SizedBox(height: EqTokens.space16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _profileLoading || _savingProfile ? null : _saveProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: colors.surface,
                            padding: const EdgeInsets.all(EqTokens.space14),
                            shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                          ),
                          child: _savingProfile
                              ? SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                              : const Text('Save Profile'),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

                const SizedBox(height: EqTokens.space24),

                // ── Appearance ─────────────────────────────────────
                _sectionLabel('APPEARANCE'),
                const SizedBox(height: EqTokens.space12),
                Container(
                  padding: const EdgeInsets.all(EqTokens.space20),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Theme', style: text.bodySmall?.copyWith(color: colors.textSecondary)),
                      const SizedBox(height: EqTokens.space12),
                      Row(
                        children: [
                          _themeOption(context, 'System', 'system', profileProvider),
                          const SizedBox(width: EqTokens.space8),
                          _themeOption(context, 'Light', 'light', profileProvider),
                          const SizedBox(width: EqTokens.space8),
                          _themeOption(context, 'Dark', 'dark', profileProvider),
                        ],
                      ),
                    ],
                  ),
                ).animate().fade(delay: 350.ms).slideY(begin: 0.1),

                const SizedBox(height: EqTokens.space24),

                // ── Sleep Shield ───────────────────────────────────
                _sectionLabel('SLEEP SHIELD'),
                const SizedBox(height: EqTokens.space12),
                Container(
                  padding: const EdgeInsets.all(EqTokens.space20),
                  decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border16),
                  child: _sleepLoading
                    ? const Center(child: CircularProgressIndicator())
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: _buildProfileTimeButton(
                                context,
                                label: 'Sleep Time',
                                value: _displayTime(_sleepStart),
                                icon: Icons.bedtime_outlined,
                                iconColor: colors.sleepShield,
                                onTap: () => _pickProfileTime('Sleep Time', _sleepStart,
                                    (v) => setState(() => _sleepStart = v)),
                              )),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('→', style: TextStyle(fontSize: 20)),
                              ),
                              Expanded(child: _buildProfileTimeButton(
                                context,
                                label: 'Wake Up',
                                value: _displayTime(_sleepEnd),
                                icon: Icons.wb_sunny_outlined,
                                iconColor: colors.success,
                                onTap: () => _pickProfileTime('Wake Up', _sleepEnd,
                                    (v) => setState(() => _sleepEnd = v)),
                              )),
                            ],
                          ),
                          const SizedBox(height: EqTokens.space12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.sleepShield.withValues(alpha: 0.08),
                              borderRadius: EqTokens.border8,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 13, color: colors.sleepShield),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Overnight schedules (e.g. 11:30 PM → 7:00 AM) are supported.',
                                    style: text.labelSmall?.copyWith(color: colors.sleepShield),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: EqTokens.space16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _saveConstraints,
                              icon: const Icon(Icons.save_outlined, size: 18),
                              label: const Text('Save Sleep Shield'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.sleepShield,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(EqTokens.space14),
                                shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                              ),
                            ),
                          ),
                        ],
                      ),
                ).animate().fade(delay: 400.ms).slideY(begin: 0.1),

                const SizedBox(height: EqTokens.space24),

                // ── Notifications ──────────────────────────────────
                _sectionLabel('NOTIFICATIONS'),
                _notificationSwitch('Upcoming task alerts', _upcomingAlerts,
                    (v) { setState(() => _upcomingAlerts = v); _saveNotifications(); }),
                _notificationSwitch('Overload warnings', _overloadAlerts,
                    (v) { setState(() => _overloadAlerts = v); _saveNotifications(); }),
                _notificationSwitch('Reschedule updates', _rescheduleAlerts,
                    (v) { setState(() => _rescheduleAlerts = v); _saveNotifications(); }),
                _notificationSwitch('Daily brief', _dailyBrief,
                    (v) { setState(() => _dailyBrief = v); _saveNotifications(); }),

                const SizedBox(height: EqTokens.space24),

                // ── Tools ──────────────────────────────────────────
                _sectionLabel('TOOLS'),
                const SizedBox(height: EqTokens.space8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _importSyllabus,
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Import Syllabus'),
                )),
                const SizedBox(height: EqTokens.space8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: _createShareLink,
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Share Read-Only Schedule'),
                )),
                const SizedBox(height: EqTokens.space8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RoutinesScreen())),
                  icon: const Icon(Icons.repeat),
                  label: const Text('Manage Routines'),
                )),

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
                const SizedBox(height: EqTokens.space24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _themeOption(BuildContext context, String label, String value, ProfileProvider provider) {
    final colors = context.eqColors;
    final isSelected = (provider.profile?.themePreference ?? 'system') == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => provider.setTheme(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withValues(alpha: 0.15) : colors.background,
            borderRadius: EqTokens.border8,
            border: Border.all(
              color: isSelected ? colors.primary : colors.surfaceElevated,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: isSelected ? colors.primary : colors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
              fontSize: 13,
            )),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title) {
    return Text(title, style: context.eqText.labelSmall?.copyWith(
      color: context.eqColors.textSecondary, letterSpacing: 1.2));
  }

  Widget _notificationSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    final colors = context.eqColors;
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: TextStyle(color: colors.textPrimary)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: colors.primary,
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, TextInputType? keyboardType}) {
    final colors = context.eqColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: EqTokens.space12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: colors.textSecondary),
          hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6)),
          filled: true,
          fillColor: colors.background,
          border: OutlineInputBorder(borderRadius: EqTokens.border8, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: EqTokens.border8,
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileTimeButton(BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final colors = context.eqColors;
    final text = context.eqText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: EqTokens.border8,
          border: Border.all(color: iconColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: iconColor),
            const SizedBox(height: 4),
            Text(label, style: text.labelSmall?.copyWith(color: colors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value, style: text.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('Tap to edit', style: text.labelSmall?.copyWith(color: iconColor, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// Reuse candidate dialog from before
class _CandidateDialog extends StatefulWidget {
  final List<Map<String, dynamic>> candidates;
  const _CandidateDialog({required this.candidates});

  @override
  State<_CandidateDialog> createState() => _CandidateDialogState();
}

class _CandidateDialogState extends State<_CandidateDialog> {
  late final Set<String> _selected = widget.candidates.map((c) => c['id'] as String).toSet();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Review imported tasks'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: widget.candidates.map((c) => CheckboxListTile(
            value: _selected.contains(c['id']),
            title: Text(c['title'].toString()),
            subtitle: Text('Estimated ${c['estimateMinutes']} minutes'),
            onChanged: (v) => setState(() => v == true ? _selected.add(c['id']) : _selected.remove(c['id'])),
          )).toList(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, widget.candidates.map((c) => {...c, 'confirmed': _selected.contains(c['id'])}).toList()),
          child: const Text('Confirm selected'),
        ),
      ],
    );
  }
}
