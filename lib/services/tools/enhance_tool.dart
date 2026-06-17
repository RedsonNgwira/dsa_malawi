import 'package:image/image.dart' as img;

/// Tool for enhancing document scan quality.
/// Handles background whitening, auto-level, contrast, brightness.
class EnhanceTool {
  /// Full enhancement pipeline for a single image.
  static img.Image enhance(img.Image src) {
    var result = whitenBackground(src);
    result = autoLevel(result);
    return result;
  }

  /// Convert near-white to pure white, darken near-black for text.
  static img.Image whitenBackground(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      int r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      // White push: pixels near white → pure white
      if (r > 200 && g > 200 && b > 200) {
        final brightness = (r + g + b) / 3;
        if (brightness > 230) {
          r = 255; g = 255; b = 255;
        } else {
          final factor = (brightness - 200) / 55;
          r = (r + (255 - r) * factor).round().clamp(0, 255);
          g = (g + (255 - g) * factor).round().clamp(0, 255);
          b = (b + (255 - b) * factor).round().clamp(0, 255);
        }
      }

      // Text darken: near-black → more black for contrast
      if (r < 60 && g < 60 && b < 60) {
        r = (r * 0.85).round();
        g = (g * 0.85).round();
        b = (b * 0.85).round();
      }

      result.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }
    return result;
  }

  /// Stretch histogram to use full tonal range.
  static img.Image autoLevel(img.Image src) {
    int minL = 255, maxL = 0;
    for (final p in src) {
      final l = (p.r + p.g + p.b) / 3;
      if (l < minL) minL = l.toInt();
      if (l > maxL) maxL = l.toInt();
    }

    final range = maxL - minL;
    if (range < 10) return src;

    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      final r = ((p.r - minL) * 255 / range).round().clamp(0, 255);
      final g = ((p.g - minL) * 255 / range).round().clamp(0, 255);
      final b = ((p.b - minL) * 255 / range).round().clamp(0, 255);
      result.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }
    return result;
  }

  /// Adjust contrast and brightness.
  static img.Image adjust(img.Image src, {double contrast = 1.0, double brightness = 0.0}) {
    return img.adjustColor(src, contrast: contrast, brightness: brightness);
  }
}
