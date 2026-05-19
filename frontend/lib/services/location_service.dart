import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _cachedPosition;
  static DateTime? _cacheTime;

  /// Get the current GPS position. Asks for permission if needed.
  static Future<Position?> getCurrentLocation({bool forceFresh = false}) async {
    // Return cached position if fresh (< 30 seconds old) and not forcing fresh
    if (!forceFresh && _cachedPosition != null && _cacheTime != null) {
      final age = DateTime.now().difference(_cacheTime!);
      if (age.inSeconds < 30) return _cachedPosition;
    }

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) return last;
      } catch (_) {}
      return null;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    // ── STEP 1: Try Fresh High Accuracy GPS Coordinate First ──
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _cachedPosition = position;
      _cacheTime = DateTime.now();
      return position;
    } catch (e) {
      // ── STEP 2: Fallback to Last Known Position ──
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (last != null) {
          _cachedPosition = last;
          _cacheTime = DateTime.now();
          return last;
        }
      } catch (_) {}

      // ── STEP 3: Fallback to Low Accuracy ──
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 4),
          ),
        );
        _cachedPosition = position;
        _cacheTime = DateTime.now();
        return position;
      } catch (_) {}
      return null;
    }
  }

  /// Stream of location updates for live tracking
  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Format distance nicely
  static String formatDistance(double km) {
    if (km < 1.0) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }

  /// Karachi center fallback coordinates
  static const double defaultLat = 24.8607;
  static const double defaultLng = 67.0099;
}
