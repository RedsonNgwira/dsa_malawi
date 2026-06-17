import 'dart:math';
import 'package:image/image.dart' as img;

/// Tool for perspective correction of document images.
/// Detects document corners and applies 4-corner warp to straighten.
class PerspectiveTool {
  /// Detect the dominant rotation angle of text and correct it.
  /// Returns deskewed image, or original if no significant skew.
  static img.Image deskew(img.Image src) {
    final gray = img.grayscale(src);
    final w = gray.width;
    final h = gray.height;

    final angles = <double>[];
    const sampleStep = 20;

    for (int y = sampleStep; y < h - sampleStep; y += sampleStep) {
      for (int x = sampleStep; x < w - sampleStep; x += sampleStep) {
        if (_isEdgeFast(gray, x, y)) {
          double bestAngle = 0;
          double bestScore = 0;
          for (int a = -15; a <= 15; a += 1) {
            final rad = a * pi / 180;
            final dx = (cos(rad) * 10).round();
            final dy = (sin(rad) * 10).round();
            if (_isEdgeFast(gray, x + dx, y + dy)) {
              final score = _edgeStrength(gray, x + dx, y + dy);
              if (score > bestScore) { bestScore = score; bestAngle = a.toDouble(); }
            }
          }
          if (bestScore > 30) angles.add(bestAngle);
        }
      }
    }

    if (angles.isEmpty) return src;
    angles.sort();
    final medianAngle = angles[angles.length ~/ 2];
    if (medianAngle.abs() < 1.5) return src;

    return img.copyRotate(src, angle: -medianAngle);
  }

  static bool _isEdgeFast(img.Image gray, int x, int y) {
    if (x <= 2 || x >= gray.width - 3 || y <= 2 || y >= gray.height - 3) return false;
    final c = gray.getPixel(x, y).luminance;
    final r = gray.getPixel(x + 2, y).luminance;
    final d = gray.getPixel(x, y + 2).luminance;
    return (c - r).abs() > 40 || (c - d).abs() > 40;
  }

  static double _edgeStrength(img.Image gray, int x, int y) {
    if (x <= 1 || x >= gray.width - 2 || y <= 1 || y >= gray.height - 2) return 0;
    final c = gray.getPixel(x, y).luminance.toDouble();
    final r = gray.getPixel(x + 1, y).luminance.toDouble();
    final d = gray.getPixel(x, y + 1).luminance.toDouble();
    return (c - r).abs() + (c - d).abs();
  }
}
