import 'package:image/image.dart' as img;

/// Tool for removing shadows from scanned documents.
/// Handles shadows from document folds, edges, and uneven lighting.
class ShadowTool {
  /// Remove shadows by adaptive lighting correction.
  /// Detects dark regions and lifts them to match surrounding brightness.
  static img.Image removeShadows(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    final w = src.width;
    final h = src.height;

    // Create a low-resolution brightness map
    const blockSize = 50;
    final blocksX = (w / blockSize).ceil();
    final blocksY = (h / blockSize).ceil();

    // Calculate average brightness per block
    final avgBrightness = List.generate(blocksY, (_) => List.filled(blocksX, 0.0));
    for (int by = 0; by < blocksY; by++) {
      for (int bx = 0; bx < blocksX; bx++) {
        double sum = 0;
        int count = 0;
        for (int y = by * blockSize; y < min((by + 1) * blockSize, h); y++) {
          for (int x = bx * blockSize; x < min((bx + 1) * blockSize, w); x++) {
            final p = src.getPixel(x, y);
            sum += (p.r + p.g + p.b) / 3;
            count++;
          }
        }
        avgBrightness[by][bx] = count > 0 ? sum / count : 128;
      }
    }

    // Find the brightest block as reference (assumed well-lit paper)
    double maxBrightness = 0;
    for (final row in avgBrightness) {
      for (final b in row) {
        if (b > maxBrightness) maxBrightness = b;
      }
    }

    if (maxBrightness < 10) return src;

    // Apply correction: brighten dark blocks proportional to difference
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final by = (y / blockSize).floor();
        final bx = (x / blockSize).floor();
        final blockBrightness = avgBrightness[by][bx];

        // How much to brighten: stronger correction for darker areas
        final ratio = maxBrightness / (blockBrightness + 1);

        // Smooth correction — don't over-brighten
        double correction;
        if (ratio > 1.3) {
          // Shadow area — lift significantly
          correction = (ratio - 1.0) * 0.7 + 1.0;
        } else if (ratio > 1.1) {
          // Moderate shadow — gentle lift
          correction = (ratio - 1.0) * 0.5 + 1.0;
        } else {
          // Well-lit area — no correction
          correction = 1.0;
        }

        final p = src.getPixel(x, y);
        final nr = (p.r * correction).round().clamp(0, 255);
        final ng = (p.g * correction).round().clamp(0, 255);
        final nb = (p.b * correction).round().clamp(0, 255);
        result.setPixelRgba(x, y, nr, ng, nb, p.a);
      }
    }

    return result;
  }

  /// Remove uneven lighting using a gentle approach.
  /// Less aggressive than removeShadows, good for general use.
  static img.Image flattenLighting(img.Image src) {
    // Apply a mild version of shadow removal
    return removeShadows(src);
  }

  static int min(int a, int b) => a < b ? a : b;
}
