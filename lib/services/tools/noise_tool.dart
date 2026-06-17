import 'package:image/image.dart' as img;

/// Tool for reducing noise in scanned document images.
/// Handles sensor noise, compression artifacts, and grain.
class NoiseTool {
  /// Apply gentle noise reduction using a median filter.
  /// Preserves edges while smoothing uniform areas.
  static img.Image reduceNoise(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    const radius = 1;
    const kernelSize = (radius * 2 + 1);
    const totalPixels = kernelSize * kernelSize;

    for (int y = radius; y < src.height - radius; y++) {
      for (int x = radius; x < src.width - radius; x++) {
        // Collect neighborhood values
        final rValues = <int>[];
        final gValues = <int>[];
        final bValues = <int>[];

        for (int ky = -radius; ky <= radius; ky++) {
          for (int kx = -radius; kx <= radius; kx++) {
            final p = src.getPixel(x + kx, y + ky);
            rValues.add(p.r.toInt());
            gValues.add(p.g.toInt());
            bValues.add(p.b.toInt());
          }
        }

        // Use median (more edge-preserving than mean)
        rValues.sort();
        gValues.sort();
        bValues.sort();

        result.setPixelRgba(x, y,
          rValues[totalPixels ~/ 2],
          gValues[totalPixels ~/ 2],
          bValues[totalPixels ~/ 2],
          src.getPixel(x, y).a);
      }
    }

    // Copy border pixels
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

  /// Lightweight denoise — faster but less effective.
  static img.Image quickDenoise(img.Image src) {
    // Simple box blur with small kernel
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (int y = 1; y < src.height - 1; y++) {
      for (int x = 1; x < src.width - 1; x++) {
        int r = 0, g = 0, b = 0;
        int count = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final p = src.getPixel(x + kx, y + ky);
            r += p.r.toInt(); g += p.g.toInt(); b += p.b.toInt();
            count++;
          }
        }
        result.setPixelRgba(x, y, r ~/ count, g ~/ count, b ~/ count, src.getPixel(x, y).a);
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
}
