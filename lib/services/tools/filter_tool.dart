import 'dart:math';
import 'package:image/image.dart' as img;

/// Tool for applying filter presets to scanned images.
/// Handles grayscale, black & white, color modes.
/// Now with adaptive thresholding (Otsu + Sauvola) for real scanner-quality output.
class FilterTool {
  /// Apply a named filter preset.
  static img.Image apply(img.Image src, String preset) {
    switch (preset) {
      case 'grayscale':
        return img.grayscale(src);
      case 'blackAndWhite':
        return _adaptiveThresholdSauvola(src);
      case 'highContrast':
        return img.adjustColor(src, contrast: 2.0, brightness: 0.05);
      case 'enhanced':
        return img.adjustColor(src, contrast: 1.3, brightness: 0.03);
      case 'autoLevel':
        return _autoLevel(src);
      case 'sharpen':
        return _sharpen(src);
      case 'inverted':
        return _invert(src);
      case 'sepia':
        return _sepia(src);
      case 'magicColor':
        return _magicColor(src);
      case 'photocopy':
        return _photocopy(src);
      default:
        return src;
    }
  }

  /// Available filter presets with display names.
  static Map<String, String> get presets => {
    'original': 'Original',
    'grayscale': 'Grayscale',
    'blackAndWhite': 'Black & White (Smart)',
    'highContrast': 'High Contrast',
    'enhanced': 'Enhanced',
    'autoLevel': 'Auto Level',
    'sharpen': 'Sharpen',
    'inverted': 'Inverted',
    'sepia': 'Sepia',
    'magicColor': 'Magic Color',
    'photocopy': 'Photocopy',
  };

  static Map<String, String> get presetIcons => {
    'original': 'image',
    'grayscale': 'blur_on',
    'blackAndWhite': 'brightness_2',
    'highContrast': 'contrast',
    'enhanced': 'auto_fix_high',
    'autoLevel': 'exposure',
    'sharpen': 'blur_on',
    'inverted': 'invert_colors',
    'sepia': 'color_lens',
    'magicColor': 'auto_awesome',
    'photocopy': 'content_copy',
  };

  // ── Adaptive Thresholding ──

