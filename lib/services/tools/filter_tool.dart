import 'package:image/image.dart' as img;

/// Tool for applying filter presets to scanned images.
/// Handles grayscale, black & white, color modes.
class FilterTool {
  /// Apply a named filter preset.
  static img.Image apply(img.Image src, String preset) {
    switch (preset) {
      case 'grayscale':
        return img.grayscale(src);
      case 'blackAndWhite':
        return _binaryThreshold(src, 128);
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
      default:
        return src;
    }
  }

  /// Available filter presets with display names.
  static Map<String, String> get presets => {
    'original': 'Original',
    'grayscale': 'Grayscale',
    'blackAndWhite': 'Black & White',
    'highContrast': 'High Contrast',
    'enhanced': 'Enhanced',
    'autoLevel': 'Auto Level',
    'sharpen': 'Sharpen',
    'inverted': 'Inverted',
    'sepia': 'Sepia',
    'magicColor': 'Magic Color',
  };

  /// Available filter icons.
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
  };

  // ── Internal filter implementations ──

  static img.Image _binaryThreshold(img.Image src, int threshold) {
    final gray = img.grayscale(src);
    final result = img.Image(width: gray.width, height: gray.height, numChannels: 3);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final l = gray.getPixel(x, y).luminance;
        result.setPixelRgba(x, y, l > threshold ? 255 : 0, l > threshold ? 255 : 0, l > threshold ? 255 : 0, 255);
      }
    }
    return result;
  }

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
    // CamScanner-style magic color: boost saturation + contrast
    var result = img.adjustColor(src, contrast: 1.4);
    // Slight saturation boost by emphasizing color channels
    result = img.adjustColor(result, contrast: 0.9, brightness: 0.02);
    return result;
  }
}
