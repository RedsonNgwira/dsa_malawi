import 'package:edge_detection_scan/edge_detection_scan.dart';

/// Result from auto-document edge detection.
class SmartScanResult {
  final String? imagePath;
  final bool success;
  final String? error;

  const SmartScanResult({this.imagePath, required this.success, this.error});
}

/// Service that wraps edge_detection_scan for automatic document detection.
/// Opens the native camera with real-time edge detection overlay,
/// automatically finds document boundaries, and returns the cropped image.
class SmartScannerService {
  /// Launch the smart scanner with real-time edge detection.
  /// Returns the path to the auto-cropped, perspective-corrected image.
  static Future<SmartScanResult> scanDocument() async {
    try {
      final scanner = EdgeDetectionScan();
      final results = await scanner.scanDocument();

      if (results.isNotEmpty) {
        return SmartScanResult(imagePath: results.first, success: true);
      }
      return const SmartScanResult(success: false, error: 'No image captured');
    } catch (e) {
      return SmartScanResult(success: false, error: e.toString());
    }
  }
}
