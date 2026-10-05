import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:convert';
import '../../../core/theme/theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/state/schedule_provider.dart';

class IcsImportScreen extends StatefulWidget {
  const IcsImportScreen({super.key});

  @override
  State<IcsImportScreen> createState() => _IcsImportScreenState();
}

class _IcsImportScreenState extends State<IcsImportScreen> {
  bool _isProcessing = false;
  Map<String, dynamic>? _importResult;

  Future<void> _pickAndUploadIcs() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ics'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _isProcessing = true);
      
      final icsText = utf8.decode(result.files.single.bytes!);
      final provider = context.read<ScheduleProvider>();
      final res = await provider.importIcs(icsText);
      
      if (res != null) {
        setState(() {
          _importResult = res;
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to import ICS')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Import Calendar (ICS)'),
        backgroundColor: colors.background,
      ),
      body: _isProcessing 
        ? Center(child: CircularProgressIndicator(color: colors.primary))
        : _importResult == null
          ? _buildUploadView(colors, text)
          : _buildResultView(colors, text),
    );
  }

  Widget _buildUploadView(EqColors colors, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_outlined, size: 64, color: colors.primary),
            const SizedBox(height: 24),
            Text('Import Calendar Events', style: text.headlineSmall?.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('Upload an .ics file from Google Calendar, Outlook, or your university portal. We will add them as Fixed Commitments.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _pickAndUploadIcs,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Select ICS File'),
            ).animate().shimmer(delay: 500.ms, duration: 2000.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView(EqColors colors, TextTheme text) {
    final count = _importResult?['importedCount'] ?? 0;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: colors.primary).animate().scale().fadeIn(),
          const SizedBox(height: 24),
          Text('Successfully Imported!', style: text.headlineSmall?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 8),
          Text('$count commitments added to your schedule.', style: text.bodyLarge?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.surface),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
