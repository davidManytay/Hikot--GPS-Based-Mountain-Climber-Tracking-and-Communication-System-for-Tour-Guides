import 'dart:math' as math;
import '../models/hiker.dart';

class GeoService {
  static const double earthRadiusMeters = 6371000.0;

  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusMeters * c;
  }

  static double groupSpread(List<Hiker> hikers) {
    if (hikers.length < 2) return 0.0;
    double maxDist = 0.0;
    for (int i = 0; i < hikers.length; i++) {
      for (int j = i + 1; j < hikers.length; j++) {
        double dist = haversineDistance(
          hikers[i].lastLat, hikers[i].lastLon,
          hikers[j].lastLat, hikers[j].lastLon,
        );
        if (dist > maxDist) maxDist = dist;
      }
    }
    return maxDist;
  }

  static double _toRadians(double degree) => degree * math.pi / 180;

  // Kalman Filter State for smoothing
  static final Map<String, _KalmanState> _kalmanStates = {};

  static List<double> smoothGPS(String hikerId, double rawLat, double rawLon) {
    if (!_kalmanStates.containsKey(hikerId)) {
      _kalmanStates[hikerId] = _KalmanState(rawLat, rawLon);
      return [rawLat, rawLon];
    }

    var state = _kalmanStates[hikerId]!;
    state.update(rawLat, rawLon);
    return [state.lat, state.lon];
  }
}

class _KalmanState {
  double lat;
  double lon;
  double variance = 1.0;
  static const double Q = 0.00001; // Process noise
  static const double R = 0.0001;  // Measurement noise

  _KalmanState(this.lat, this.lon);

  void update(double newLat, double newLon) {
    // Prediction step
    variance += Q;

    // Measurement update step
    double k = variance / (variance + R);
    lat += k * (newLat - lat);
    lon += k * (newLon - lon);
    variance = (1 - k) * variance;
  }
}
