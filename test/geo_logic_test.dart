import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:hikot/services/geo_service.dart';
import 'package:hikot/services/geofence_service.dart';

void main() {
  group('GeoService Tests', () {
    test('Haversine distance between two points', () {
      // Near Mount Apo
      double dist = GeoService.haversineDistance(7.0700, 125.6100, 7.0750, 125.6100);
      expect(dist, closeTo(555.9, 1.0)); // Approx 556m
    });
  });

  group('GeofenceService Tests', () {
    final List<LatLng> trail = [
      const LatLng(7.0700, 125.6100),
      const LatLng(7.0750, 125.6100),
      const LatLng(7.0750, 125.6150),
      const LatLng(7.0700, 125.6150),
    ];

    test('Point inside trail', () {
      bool inside = GeofenceService.isInsideTrail(7.0725, 125.6125, trail);
      expect(inside, isTrue);
    });

    test('Point outside trail', () {
      bool inside = GeofenceService.isInsideTrail(7.0800, 125.6200, trail);
      expect(inside, isFalse);
    });

    test('Point near boundary (buffer check)', () {
      // Point just outside 7.0700, 125.6100
      bool inside = GeofenceService.isInsideTrail(7.0699, 125.6100, trail);
      expect(inside, isTrue); // Should be true due to 50m buffer
    });
  });
}
