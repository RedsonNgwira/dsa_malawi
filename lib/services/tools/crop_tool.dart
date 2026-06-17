import 'dart:math';
import 'package:image/image.dart' as img;

/// Tool for auto-cropping document images.
/// Detects content boundaries and removes excess whitespace.
class CropTool {
  /// Auto-crop by detecting non-white content with edge detection.
  /// Returns the cropped image, or original if no crop is needed.
  static img.Image autoCrop(img.Image source) {
    final gray = img.grayscale(source);
    final w = gray.width;
    final h = gray.height;

    int top = 0, bottom = h - 1, left = 0, right = w - 1;
    const edgeThreshold = 30;

    // Find content boundaries
    for (int y = 0; y < h; y++) {
      if (_hasEdge(gray, y, 0, w, edgeThreshold, isHorizontal: true)) {
        top = y; break;
      }
    }
    for (int y = h - 1; y > top; y--) {
      if (_hasEdge(gray, y, 0, w, edgeThreshold, isHorizontal: true)) {
        bottom = y; break;
      }
    }
    for (int x = 0; x < w; x++) {
      if (_hasEdge(gray, 0, x, h, edgeThreshold, isHorizontal: false)) {
        left = x; break;
      }
    }
    for (int x = w - 1; x > left; x--) {
      if (_hasEdge(gray, 0, x, h, edgeThreshold, isHorizontal: false)) {
        right = x; break;
      }
    }

    // Add small margin
    const margin = 5;
    top = max(0, top - margin);
    left = max(0, left - margin);
    bottom = min(h - 1, bottom + margin);
    right = min(w - 1, right + margin);

    final croppedW = right - left;
    final croppedH = bottom - top;

    // Guard: don't crop if it's too aggressive
    if (croppedW < w * 0.3 || croppedH < h * 0.3) return source;

    return img.copyCrop(source, x: left, y: top, width: croppedW, height: croppedH);
  }

  static bool _hasEdge(img.Image gray, int fixed, int start, int end, int threshold, {required bool isHorizontal}) {
    final step = (end - start) ~/ 100 + 1;
    for (int i = start; i < end; i += step) {
      final x = isHorizontal ? i : fixed;
      final y = isHorizontal ? fixed : i;
      if (_isEdge(gray, x, y, threshold)) return true;
    }
    return false;
  }

  static bool _isEdge(img.Image gray, int x, int y, int threshold) {
    if (x <= 1 || x >= gray.width - 2 || y <= 1 || y >= gray.height - 2) return false;
    final c = gray.getPixel(x, y).luminance;
    final r = gray.getPixel(x + 1, y).luminance;
    final d = gray.getPixel(x, y + 1).luminance;
    return (c - r).abs() > threshold || (c - d).abs() > threshold;
  }
}
