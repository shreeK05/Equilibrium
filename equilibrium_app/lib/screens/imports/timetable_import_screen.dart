import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';

import '../../services/ocr_service.dart';

class TimetableImportScreen extends StatefulWidget {
  final IOcrService? ocrService;
  const TimetableImportScreen({super.key, this.ocrService});

  @override
  State<TimetableImportScreen> createState() => _TimetableImportScreenState();
}

class _TimetableImportScreenState extends State<TimetableImportScreen> {
  final _manualTextCtrl = TextEditingController();
  late final IOcrService _ocrService;

  bool _isParsing = false;
  bool _isConfirming = false;
  String? _errorMessage;
  String? _jobId;

  List<Map<String, dynamic>> _candidates = [];

  final List<String> _dayNames = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

  @override
  void initState() {
    super.initState();
    _ocrService = widget.ocrService ?? OcrService();
  }

  @override
  void dispose() {
    if (widget.ocrService == null) {
      _ocrService.dispose();
    }
    _manualTextCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() {
      _errorMessage = null;
      _isParsing = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final fileName = file.name;

        String extractedText = '';
        if (file.path != null && file.path!.isNotEmpty) {
          extractedText = await _ocrService.recognizeTextFromFile(file.path!);
        } else if (file.bytes != null) {
          extractedText = await _ocrService.recognizeTextFromBytes(file.bytes!);
        } else {
          throw Exception('Unable to read selected image data.');
        }

        if (extractedText.trim().isEmpty) {
          if (mounted) {
            setState(() {
              _errorMessage = 'No text could be extracted from this image. Please ensure the timetable image is clear and legible.';
              _isParsing = false;
            });
          }
          return;
        }

        _manualTextCtrl.text = extractedText.trim();
        await _parseText(extractedText.trim(), sourceName: fileName);
      } else {
        if (mounted) setState(() => _isParsing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to extract text from image: ${e.toString()}';
          _isParsing = false;
        });
      }
    }
  }

  Future<void> _parseText(String text, {String sourceName = 'manual-text'}) async {
    if (text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide or select a timetable.');
      return;
    }

    setState(() {
      _isParsing = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiClient>();
      final data = await api.post('/imports/timetable/parse', body: {
        'rawText': text.trim(),
        'sourceName': sourceName,
      }) as Map<String, dynamic>;

      final list = (data['candidates'] as List<dynamic>?) ?? [];
      setState(() {
        _jobId = data['jobId'] as String?;
        _candidates = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      setState(() => _errorMessage = 'Failed to parse timetable: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isParsing = false);
    }
  }

  Future<void> _confirmAndSave() async {
    if (_candidates.isEmpty) return;
    setState(() {
      _isConfirming = true;
      _errorMessage = null;
    });

    try {
      final api = context.read<ApiClient>();
      final entries = _candidates.map((c) => {
        'title': c['subject'] as String? ?? 'Lecture',
        'startTime': c['startTime'] as String? ?? '09:00',
        'endTime': c['endTime'] as String? ?? '10:00',
        'dayOfWeek': (c['dayOfWeek'] as num?)?.toInt() ?? 1,
        'venue': c['venue'] as String?,
      }).toList();

      final jobId = _jobId ?? 'temp-job';
      await api.post('/imports/timetable/$jobId/confirm', body: { 'entries': entries });

      if (mounted) {
        final colors = context.eqColors;
        await context.read<ScheduleProvider>().fetchDashboardData();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported ${_candidates.length} recurring classes!'),
            backgroundColor: colors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to confirm timetable: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  void _editCandidate(int index) {
    final item = _candidates[index];
    final titleCtrl = TextEditingController(text: item['subject'] as String? ?? '');
    final venueCtrl = TextEditingController(text: item['venue'] as String? ?? '');
    int selectedDay = (item['dayOfWeek'] as num?)?.toInt() ?? 1;
    String startStr = item['startTime'] as String? ?? '09:00';
    String endStr = item['endTime'] as String? ?? '10:00';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Timetable Row'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedDay,
                  decoration: const InputDecoration(labelText: 'Day of Week'),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_dayNames[i]))),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedDay = val);
                  },
                ),
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Subject Name')),
                TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue / Room')),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'Start (HH:mm)'),
                        controller: TextEditingController(text: startStr),
                        onChanged: (v) => startStr = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(labelText: 'End (HH:mm)'),
                        controller: TextEditingController(text: endStr),
                        onChanged: (v) => endStr = v,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _candidates[index]['subject'] = titleCtrl.text.trim();
                  _candidates[index]['venue'] = venueCtrl.text.trim().isNotEmpty ? venueCtrl.text.trim() : null;
                  _candidates[index]['dayOfWeek'] = selectedDay;
                  _candidates[index]['dayName'] = _dayNames[selectedDay];
                  _candidates[index]['startTime'] = startStr;
                  _candidates[index]['endTime'] = endStr;
                  _candidates[index]['isUncertain'] = false;
                });
                Navigator.pop(ctx);
              },
              child: const Text('Save Row'),
            ),
          ],
        ),
      ),
    );
  }

  void _addNewRow() {
    setState(() {
      _candidates.add({
        'id': 'manual-${DateTime.now().millisecondsSinceEpoch}',
        'dayOfWeek': 1,
        'dayName': 'Monday',
        'startTime': '09:00',
        'endTime': '10:00',
        'subject': 'New Lecture',
        'venue': 'Room 101',
        'isUncertain': false,
        'confidence': 1.0,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Import College Timetable'),
        backgroundColor: colors.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(EqTokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header instructions
            Text(
              'Upload or Scan Timetable',
              style: text.headlineSmall?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: EqTokens.space8),
            Text(
              'Extract weekly classes and labs directly from your college timetable image. All entries are fully editable before saving.',
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: EqTokens.space20),

            // Action Buttons Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isParsing ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Select Image'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                    ),
                  ),
                ),
                const SizedBox(width: EqTokens.space12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isParsing ? null : () => _parseText(_manualTextCtrl.text),
                    icon: const Icon(Icons.text_fields_outlined),
                    label: const Text('Parse Text'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space16),

            // Manual Text Input field
            TextField(
              controller: _manualTextCtrl,
              maxLines: 4,
              style: text.bodySmall?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Or paste OCR text here:\nMon 09:00 - 10:00 DBMS Room 302\nTue 10:00 - 11:00 Operating Systems LH-1',
                hintStyle: text.bodySmall?.copyWith(color: colors.textSecondary.withValues(alpha: 0.6)),
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: EqTokens.border12),
              ),
            ),

            if (_isParsing) ...[
              const SizedBox(height: EqTokens.space24),
              const Center(child: CircularProgressIndicator()),
            ],

            if (_errorMessage != null) ...[
              const SizedBox(height: EqTokens.space16),
              Container(
                padding: const EdgeInsets.all(EqTokens.space12),
                decoration: BoxDecoration(
                  color: colors.danger.withValues(alpha: 0.1),
                  borderRadius: EqTokens.border12,
                  border: Border.all(color: colors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(_errorMessage!, style: text.bodySmall?.copyWith(color: colors.danger)),
              ),
            ],

            // Candidates Preview Table
            if (_candidates.isNotEmpty) ...[
              const SizedBox(height: EqTokens.space24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Extracted Classes (${_candidates.length})',
                    style: text.titleMedium?.copyWith(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addNewRow,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Row'),
                  ),
                ],
              ),
              const SizedBox(height: EqTokens.space8),

              // Table list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _candidates.length,
                itemBuilder: (context, i) {
                  final item = _candidates[i];
                  final isUncertain = item['isUncertain'] == true;
                  final isDuplicate = item['isDuplicate'] == true;

                  return Card(
                    margin: const EdgeInsets.only(bottom: EqTokens.space8),
                    color: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: EqTokens.border12,
                      side: BorderSide(
                        color: isUncertain ? Colors.orange.withValues(alpha: 0.5) : colors.cardBorder,
                      ),
                    ),
                    child: ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              item['subject'] as String? ?? 'Lecture',
                              style: text.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                          ),
                          if (isUncertain)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Verify', style: text.labelSmall?.copyWith(color: Colors.orange.shade800)),
                            ),
                          if (isDuplicate)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: colors.danger.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text('Duplicate', style: text.labelSmall?.copyWith(color: colors.danger)),
                            ),
                        ],
                      ),
                      subtitle: Text(
                        '${item['dayName']} • ${item['startTime']} - ${item['endTime']}${item['venue'] != null ? ' • ${item['venue']}' : ''}',
                        style: text.bodySmall?.copyWith(color: colors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editCandidate(i),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: colors.danger),
                            onPressed: () => setState(() => _candidates.removeAt(i)),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: EqTokens.space24),

              // Confirm Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isConfirming ? null : _confirmAndSave,
                  icon: _isConfirming
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isConfirming ? 'Importing...' : 'Confirm & Save Timetable (${_candidates.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
