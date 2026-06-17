import 'dart:io';
import '../../../services/image_processor.dart';
import '../../../services/gps_service.dart';

/// A scanned page with its processing state.
class ScanPageDto {
  final String path;
  final String rawPath;
  final FilterPreset filter;
  final GpsLocation? gps;

  const ScanPageDto({
    required this.path,
    required this.rawPath,
    required this.filter,
    this.gps,
  });

  bool get hasGps => gps != null;

  /// Create a new instance with updated path/filter (after re-processing).
  ScanPageDto copyWith({String? path, String? rawPath, FilterPreset? filter, GpsLocation? gps}) {
    return ScanPageDto(
      path: path ?? this.path,
      rawPath: rawPath ?? this.rawPath,
      filter: filter ?? this.filter,
      gps: gps ?? this.gps,
    );
  }

  /// Delete files associated with this page.
  void deleteFiles() {
    File(path).deleteSync(recursive: true);
    if (rawPath != path) File(rawPath).deleteSync(recursive: true);
  }
}
