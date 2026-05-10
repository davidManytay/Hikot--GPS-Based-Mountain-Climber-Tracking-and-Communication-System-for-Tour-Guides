import 'dart:async';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/hiker.dart';
import '../models/detection.dart';
import 'geofence_service.dart';
import 'geo_service.dart';
import 'settings_service.dart';
import 'package:vibration/vibration.dart';

class DetectorService {
  final _detectionController = StreamController<Detection>.broadcast();
  final Map<String, List<Detection>> _activeDetections = {};
  final Map<String, DateTime> _lastMovement = {};
  final Map<String, LatLng> _lastPositions = {};
  
  final SettingsService _settings = SettingsService();

  Stream<Detection> get detectionStream => _detectionController.stream;
  Map<String, List<Detection>> get activeDetections => _activeDetections;

  void checkHiker(Hiker hiker, double guideLat, double guideLon, List<LatLng> trailBoundary) {
    final newDetections = <Detection>[];

    // 1. Off-Trail Detection
    bool isInside = GeofenceService.isInsideTrail(hiker.lastLat, hiker.lastLon, trailBoundary);
    if (!isInside) {
      newDetections.add(Detection(
        hikerId: hiker.deviceId,
        hikerName: hiker.name,
        type: DetectionType.offTrail,
        message: "${hiker.name} is outside the designated trail!",
        timestamp: DateTime.now(),
      ));
    }

    // 2. Proximity Detection
    double distance = GeoService.haversineDistance(guideLat, guideLon, hiker.lastLat, hiker.lastLon);
    if (distance > _settings.proximityThresholdMeters) {
      newDetections.add(Detection(
        hikerId: hiker.deviceId,
        hikerName: hiker.name,
        type: DetectionType.proximityAlert,
        message: "${hiker.name} is too far (${distance.toStringAsFixed(0)}m)!",
        timestamp: DateTime.now(),
      ));
    }

    // 3. Battery Detection
    if (hiker.batteryLevel <= _settings.batteryWarningThreshold) {
      newDetections.add(Detection(
        hikerId: hiker.deviceId,
        hikerName: hiker.name,
        type: DetectionType.lowBattery,
        message: "${hiker.name}'s battery is at ${hiker.batteryLevel}%",
        timestamp: DateTime.now(),
      ));
    }

    // 4. SOS Detection
    if (hiker.status == HikerStatus.sos) {
      newDetections.add(Detection(
        hikerId: hiker.deviceId,
        hikerName: hiker.name,
        type: DetectionType.sos,
        message: "SOS signal received from ${hiker.name}!",
        timestamp: DateTime.now(),
      ));
      
      // Trigger Vibrate + Flash (Vibration part)
      Vibration.hasVibrator().then((hasVibrator) {
        if (hasVibrator == true) {
          Vibration.vibrate(pattern: [500, 1000, 500, 1000], intensities: [1, 255]);
        }
      });
    }

    // 5. Immobility Detection
    _updateMovementTracking(hiker);
    if (_isImmobile(hiker.deviceId)) {
      newDetections.add(Detection(
        hikerId: hiker.deviceId,
        hikerName: hiker.name,
        type: DetectionType.stationary,
        message: "${hiker.name} has been stationary for over ${_settings.immobilityThresholdMinutes} mins",
        timestamp: DateTime.now(),
      ));
    }

    // Only notify if detections have changed (simple check for now)
    final oldDetections = _activeDetections[hiker.deviceId] ?? [];
    if (newDetections.length != oldDetections.length || 
        newDetections.any((nd) => !oldDetections.any((od) => od.type == nd.type))) {
      _activeDetections[hiker.deviceId] = newDetections;
      for (var d in newDetections) {
        _detectionController.add(d);
      }
    }
  }

  void _updateMovementTracking(Hiker hiker) {
    final currentPos = LatLng(hiker.lastLat, hiker.lastLon);
    if (!_lastPositions.containsKey(hiker.deviceId)) {
      _lastPositions[hiker.deviceId] = currentPos;
      _lastMovement[hiker.deviceId] = DateTime.now();
      return;
    }

    double dist = GeoService.haversineDistance(
      _lastPositions[hiker.deviceId]!.latitude,
      _lastPositions[hiker.deviceId]!.longitude,
      currentPos.latitude,
      currentPos.longitude,
    );

    // If moved more than 5 meters, update last movement
    if (dist > 5.0) {
      _lastPositions[hiker.deviceId] = currentPos;
      _lastMovement[hiker.deviceId] = DateTime.now();
    }
  }

  bool _isImmobile(String hikerId) {
    if (!_lastMovement.containsKey(hikerId)) return false;
    final duration = DateTime.now().difference(_lastMovement[hikerId]!);
    return duration.inMinutes >= _settings.immobilityThresholdMinutes;
  }

  void clearDetections(String hikerId) {
    _activeDetections.remove(hikerId);
  }

  void dispose() {
    _detectionController.close();
  }
}
