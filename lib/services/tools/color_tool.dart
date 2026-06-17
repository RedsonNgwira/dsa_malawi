import 'package:image/image.dart' as img;

/// Tool for color correction and enhancement.
/// Handles auto white balance, color boost, and magic color (CamScanner-style).
class ColorTool {
  /// Auto white balance — corrects color cast from different lighting.
  /// Uses gray world assumption: average of all pixels should be gray.
  static img.Image autoWhiteBalance(img.Image src) {
    double sumR = 0, sumG = 0, sumB = 0;
    int count = 0;

    // Sample pixels for color cast
    for (int y = 0; y < src.height; y += 10) {
      for (int x = 0; x < src.width; x += 10) {
        final p = src.getPixel(x, y);
        sumR += p.r; sumG += p.g; sumB += p.b;
        count++;
      }
    }

    if (count == 0) return src;

    final avgR = sumR / count;
    final avgG = sumG / count;
    final avgB = sumB / count;
    final avgAll = (avgR + avgG + avgB) / 3;

    // Compute gain per channel
    final gainR = avgAll / (avgR + 0.001);
    final gainG = avgAll / (avgG + 0.001);
    final gainB = avgAll / (avgB + 0.001);

    // Clamp gains to prevent extreme shifts
    final clampedR = gainR.clamp(0.5, 2.0);
    final clampedG = gainG.clamp(0.5, 2.0);
    final clampedB = gainB.clamp(0.5, 2.0);

    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      result.setPixelRgba(p.x, p.y,
        (p.r * clampedR).round().clamp(0, 255),
        (p.g * clampedG).round().clamp(0, 255),
        (p.b * clampedB).round().clamp(0, 255),
        p.a);
    }
    return result;
  }

  /// Magic Color — CamScanner-style color enhancement.
  /// Boosts saturation, contrast, and vibrance for a professional scan look.
  static img.Image magicColor(img.Image src) {
    // Step 1: Get white balance right
    var result = autoWhiteBalance(src);
    // Step 2: Boost contrast slightly
    result = img.adjustColor(result, contrast: 1.3);
    // Step 3: Boost saturation (simulated via channel emphasis)
    for (final p in result) {
      final r = p.r; final g = p.g; final b = p.b;
      final maxC = [r, g, b].reduce((a, b) => a > b ? a : b);
      final minC = [r, g, b].reduce((a, b) => a < b ? a : b);
      final saturation = maxC - minC;
      if (saturation < 30) {
        // Low saturation — boost gently
        final boost = 1.3;
        final nr = (r + (r - (r + g + b) / 3) * (boost - 1)).round().clamp(0, 255);
        final ng = (g + (g - (r + g + b) / 3) * (boost - 1)).round().clamp(0, 255);
        final nb = (b + (b - (r + g + b) / 3) * (boost - 1)).round().clamp(0, 255);
        result.setPixelRgba(p.x, p.y, nr, ng, nb, p.a);
      }
    }
    return result;
  }

  /// Boost color vibrance — enhances existing colors without over-saturating.
  static img.Image boostVibrance(img.Image src, {double amount = 0.3}) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      final maxC = [p.r, p.g, p.b].reduce((a, b) => a > b ? a : b).toDouble();
      final avg = (p.r + p.g + p.b) / 3;
      // More boost for highly saturated pixels
      final factor = 1.0 + amount * (maxC - avg) / 255;
      result.setPixelRgba(p.x, p.y,
        (p.r * factor).round().clamp(0, 255),
        (p.g * factor).round().clamp(0, 255),
        (p.b * factor).round().clamp(0, 255),
        p.a);
    }
    return result;
  }
}
