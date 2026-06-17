import 'dart:math';
import 'package:image/image.dart' as img;

class FilterTool {
  static img.Image apply(img.Image src, String preset) {
    switch (preset) {
      case 'grayscale': return img.grayscale(src);
      case 'blackAndWhite': return _sauvolaThreshold(src);
      case 'highContrast': return img.adjustColor(src, contrast: 2.0, brightness: 0.05);
      case 'enhanced': return img.adjustColor(src, contrast: 1.3, brightness: 0.03);
      case 'autoLevel': return _autoLevel(src);
      case 'sharpen': return _sharpen(src);
      case 'inverted': return _invert(src);
      case 'sepia': return _sepia(src);
      case 'magicColor': return _magicColor(src);
      case 'photocopy': return _photocopy(src);
      default: return src;
    }
  }

  static Map<String, String> get presets => {
    'original': 'Original', 'grayscale': 'Grayscale', 'blackAndWhite': 'B&W (Smart)',
    'highContrast': 'High Contrast', 'enhanced': 'Enhanced', 'autoLevel': 'Auto Level',
    'sharpen': 'Sharpen', 'inverted': 'Inverted', 'sepia': 'Sepia',
    'magicColor': 'Magic Color', 'photocopy': 'Photocopy',
  };

  static Map<String, String> get presetIcons => {
    'original': 'image', 'grayscale': 'blur_on', 'blackAndWhite': 'brightness_2',
    'highContrast': 'contrast', 'enhanced': 'auto_fix_high', 'autoLevel': 'exposure',
    'sharpen': 'blur_on', 'inverted': 'invert_colors', 'sepia': 'color_lens',
    'magicColor': 'auto_awesome', 'photocopy': 'content_copy',
  };

  /// Sauvola adaptive threshold — per-pixel local analysis for crisp text.
  static img.Image _sauvolaThreshold(img.Image src) {
    final gray = img.grayscale(src);
    const ws = 15, hw = ws ~/ 2; const k = 0.2; const r = 128.0;
    final integral = _integralSumTable(gray);
    final integralSq = _integralSumTableSq(gray);
    final result = img.Image(width: gray.width, height: gray.height, numChannels: 3);
    final w = gray.width, h = gray.height;
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      final x1 = max(0, x - hw), y1 = max(0, y - hw);
      final x2 = min(w - 1, x + hw), y2 = min(h - 1, y + hw);
      final n = (x2 - x1 + 1) * (y2 - y1 + 1);
      final mean = _sum(integral, x1, y1, x2, y2) / n;
      final var_ = (_sum(integralSq, x1, y1, x2, y2) / n) - mean * mean;
      final std = sqrt(max(0.0, var_));
      final thresh = mean * (1.0 + k * ((std / r) - 1.0));
      if (gray.getPixel(x, y).luminance > thresh) {
        result.setPixelRgba(x, y, 255, 255, 255, 255);
      } else result.setPixelRgba(x, y, 0, 0, 0, 255);
    }
    return result;
  }

  static img.Image _photocopy(img.Image src) {
    var result = _sauvolaThreshold(src);
    for (final p in result) if (p.r > 200) p.setRgba(255, 255, 255, 255);
    return result;
  }

  static List<List<double>> _integralSumTable(img.Image gray) {
    final w = gray.width, h = gray.height;
    final t = List.generate(h + 1, (_) => List.filled(w + 1, 0.0));
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++)
      t[y + 1][x + 1] = gray.getPixel(x, y).luminance + t[y][x + 1] + t[y + 1][x] - t[y][x];
    return t;
  }

  static List<List<double>> _integralSumTableSq(img.Image gray) {
    final w = gray.width, h = gray.height;
    final t = List.generate(h + 1, (_) => List.filled(w + 1, 0.0));
    for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
      final v = gray.getPixel(x, y).luminance;
      t[y + 1][x + 1] = v * v + t[y][x + 1] + t[y + 1][x] - t[y][x];
    }
    return t;
  }

  static double _sum(List<List<double>> t, int x1, int y1, int x2, int y2) =>
    t[y2 + 1][x2 + 1] - t[y1][x2 + 1] - t[y2 + 1][x1] + t[y1][x1];

  static img.Image _autoLevel(img.Image src) {
    int minL = 255, maxL = 0;
    for (final p in src) { final l = (p.r + p.g + p.b) / 3; if (l < minL) minL = l.toInt(); if (l > maxL) maxL = l.toInt(); }
    if (maxL - minL < 10) return src;
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) result.setPixelRgba(p.x, p.y,
      ((p.r - minL) * 255 / (maxL - minL)).round().clamp(0, 255),
      ((p.g - minL) * 255 / (maxL - minL)).round().clamp(0, 255),
      ((p.b - minL) * 255 / (maxL - minL)).round().clamp(0, 255), p.a);
    return result;
  }

  static img.Image _sharpen(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    const kernel = [[0, -1, 0], [-1, 5, -1], [0, -1, 0]];
    for (int y = 1; y < src.height - 1; y++) for (int x = 1; x < src.width - 1; x++) {
      double r = 0, g = 0, b = 0;
      for (int ky = -1; ky <= 1; ky++) for (int kx = -1; kx <= 1; kx++) {
        final p = src.getPixel(x + kx, y + ky); final k = kernel[ky + 1][kx + 1];
        r += p.r * k; g += p.g * k; b += p.b * k;
      }
      result.setPixelRgba(x, y, r.round().clamp(0, 255), g.round().clamp(0, 255), b.round().clamp(0, 255), src.getPixel(x, y).a);
    }
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
    for (final p in src) result.setPixelRgba(p.x, p.y, 255 - p.r, 255 - p.g, 255 - p.b, p.a);
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
    var r = img.adjustColor(src, contrast: 1.4);
    return img.adjustColor(r, contrast: 0.9, brightness: 0.02);
  }
}
