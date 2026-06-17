import 'package:geolocator/geolocator.dart';

/// Result of a GPS location capture.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  GpsLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });

  String get formatted => '$latitude, $longitude (±${accuracy.toStringAsFixed(1)}m)';

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Service for capturing GPS location when scanning documents.
class GpsService {
  static bool _serviceEnabled = false;
  static LocationPermission? _permission;

  /// Request location permission and enable GPS if possible.
  static Future<bool> ensurePermissions() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!_serviceEnabled) {
      await Geolocator.openLocationSettings();
      _serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    _permission = await Geolocator.checkPermission();
    if (_permission == LocationPermission.denied) {
      _permission = await Geolocator.requestPermission();
    }

    return _permission == LocationPermission.always ||
        _permission == LocationPermission.whileInUse;
  }

  /// Capture the current GPS location.
  /// Returns null if permissions are denied or location is unavailable.
  static Future<GpsLocation?> captureLocation() async {
    try {
      final hasPermission = await ensurePermissions();
      if (!hasPermission) return null;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return GpsLocation(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
        timestamp: pos.timestamp,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get a human-readable location string for document metadata.
  static Future<String> getLocationString() async {
    final loc = await captureLocation();
    if (loc == null) return 'Location unavailable';
    return loc.formatted;
  }
}
