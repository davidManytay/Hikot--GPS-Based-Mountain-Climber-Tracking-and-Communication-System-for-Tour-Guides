import 'dart:async';
import 'package:flutter/foundation.dart';

import 'dart:convert';
import 'dart:collection';
import 'package:flutter_nearby_connections/flutter_nearby_connections.dart';
import '../core/mesh_constants.dart';
import '../models/gps_packet.dart';
import 'packet_scheduler.dart';

class MeshRelayService {
  static final MeshRelayService _instance = MeshRelayService._internal();
  factory MeshRelayService() => _instance;
  MeshRelayService._internal();

  final HashSet<String> _seenIds = HashSet<String>();
  final StreamController<GpsPacket> _incomingController = StreamController<GpsPacket>.broadcast();
  NearbyService? _nearbyService;
  PacketScheduler? _scheduler;
  
  StreamSubscription? _subscription;
  StreamSubscription? _dataSubscription;
  List<Device> _connectedDevices = [];

  int get meshNeighborCount => _connectedDevices.length;

  bool get isMeshRadioActive => _nearbyService != null;

  Stream<GpsPacket> get incomingPackets => _incomingController.stream;

  void updateScheduler(PacketScheduler scheduler) {
    _scheduler = scheduler;
  }

  Future<void> init() async {
    try {
      _nearbyService = NearbyService();
      
      // Attempt to initialize native services
      // Using a try block specifically for native initialization to catch hardware-related crashes
      try {
        await _nearbyService!.init(
          serviceType: 'hikot-mesh',
          strategy: Strategy.P2P_CLUSTER,
          callback: (event) {
            debugPrint("Mesh Connection Event: $event");
          },
        ).timeout(const Duration(seconds: 3), onTimeout: () {
          throw TimeoutException("Bluetooth hardware initialization timed out");
        });
      } catch (nativeError) {
        debugPrint("NATIVE MESH ERROR: $nativeError. Falling back to simulation mode.");
        _nearbyService = null; // Mark as unavailable
        return; 
      }

      if (_nearbyService == null) return;

      _subscription = _nearbyService!.stateChangedSubscription(callback: (devicesList) {
        _connectedDevices = devicesList.where((d) => d.state == SessionState.connected).toList();
        
        for (var device in devicesList) {
          if (device.state == SessionState.notConnected) {
            try {
              _nearbyService!.invitePeer(
                deviceID: device.deviceId,
                deviceName: device.deviceName,
              );
            } catch (e) {
              debugPrint("Invite error: $e");
            }
          }
        }
      });

      _dataSubscription = _nearbyService!.dataReceivedSubscription(callback: (data) {
        _handleRawData(data['message']);
      });

      await _nearbyService!.startAdvertisingPeer();
      await _nearbyService!.startBrowsingForPeers();
    } catch (e) {
      // Graceful fallback for emulators or missing hardware
      debugPrint("MESH HARDWARE ERROR: $e. Running in Virtual Simulation Mode.");
    }
  }

  void _handleRawData(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson) as Map<String, dynamic>;
      final packet = GpsPacket.fromJson(data);

      if (_seenIds.contains(packet.uuid)) return;

      // TTL / hop limit: drop expired packets (flooding mesh with dedupe by UUID).
      if (packet.hopCount > MeshConstants.maxHops) {
        debugPrint('Mesh: dropped packet ${packet.uuid} (hop ${packet.hopCount} > max ${MeshConstants.maxHops})');
        return;
      }

      _seenIds.add(packet.uuid);
      _incomingController.add(packet);

      final int nextHop = packet.hopCount + 1;
      if (nextHop > MeshConstants.maxHops) {
        debugPrint('Mesh: accept but do not relay ${packet.uuid} (next hop would exceed TTL)');
        return;
      }

      final relayPayload = Map<String, dynamic>.from(data);
      relayPayload['hop_count'] = nextHop;
      _relayPacket(jsonEncode(relayPayload));
    } catch (e) {
      debugPrint('Error parsing mesh packet: $e');
    }
  }

  void _relayPacket(String message) {
    if (_nearbyService == null) return;
    for (var device in _connectedDevices) {
      _nearbyService!.sendMessage(device.deviceId, message);
    }
  }

  void broadcastPacket(GpsPacket packet) {
    // SOS: immediate local handle + relay (bypasses any pacing queue on senders).
    if (packet.type == PacketType.sos) {
      _handleRawData(jsonEncode(packet.toJson()));
      return;
    }

    _handleRawData(jsonEncode(packet.toJson()));
  }

  void dispose() {
    _subscription?.cancel();
    _dataSubscription?.cancel();
    _nearbyService?.stopAdvertisingPeer();
    _nearbyService?.stopBrowsingForPeers();
    _incomingController.close();
  }
}
