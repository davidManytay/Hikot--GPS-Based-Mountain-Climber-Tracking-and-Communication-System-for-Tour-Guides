enum HikerStatus { active, warning, noSignal, sos, missing }
enum DeviceType { smartphone, hikerNode }

class Hiker {
  final int? id;
  final String name;
  final String deviceId;
  final double lastLat;
  final double lastLon;
  final DateTime lastSeen;
  final HikerStatus status;
  final int batteryLevel;
  final int signalStrength;
  final int hopCount;
  final DeviceType deviceType;


  Hiker({
    this.id,
    required this.name,
    required this.deviceId,
    this.lastLat = 0.0,
    this.lastLon = 0.0,
    DateTime? lastSeen,
    this.status = HikerStatus.noSignal,
    this.batteryLevel = 100,
    this.signalStrength = 0,
    this.hopCount = 0,
    this.deviceType = DeviceType.hikerNode,
  }) : lastSeen = lastSeen ?? DateTime.now();

  Hiker copyWith({
    int? id,
    String? name,
    String? deviceId,
    double? lastLat,
    double? lastLon,
    DateTime? lastSeen,
    HikerStatus? status,
    int? batteryLevel,
    int? signalStrength,
    int? hopCount,
    DeviceType? deviceType,
  }) {
    return Hiker(
      id: id ?? this.id,
      name: name ?? this.name,
      deviceId: deviceId ?? this.deviceId,
      lastLat: lastLat ?? this.lastLat,
      lastLon: lastLon ?? this.lastLon,
      lastSeen: lastSeen ?? this.lastSeen,
      status: status ?? this.status,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      signalStrength: signalStrength ?? this.signalStrength,
      hopCount: hopCount ?? this.hopCount,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'device_id': deviceId,
      'device_type': deviceType.index,
    };
  }

  factory Hiker.fromMap(Map<String, dynamic> map) {
    return Hiker(
      id: map['id'],
      name: map['name'],
      deviceId: map['device_id'],
      deviceType: map['device_type'] != null ? DeviceType.values[map['device_type']] : DeviceType.hikerNode,
      lastSeen: DateTime.now(),
    );
  }
}
