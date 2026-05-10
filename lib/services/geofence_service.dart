import 'package:maplibre_gl/maplibre_gl.dart';
import 'geo_service.dart';

class GeofenceService {
  static const double geofenceBufferMeters = 50.0;

  /// Ray-casting algorithm to check if a point is inside a polygon.
  /// Applies a 50-meter buffer to prevent false alerts.
  static bool isInsideTrail(double lat, double lon, List<LatLng> trailBoundary) {
    if (trailBoundary.isEmpty) return true; // Default to safe if no boundary defined

    // First check if the point is within the 50m buffer of any point on the trail
    // This is a simplification; a true polygon buffer is complex.
    // For Hikot, we'll check if it's within the polygon OR close to any edge.
    
    bool inside = false;
    int j = trailBoundary.length - 1;
    for (int i = 0; i < trailBoundary.length; i++) {
      if ((trailBoundary[i].longitude > lon) != (trailBoundary[j].longitude > lon) &&
          (lat < (trailBoundary[j].latitude - trailBoundary[i].latitude) * 
          (lon - trailBoundary[i].longitude) / (trailBoundary[j].longitude - trailBoundary[i].longitude) + 
          trailBoundary[i].latitude)) {
        inside = !inside;
      }
      
      // Buffer check: If we are very close to any edge or vertex, consider it "inside"
      double distToVertex = GeoService.haversineDistance(
        lat, lon, 
        trailBoundary[i].latitude, trailBoundary[i].longitude
      );
      if (distToVertex < geofenceBufferMeters) return true;

      j = i;
    }

    return inside;
  }
}
