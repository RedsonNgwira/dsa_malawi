import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Result of an OCR scan.
class OcrResult {
  final String text;
  final bool success;
  final String? error;

  const OcrResult({required this.text, required this.success, this.error});
}

/// Service for Optical Character Recognition (OCR) on scanned documents.
/// Uses Google ML Kit for on-device text recognition.
class OcrService {
  static final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extract text from an image file.
  static Future<OcrResult> extractText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);
      return OcrResult(
        text: recognizedText.text,
        success: recognizedText.text.isNotEmpty,
      );
    } catch (e) {
      return OcrResult(text: '', success: false, error: e.toString());
    }
  }

  /// Search for key terms in OCR text (e.g., client name, loan amount).
  static List<String> findKeyTerms(String text, List<String> keywords) {
    return keywords.where((k) => text.toLowerCase().contains(k.toLowerCase())).toList();
  }

  /// Clean up OCR text (remove excessive whitespace, fix common OCR errors).
  static String cleanText(String text) {
    return text
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[|¦]'), 'I')
        .replaceAll(RegExp(r'[0Oo]{2,}'), '00')
        .trim();
  }

  static void dispose() {
    _recognizer.close();
  }
}