  /// Sauvola's adaptive threshold: per-pixel local neighborhood analysis.
  /// This is what makes text look crisp even on uneven lighting.
  static img.Image _adaptiveThresholdSauvola(img.Image src) {
    final gray = img.grayscale(src);
    const windowSize = 15; // Must be odd
    const halfWindow = windowSize ~/ 2;
    const k = 0.2; // Sauvola parameter
    const r = 128.0; // Dynamic range of standard deviation

    // Compute integral image for fast local mean and std calculation
    final integral = _computeIntegralImage(gray);
    final integralSq = _computeIntegralSquared(gray);

    final result = img.Image(width: gray.width, height: gray.height, numChannels: 3);
    final w = gray.width;
    final h = gray.height;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        // Define local window
        final x1 = max(0, x - halfWindow);
        final y1 = max(0, y - halfWindow);
        final x2 = min(w - 1, x + halfWindow);
        final y2 = min(h - 1, y + halfWindow);
        final n = (x2 - x1 + 1) * (y2 - y1 + 1);

        // Local mean via integral image
        final mean = _integralSum(integral, x1, y1, x2, y2) / n;

        // Local variance via integral squared
        final variance = (_integralSum(integralSq, x1, y1, x2, y2) / n) - (mean * mean);
        final std = sqrt(max(0.0, variance));

        // Sauvola threshold
        final threshold = mean * (1.0 + k * ((std / r) - 1.0));
        final luminance = gray.getPixel(x, y).luminance;

        if (luminance > threshold) {
          result.setPixelRgba(x, y, 255, 255, 255, 255); // White
        } else {
          result.setPixelRgba(x, y, 0, 0, 0, 255); // Black
        }
      }
    }
    return result;
  }

  /// Photocopy mode: Sauvola threshold + pure white background.
  static img.Image _photocopy(img.Image src) {
    var result = _adaptiveThresholdSauvola(src);
    // Ensure pure white background
    for (final p in result) {
      if (p.r > 200) {
        p.setRgba(255, 255, 255, 255);
      }
    }
    return result;
  }

  // ── Integral Image Helpers ──

  static List<List<double>> _computeIntegralImage(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final integral = List.generate(h + 1, (_) => List.filled(w + 1, 0.0));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        integral[y + 1][x + 1] = gray.getPixel(x, y).luminance +
            integral[y][x + 1] + integral[y + 1][x] - integral[y][x];
      }
    }
    return integral;
  }

  static List<List<double>> _computeIntegralSquared(img.Image gray) {
    final w = gray.width;
    final h = gray.height;
    final integral = List.generate(h + 1, (_) => List.filled(w + 1, 0.0));
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final val = gray.getPixel(x, y).luminance;
        integral[y + 1][x + 1] = val * val +
            integral[y][x + 1] + integral[y + 1][x] - integral[y][x];
      }
    }
    return integral;
  }

  static double _integralSum(List<List<double>> integral, int x1, int y1, int x2, int y2) {
    return integral[y2 + 1][x2 + 1] - integral[y1][x2 + 1] - integral[y2 + 1][x1] + integral[y1][x1];
  }

  // ── Legacy filters ──

  static img.Image _autoLevel(img.Image src) {
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
      result.setPixelRgba(p.x, p.y,
        ((p.r - minL) * 255 / range).round().clamp(0, 255),
        ((p.g - minL) * 255 / range).round().clamp(0, 255),
        ((p.b - minL) * 255 / range).round().clamp(0, 255), p.a);
    }
    return result;
  }

  static img.Image _sharpen(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    const kernel = [[0, -1, 0], [-1, 5, -1], [0, -1, 0]];
    for (int y = 1; y < src.height - 1; y++) {
      for (int x = 1; x < src.width - 1; x++) {
        double r = 0, g = 0, b = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final p = src.getPixel(x + kx, y + ky);
            final k = kernel[ky + 1][kx + 1];
            r += p.r * k; g += p.g * k; b += p.b * k;
          }
        }
        result.setPixelRgba(x, y, r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), src.getPixel(x, y).a);
      }
    }
    // Copy border
    for (int x = 0; x < src.width; x++) {
      result.setPixelRgba(x, 0, src.getPixel(x, 0).r, src.getPixel(x, 0).g, src.getPixel(x, 0).b, src.getPixel(x, 0).a);
      result.setPixelRgba(x, src.height - 1, src.getPixel(x, src.height - 1).r, src.getPixel(x, src.height - 1).g, src.getPixel(x, src.height - 1).b, src.getPixel(x, src.height - 1).a);
    }
    for (int y = 0; y < src.height; y++) {
      result.setPixelRgba(0, y, src.getPixel(0, y).r, src.getPixel(0, y).g, src.getPixel(0, y).b, src.getPixel(0, y).a);
      result.setPixelRgba(src.width - 1, y, src.getPixel(src.width - 1, y).r, src.getPixel(src.width - 1, y).g, src.getPixel(src.width - 1, y).b, src.getPixel(src.width - 1, y).a);
    }
    return result;
  }

  static img.Image _invert(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      result.setPixelRgba(p.x, p.y, 255 - p.r, 255 - p.g, 255 - p.b, p.a);
    }
    return result;
  }

  static img.Image _sepia(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      final tr = (0.393 * p.r + 0.769 * p.g + 0.189 * p.b).round();
      final tg = (0.349 * p.r + 0.686 * p.g + 0.168 * p.b).round();
      final tb = (0.272 * p.r + 0.534 * p.g + 0.131 * p.b).round();
      result.setPixelRgba(p.x, p.y, tr.clamp(0, 255), tg.clamp(0, 255), tb.clamp(0, 255), p.a);
    }
    return result;
  }

  static img.Image _magicColor(img.Image src) {
    var result = img.adjustColor(src, contrast: 1.4);
    result = img.adjustColor(result, contrast: 0.9, brightness: 0.02);
    return result;
  }
}
