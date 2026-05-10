enum DetectionType { offTrail, stationary, lowBattery, proximityAlert, sos }

class Detection {
  final String hikerId;
  final String hikerName;
  final DetectionType type;
  final String message;
  final DateTime timestamp;

  Detection({
    required this.hikerId,
    required this.hikerName,
    required this.type,
    required this.message,
    required this.timestamp,
  });

  String get typeLabel {
    switch (type) {
      case DetectionType.offTrail: return 'OFF-TRAIL';
      case DetectionType.stationary: return 'STATIONARY';
      case DetectionType.lowBattery: return 'LOW BATTERY';
      case DetectionType.proximityAlert: return 'PROXIMITY';
      case DetectionType.sos: return 'SOS';
    }
  }
}
