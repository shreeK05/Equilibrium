import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';
import '../../../core/theme/colors.dart';
import '../../../core/state/schedule_provider.dart';

class SyllabusImportScreen extends StatefulWidget {
  const SyllabusImportScreen({super.key});

  @override
  State<SyllabusImportScreen> createState() => _SyllabusImportScreenState();
}

class _SyllabusImportScreenState extends State<SyllabusImportScreen> {
  bool _isProcessing = false;
  String? _jobId;
  List<Map<String, dynamic>> _candidates = [];

  Future<void> _pickAndUploadPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() => _isProcessing = true);
      
      if (!mounted) return;
      final provider = context.read<ScheduleProvider>();
      final res = await provider.importSyllabusPdf(result.files.single.bytes!);
      
      if (res != null) {
        setState(() {
          _jobId = res['id'];
          _candidates = (res['candidates'] as List).map((c) => {
            'id': c['id'],
            'title': c['title'],
            'deadline': c['deadline'],
            'estimateMinutes': c['estimateMinutes'],
            'confirmed': true, // Default to true
          }).toList();
          _isProcessing = false;
        });
      } else {
        setState(() => _isProcessing = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to process syllabus')));
        }
      }
    }
  }

  Future<void> _confirmImport() async {
    if (_jobId == null) return;
    setState(() => _isProcessing = true);
    
    final provider = context.read<ScheduleProvider>();
    final success = await provider.confirmSyllabusTasks(_jobId!, _candidates);
    
    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tasks imported successfully!')));
    } else {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(provider.errorMessage ?? 'Failed to confirm tasks')));
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
        title: const Text('Import Syllabus'),
        backgroundColor: colors.background,
      ),
      body: _isProcessing 
        ? Center(child: CircularProgressIndicator(color: colors.primary))
        : _jobId == null
          ? _buildUploadView(colors, text)
          : _buildCandidatesView(colors, text),
    );
  }

  Widget _buildUploadView(EqColors colors, TextTheme text) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.picture_as_pdf_outlined, size: 64, color: colors.primary),
            const SizedBox(height: 24),
            Text('Extract Tasks from Syllabus', style: text.headlineSmall?.copyWith(color: colors.textPrimary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Text('Upload your course syllabus PDF. Equilibrium will extract assignments, projects, and deadlines automatically.',
              style: text.bodyMedium?.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _pickAndUploadPdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text('Select PDF File'),
            ).animate().shimmer(delay: 500.ms, duration: 2000.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidatesView(EqColors colors, TextTheme text) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text('Review Extracted Tasks', style: text.titleMedium?.copyWith(color: colors.textPrimary)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _candidates.length,
            itemBuilder: (context, index) {
              final c = _candidates[index];
              return CheckboxListTile(
                value: c['confirmed'],
                onChanged: (val) {
                  setState(() => c['confirmed'] = val);
                },
                title: TextFormField(
                  initialValue: c['title'],
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  style: TextStyle(color: colors.textPrimary),
                  onChanged: (val) => c['title'] = val,
                ),
                subtitle: Text('Est: ${c['estimateMinutes']}m ${c['deadline'] != null ? '| Due: ${c['deadline'].toString().substring(0, 10)}' : ''}',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                activeColor: colors.primary,
                checkColor: colors.surface,
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: colors.surfaceElevated, border: Border(top: BorderSide(color: colors.textSecondary.withValues(alpha: 0.2)))),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() { _jobId = null; _candidates = []; }),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _confirmImport,
                  style: ElevatedButton.styleFrom(backgroundColor: colors.primary, foregroundColor: colors.surface),
                  child: const Text('Import Selected'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
