import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Available filter presets for scanned document images.
enum FilterPreset {
  original,
  grayscale,
  blackAndWhite,
  highContrast,
  enhanced,
  autoLevel,
  sharpen,
  lightweight,
}

/// Result of a processing operation.
class ProcessedImage {
  final String outputPath;
  final int width;
  final int height;
  final int fileSizeBytes;

  ProcessedImage({
    required this.outputPath,
    required this.width,
    required this.height,
    required this.fileSizeBytes,
  });
}

/// Advanced image processing for document scanning.
/// Provides auto-crop, perspective correction, deskew, filters, and compression.
class ImageProcessor {
  /// Full auto-enhance pipeline: crop → deskew → whiten → auto-level → sharpen → contrast.
  /// Produces clean "scanner app" quality output optimized for documents.
  static Future<ProcessedImage> autoEnhance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) {
      throw Exception('Failed to decode image: $sourcePath');
    }

    // Step 1: Auto-crop by detecting content bounds
    img.Image result = _autoCrop(original);

    // Step 2: Deskew — detect and correct rotation
    result = _deskew(result);

    // Step 3: Background whitening — make near-white → pure white
    result = _whitenBackground(result);

    // Step 4: Auto-level — histogram stretch for full tonal range
    result = _autoLevel(result);

    // Step 5: Stronger perceptive contrast for text readability
    result = img.adjustColor(result, contrast: 1.3, brightness: 0.02);

    // Step 6: Subtle sharpen for crisp text edges
    result = _sharpen(result);

    // Step 7: Save with high quality
    final dir = Directory(sourcePath).parent;
    final name = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';

    final jpeg = img.encodeJpg(result, quality: 90);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: result.width,
      height: result.height,
      fileSizeBytes: jpeg.length,
    );
  }

  /// Lightweight version — faster, less processing.
  static Future<ProcessedImage> quickEnhance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) {
      throw Exception('Failed to decode image: $sourcePath');
    }

    // Just auto-crop + slight contrast
    final cropped = _autoCrop(original);
    final enhanced = img.adjustColor(cropped, contrast: 1.2);

    final dir = Directory(sourcePath).parent;
    final name = 'quick_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';

    final jpeg = img.encodeJpg(enhanced, quality: 90);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: enhanced.width,
      height: enhanced.height,
      fileSizeBytes: jpeg.length,
    );
  }

  /// Apply a specific filter preset.
  static Future<ProcessedImage> applyFilter(
    String sourcePath,
    FilterPreset preset,
  ) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) {
      throw Exception('Failed to decode image: $sourcePath');
    }

    img.Image processed;
    switch (preset) {
      case FilterPreset.original:
        processed = original;
        break;
      case FilterPreset.grayscale:
        processed = img.grayscale(original);
        break;
      case FilterPreset.blackAndWhite:
        processed = _binaryThreshold(original, 128);
        break;
      case FilterPreset.highContrast:
        processed = img.adjustColor(original, contrast: 2.0, brightness: 0.05);
        break;
      case FilterPreset.enhanced:
        processed = img.adjustColor(original, contrast: 1.3, brightness: 0.03);
        break;
      case FilterPreset.autoLevel:
        processed = _autoLevel(original);
        break;
      case FilterPreset.sharpen:
        processed = _sharpen(original);
        break;
      case FilterPreset.lightweight:
        final cropped = _autoCrop(original);
        processed = img.adjustColor(cropped, contrast: 1.15);
        break;
    }

    final dir = Directory(sourcePath).parent;
    final name = 'filter_${preset.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';

    final jpeg = img.encodeJpg(processed, quality: 92);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: processed.width,
      height: processed.height,
      fileSizeBytes: jpeg.length,
    );
  }

  // ── Deskew: Detect and correct image rotation ──

  /// Detect the dominant angle of text lines and rotate to correct.
  static img.Image _deskew(img.Image src) {
    final gray = img.grayscale(src);
    final w = gray.width;
    final h = gray.height;

    // Sample a grid of edge points and find dominant angle
    const sampleStep = 20;
    final angles = <double>[];

    for (int y = sampleStep; y < h - sampleStep; y += sampleStep) {
      for (int x = sampleStep; x < w - sampleStep; x += sampleStep) {
        if (_isEdgeFast(gray, x, y)) {
          // Check small neighborhood for angle
          double bestAngle = 0;
          double bestScore = 0;
          for (int a = -15; a <= 15; a += 1) {
            final rad = a * pi / 180;
            final dx = (cos(rad) * 10).round();
            final dy = (sin(rad) * 10).round();
            if (_isEdgeFast(gray, x + dx, y + dy)) {
              final score = _edgeStrength(gray, x + dx, y + dy);
              if (score > bestScore) {
                bestScore = score;
                bestAngle = a.toDouble();
              }
            }
          }
          if (bestScore > 30) {
            angles.add(bestAngle);
          }
        }
      }
    }

    if (angles.isEmpty) return src;

    // Use median angle
    angles.sort();
    final medianAngle = angles[angles.length ~/ 2];

    // Only rotate if angle is significant (more than 1.5 degrees)
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

  // ── Background Whitening ──

  /// Convert near-white pixels to pure white for a clean scanned look.
  /// Also boosts text contrast by darkening near-black pixels.
  static img.Image _whitenBackground(img.Image src) {
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      int r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      // If pixel is light/white-ish, push to pure white
      if (r > 200 && g > 200 && b > 200) {
        // Smooth transition to white
        final brightness = (r + g + b) / 3;
        if (brightness > 230) {
          r = 255; g = 255; b = 255;
        } else {
          // Gentle push toward white
          final factor = (brightness - 200) / 55;
          r = (r + (255 - r) * factor).round().clamp(0, 255);
          g = (g + (255 - g) * factor).round().clamp(0, 255);
          b = (b + (255 - b) * factor).round().clamp(0, 255);
        }
      }

      // Darken near-black pixels slightly for stronger text
      if (r < 60 && g < 60 && b < 60) {
        r = (r * 0.85).round();
        g = (g * 0.85).round();
        b = (b * 0.85).round();
      }

      result.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }
    return result;
  }

  // ── Auto-Level: Histogram stretch ──

  /// Stretch the histogram to use full tonal range.
  static img.Image _autoLevel(img.Image src) {
    final gray = img.grayscale(src);
    // Find min/max luminance
    int minL = 255, maxL = 0;
    for (final p in gray) {
      final l = p.luminance.toInt();
      if (l < minL) minL = l;
      if (l > maxL) maxL = l;
    }

    final range = maxL - minL;
    if (range < 10) return src; // Already flat

    // Stretch
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    for (final p in src) {
      final r = ((p.r - minL) * 255 / range).round().clamp(0, 255);
      final g = ((p.g - minL) * 255 / range).round().clamp(0, 255);
      final b = ((p.b - minL) * 255 / range).round().clamp(0, 255);
      result.setPixelRgba(p.x, p.y, r, g, b, p.a);
    }

    return result;
  }

  // ── Sharpen: Unsharp mask ──

  /// Apply unsharp mask sharpening.
  static img.Image _sharpen(img.Image src) {
    // Simple convolution-based sharpen
    final result = img.Image(width: src.width, height: src.height, numChannels: src.numChannels);
    const kernel = [
      [0, -1, 0],
      [-1, 5, -1],
      [0, -1, 0],
    ];

    for (int y = 1; y < src.height - 1; y++) {
      for (int x = 1; x < src.width - 1; x++) {
            double r = 0, g = 0, b = 0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final p = src.getPixel(x + kx, y + ky);
            final k = kernel[ky + 1][kx + 1];
            r += p.r * k;
            g += p.g * k;
            b += p.b * k;
          }
        }
        result.setPixelRgba(x, y,
          r.clamp(0, 255), g.clamp(0, 255), b.clamp(0, 255),
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

  // ── Auto-crop ──

  /// Auto-crop by detecting non-white content region with edge detection.
  static img.Image _autoCrop(img.Image source) {
    final gray = img.grayscale(source);
    final w = gray.width;
    final h = gray.height;

    int top = 0, bottom = h - 1, left = 0, right = w - 1;
    const edgeThreshold = 30;

    // Find top edge
    for (int y = 0; y < h; y++) {
      bool hasEdge = false;
      for (int x = 0; x < w; x += 3) {
        if (_isEdgePixel(gray, x, y, w, edgeThreshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) { top = y; break; }
    }

    // Find bottom edge
    for (int y = h - 1; y > top; y--) {
      bool hasEdge = false;
      for (int x = 0; x < w; x += 3) {
        if (_isEdgePixel(gray, x, y, w, edgeThreshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) { bottom = y; break; }
    }

    // Find left edge
    for (int x = 0; x < w; x++) {
      bool hasEdge = false;
      for (int y = top; y <= bottom; y += 3) {
        if (_isEdgePixel(gray, x, y, w, edgeThreshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) { left = x; break; }
    }

    // Find right edge
    for (int x = w - 1; x > left; x--) {
      bool hasEdge = false;
      for (int y = top; y <= bottom; y += 3) {
        if (_isEdgePixel(gray, x, y, w, edgeThreshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) { right = x; break; }
    }

    // Add margin
    const margin = 5;
    top = max(0, top - margin);
    left = max(0, left - margin);
    bottom = min(h - 1, bottom + margin);
    right = min(w - 1, right + margin);

    // If crop is too aggressive, return original
    if (right - left < w * 0.3 || bottom - top < h * 0.3) {
      return source;
    }

    return img.copyCrop(source, x: left, y: top, width: right - left, height: bottom - top);
  }

  // ── Helpers ──

  static bool _isEdgePixel(img.Image gray, int x, int y, int w, int threshold) {
    if (x <= 1 || x >= w - 2 || y <= 1 || y >= gray.height - 2) return false;
    final c = gray.getPixel(x, y).luminance;
    final r = gray.getPixel(x + 1, y).luminance;
    final l = gray.getPixel(x - 1, y).luminance;
    final d = gray.getPixel(x, y + 1).luminance;
    final u = gray.getPixel(x, y - 1).luminance;
    return (c - r).abs() > threshold ||
        (c - l).abs() > threshold ||
        (c - d).abs() > threshold ||
        (c - u).abs() > threshold;
  }

  static img.Image _binaryThreshold(img.Image src, int threshold) {
    final gray = img.grayscale(src);
    final result = img.Image(width: gray.width, height: gray.height, numChannels: 3);
    for (var y = 0; y < gray.height; y++) {
      for (var x = 0; x < gray.width; x++) {
        final l = gray.getPixel(x, y).luminance;
        if (l > threshold) {
          result.setPixelRgba(x, y, 255, 255, 255, 255);
        } else {
          result.setPixelRgba(x, y, 0, 0, 0, 255);
        }
      }
    }
    return result;
  }

  // ── External API: compress, rotate ──

  static Future<ProcessedImage> compressImage(
    String sourcePath, {
    int quality = 70,
    int minWidth = 1920,
    int minHeight = 1080,
  }) async {
    final outPath = sourcePath.replaceAll('.jpg', '_compressed.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath, outPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    );
    if (result == null) throw Exception('Image compression failed');
    final file = File(result.path);
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    return ProcessedImage(
      outputPath: result.path,
      width: decoded?.width ?? 0,
      height: decoded?.height ?? 0,
      fileSizeBytes: bytes.length,
    );
  }

  static Future<ProcessedImage> rotateImage(String sourcePath, int degrees) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');

    img.Image rotated;
    switch (degrees % 360) {
      case 90:  rotated = img.copyRotate(original, angle: 90); break;
      case 180: rotated = img.copyRotate(original, angle: 180); break;
      case 270: rotated = img.copyRotate(original, angle: 270); break;
      default:  rotated = original;
    }

    final dir = Directory(sourcePath).parent;
    final name = 'rotated_${degrees}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(rotated, quality: 92);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: rotated.width, height: rotated.height,
      fileSizeBytes: jpeg.length,
    );
  }
}
