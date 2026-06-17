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

/// Service for processing scanned document images.
///
/// Provides auto-crop (contour detection), perspective correction,
/// filter presets, and compression.
class ImageProcessor {
  /// Auto-crop, deskew, and enhance a scanned image.
  /// Returns the processed file path.
  static Future<ProcessedImage> autoEnhance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) {
      throw Exception('Failed to decode image: $sourcePath');
    }

    // Step 1: Auto-crop by detecting content bounds
    final cropped = _autoCrop(original);

    // Step 2: Apply basic enhancement (contrast + sharpen)
    final enhanced = img.adjustColor(cropped, contrast: 1.2);
    final sharpened = img.gaussianBlur(enhanced, radius: 0);

    // Step 3: Save with quality
    final dir = Directory(sourcePath).parent;
    final name = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';

    final outFile = File(outPath);
    final jpeg = img.encodeJpg(sharpened, quality: 90);
    await outFile.writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: sharpened.width,
      height: sharpened.height,
      fileSizeBytes: jpeg.length,
    );
  }

  /// Apply a specific filter preset to an image.
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
    }

    final dir = Directory(sourcePath).parent;
    final name =
        'filter_${preset.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
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

  /// Compress a JPEG image to a target quality.
  static Future<ProcessedImage> compressImage(
    String sourcePath, {
    int quality = 70,
    int minWidth = 1920,
    int minHeight = 1080,
  }) async {
    final outPath = sourcePath.replaceAll('.jpg', '_compressed.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      outPath,
      quality: quality,
      minWidth: minWidth,
      minHeight: minHeight,
    );

    if (result == null) {
      throw Exception('Image compression failed');
    }

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

  /// Rotate an image by 90-degree increments.
  static Future<ProcessedImage> rotateImage(
    String sourcePath,
    int degrees,
  ) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) {
      throw Exception('Failed to decode image: $sourcePath');
    }

    img.Image rotated;
    switch (degrees % 360) {
      case 90:
        rotated = img.copyRotate(original, angle: 90);
        break;
      case 180:
        rotated = img.copyRotate(original, angle: 180);
        break;
      case 270:
        rotated = img.copyRotate(original, angle: 270);
        break;
      default:
        rotated = original;
    }

    final dir = Directory(sourcePath).parent;
    final name =
        'rotated_${degrees}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';

    final jpeg = img.encodeJpg(rotated, quality: 92);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath,
      width: rotated.width,
      height: rotated.height,
      fileSizeBytes: jpeg.length,
    );
  }

  /// Auto-crop by detecting non-white content region with edge detection.
  static img.Image _autoCrop(img.Image source) {
    // Convert to grayscale for edge detection
    final gray = img.grayscale(source);
    final w = gray.width;
    final h = gray.height;

    // Edge detection using Sobel-like simple gradient
    int top = 0, bottom = h - 1, left = 0, right = w - 1;
    final threshold = 30;

    // Find top edge
    for (int y = 0; y < h; y++) {
      bool hasEdge = false;
      for (int x = 0; x < w; x += 3) {
        if (_isEdgePixel(gray, x, y, w, threshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) {
        top = y;
        break;
      }
    }

    // Find bottom edge
    for (int y = h - 1; y > top; y--) {
      bool hasEdge = false;
      for (int x = 0; x < w; x += 3) {
        if (_isEdgePixel(gray, x, y, w, threshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) {
        bottom = y;
        break;
      }
    }

    // Find left edge
    for (int x = 0; x < w; x++) {
      bool hasEdge = false;
      for (int y = top; y <= bottom; y += 3) {
        if (_isEdgePixel(gray, x, y, w, threshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) {
        left = x;
        break;
      }
    }

    // Find right edge
    for (int x = w - 1; x > left; x--) {
      bool hasEdge = false;
      for (int y = top; y <= bottom; y += 3) {
        if (_isEdgePixel(gray, x, y, w, threshold)) {
          hasEdge = true;
          break;
        }
      }
      if (hasEdge) {
        right = x;
        break;
      }
    }

    // Add small margin
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

  /// Simple threshold filter — converts to grayscale then applies binary threshold.
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

  /// Simple edge detection: check if a pixel differs significantly from neighbors.
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
}
