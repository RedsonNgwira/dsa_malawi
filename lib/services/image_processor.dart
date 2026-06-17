import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'tools/crop_tool.dart';
import 'tools/enhance_tool.dart';
import 'tools/filter_tool.dart';
import 'tools/perspective_tool.dart';
import 'tools/shadow_tool.dart';
import 'tools/noise_tool.dart';
import 'tools/color_tool.dart';

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
  inverted,
  sepia,
  magicColor,
  photocopy,
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

/// Master image processor — orchestrates all image tools.
/// Provides a simple API for common scanning workflows while
/// delegating to specialized tool classes.
class ImageProcessor {
  /// Full auto-enhance pipeline: crop → deskew → whiten → auto-level → sharpen.
  static Future<ProcessedImage> autoEnhance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');

    var result = CropTool.autoCrop(original);
    result = PerspectiveTool.deskew(result);
    result = EnhanceTool.whitenBackground(result);
    result = EnhanceTool.autoLevel(result);
    result = EnhanceTool.adjust(result, contrast: 1.3, brightness: 0.02);
    result = FilterTool.apply(result, 'sharpen');

    final dir = Directory(sourcePath).parent;
    final name = 'processed_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(result, quality: 90);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath, width: result.width, height: result.height, fileSizeBytes: jpeg.length,
    );
  }

  /// Quick processing — crop + contrast + whiten.
  static Future<ProcessedImage> quickEnhance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');

    var result = CropTool.autoCrop(original);
    result = EnhanceTool.adjust(result, contrast: 1.2);
    result = EnhanceTool.whitenBackground(result);

    final dir = Directory(sourcePath).parent;
    final name = 'quick_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(result, quality: 90);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath, width: result.width, height: result.height, fileSizeBytes: jpeg.length,
    );
  }

  /// Apply a named filter preset.
  static Future<ProcessedImage> applyFilter(String sourcePath, FilterPreset preset) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');

    img.Image processed;
    switch (preset) {
      case FilterPreset.original:
        processed = original; break;
      case FilterPreset.grayscale:
        processed = FilterTool.apply(original, 'grayscale'); break;
      case FilterPreset.blackAndWhite:
        processed = FilterTool.apply(original, 'blackAndWhite'); break;
      case FilterPreset.highContrast:
        processed = FilterTool.apply(original, 'highContrast'); break;
      case FilterPreset.enhanced:
        processed = FilterTool.apply(original, 'enhanced'); break;
      case FilterPreset.autoLevel:
        processed = FilterTool.apply(original, 'autoLevel'); break;
      case FilterPreset.sharpen:
        processed = FilterTool.apply(original, 'sharpen'); break;
      case FilterPreset.lightweight:
        var r = CropTool.autoCrop(original);
        processed = EnhanceTool.adjust(r, contrast: 1.15); break;
      case FilterPreset.inverted:
        processed = FilterTool.apply(original, 'inverted'); break;
      case FilterPreset.sepia:
        processed = FilterTool.apply(original, 'sepia'); break;
      case FilterPreset.magicColor:
        processed = FilterTool.apply(original, 'magicColor'); break;
      case FilterPreset.photocopy:
        processed = FilterTool.apply(original, 'photocopy'); break;
    }

    final dir = Directory(sourcePath).parent;
    final name = 'filter_${preset.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(processed, quality: 92);
    await File(outPath).writeAsBytes(jpeg);

    return ProcessedImage(
      outputPath: outPath, width: processed.width, height: processed.height, fileSizeBytes: jpeg.length,
    );
  }

  /// Compress image to reduce file size.
  static Future<ProcessedImage> compressImage(String sourcePath, {int quality = 70, int minWidth = 1920, int minHeight = 1080}) async {
    final outPath = sourcePath.replaceAll('.jpg', '_compressed.jpg');
    final result = await FlutterImageCompress.compressAndGetFile(sourcePath, outPath, quality: quality, minWidth: minWidth, minHeight: minHeight);
    if (result == null) throw Exception('Image compression failed');
    final bytes = await File(result.path).readAsBytes();
    final decoded = img.decodeImage(bytes);
    return ProcessedImage(outputPath: result.path, width: decoded?.width ?? 0, height: decoded?.height ?? 0, fileSizeBytes: bytes.length);
  }

  /// Rotate image by 90-degree increments.
  static Future<ProcessedImage> rotateImage(String sourcePath, int degrees) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');
    final rotated = switch (degrees % 360) { 90 => img.copyRotate(original, angle: 90), 180 => img.copyRotate(original, angle: 180), 270 => img.copyRotate(original, angle: 270), _ => original };
    final dir = Directory(sourcePath).parent;
    final name = 'rotated_${degrees}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(rotated, quality: 92);
    await File(outPath).writeAsBytes(jpeg);
    return ProcessedImage(outputPath: outPath, width: rotated.width, height: rotated.height, fileSizeBytes: jpeg.length);
  }

  // ── Advanced tools (direct access) ──

  /// Remove shadows from a scanned image.
  static Future<ProcessedImage> removeShadows(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');
    final result = ShadowTool.removeShadows(original);
    final dir = Directory(sourcePath).parent;
    final name = 'no_shadow_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(result, quality: 92);
    await File(outPath).writeAsBytes(jpeg);
    return ProcessedImage(outputPath: outPath, width: result.width, height: result.height, fileSizeBytes: jpeg.length);
  }

  /// Reduce noise in a scanned image.
  static Future<ProcessedImage> denoise(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');
    final result = NoiseTool.reduceNoise(original);
    final dir = Directory(sourcePath).parent;
    final name = 'denoised_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(result, quality: 92);
    await File(outPath).writeAsBytes(jpeg);
    return ProcessedImage(outputPath: outPath, width: result.width, height: result.height, fileSizeBytes: jpeg.length);
  }

  /// Auto white balance correction.
  static Future<ProcessedImage> correctWhiteBalance(String sourcePath) async {
    final original = img.decodeImage(await File(sourcePath).readAsBytes());
    if (original == null) throw Exception('Failed to decode image: $sourcePath');
    final result = ColorTool.autoWhiteBalance(original);
    final dir = Directory(sourcePath).parent;
    final name = 'wb_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final outPath = '${dir.path}/$name';
    final jpeg = img.encodeJpg(result, quality: 92);
    await File(outPath).writeAsBytes(jpeg);
    return ProcessedImage(outputPath: outPath, width: result.width, height: result.height, fileSizeBytes: jpeg.length);
  }
}
