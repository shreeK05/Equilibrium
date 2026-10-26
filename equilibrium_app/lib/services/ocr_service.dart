import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract class IOcrService {
  Future<String> recognizeTextFromFile(String filePath);
  Future<String> recognizeTextFromBytes(Uint8List bytes);
  Future<void> dispose();
}

class OcrService implements IOcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _safeRecognizer {
    _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
    return _recognizer!;
  }

  @override
  Future<String> recognizeTextFromFile(String filePath) async {
    try {
      final inputImage = InputImage.fromFilePath(filePath);
      final RecognizedText recognizedText = await _safeRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      debugPrint('OcrService error recognizing text from file ($filePath): $e');
      rethrow;
    }
  }

  @override
  Future<String> recognizeTextFromBytes(Uint8List bytes) async {
    File? tempFile;
    try {
      final tempDir = Directory.systemTemp;
      tempFile = File('${tempDir.path}/ocr_${DateTime.now().microsecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      final text = await recognizeTextFromFile(tempFile.path);
      return text;
    } catch (e) {
      debugPrint('OcrService error recognizing text from bytes: $e');
      rethrow;
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
