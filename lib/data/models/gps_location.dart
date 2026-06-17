/// GPS location data model.
class GpsLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const GpsLocation({
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

  factory GpsLocation.fromMap(Map<String, dynamic> map) => GpsLocation(
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    accuracy: (map['accuracy'] as num).toDouble(),
    timestamp: DateTime.parse(map['timestamp'] as String),
  );
}
