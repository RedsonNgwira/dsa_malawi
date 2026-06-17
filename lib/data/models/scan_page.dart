import '../models/gps_location.dart';
import '../../services/image_processor.dart';

/// Model representing a scanned document page.
class ScanPage {
  final String path;
  final String rawPath;
  final FilterPreset filter;
  final GpsLocation? gps;

  const ScanPage({
    required this.path,
    required this.rawPath,
    required this.filter,
    this.gps,
  });

  bool get hasGps => gps != null;

  String get locationLabel => gps != null
      ? '${gps!.latitude.toStringAsFixed(4)}, ${gps!.longitude.toStringAsFixed(4)}'
      : '';
}
