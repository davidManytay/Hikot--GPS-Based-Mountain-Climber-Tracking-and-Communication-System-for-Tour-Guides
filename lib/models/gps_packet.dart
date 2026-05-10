import 'dart:convert';

enum PacketType { gps, heartbeat, sos }

class GpsPacket {
  final String uuid;
  final String hikerId;
  final double lat;
  final double lon;
  final int timestamp;
  final PacketType type;
  final int batteryLevel; // 0-100
  final int signalStrength; // 0-100
  final int hopCount;

  GpsPacket({
    required this.uuid,
    required this.hikerId,
    required this.lat,
    required this.lon,
    required this.timestamp,
    required this.type,
    this.batteryLevel = 100,
    this.signalStrength = 100,
    this.hopCount = 1,
  });

  factory GpsPacket.fromJson(Map<String, dynamic> json) {
    return GpsPacket(
      uuid: json['uuid'] as String,
      hikerId: json['hiker_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      type: _parseType(json['type'] as String),
      batteryLevel: json['battery'] as int? ?? 100,
      signalStrength: json['signal'] as int? ?? 100,
      hopCount: json['hop_count'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'hiker_id': hikerId,
      'lat': lat,
      'lon': lon,
      'timestamp': timestamp,
      'type': type.name,
      'battery': batteryLevel,
      'signal': signalStrength,
      'hop_count': hopCount,
    };
  }

  static PacketType _parseType(String type) {
    switch (type) {
      case 'sos':
        return PacketType.sos;
      case 'heartbeat':
        return PacketType.heartbeat;
      default:
        return PacketType.gps;
    }
  }

  int get priority {
    switch (type) {
      case PacketType.sos:
        return 0;
      case PacketType.heartbeat:
        return 1;
      case PacketType.gps:
        return 2;
    }
  }

  @override
  String toString() => jsonEncode(toJson());
}
