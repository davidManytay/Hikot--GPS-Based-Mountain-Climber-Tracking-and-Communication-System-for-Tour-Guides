import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/device_role.dart';
import '../models/hiker.dart';
import '../models/gps_packet.dart';
import '../services/mesh_relay_service.dart';
import '../services/packet_scheduler.dart';
import '../services/heartbeat_monitor.dart';
import '../services/database_helper.dart';
import '../services/geo_service.dart';
import '../services/geofence_service.dart';
import '../services/settings_service.dart';
import '../services/detector_service.dart';
import '../models/detection.dart';
import '../widgets/detector_list_panel.dart';
import '../theme/app_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MeshRelayService _mesh = MeshRelayService();
  final PacketScheduler _scheduler = PacketScheduler();
  final HeartbeatMonitor _heartbeat = HeartbeatMonitor();
  final DatabaseHelper _db = DatabaseHelper();
  final DetectorService _detector = DetectorService();
  final SettingsService _settings = SettingsService();
  
  Map<String, Hiker> _hikerStates = {};
  Map<String, List<Offset>> _hikerHistory = {};
  List<Detection> _detections = [];
  String? _alertMessage;
  
  final List<Offset> _trailBoundaryOffsets = [
    const Offset(0, 0),
    const Offset(0.2, 0.5),
    const Offset(0.8, 0.6),
    const Offset(0.5, -0.2),
  ];

  @override
  void initState() {
    super.initState();
    if (_settings.deviceRole != HikotDeviceRole.guideHub) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The live group map is only available on the tour guide device.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      });
      return;
    }
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      _mesh.updateScheduler(_scheduler);
      await _mesh.init().catchError((e) => debugPrint("Mesh init error: $e"));
      _heartbeat.start();

      _mesh.incomingPackets.listen((packet) {
        _handlePacket(packet);
      });

      _heartbeat.lostSignalStream.listen((hikerId) {
        _handleLostSignal(hikerId);
      });

      _detector.detectionStream.listen((_) {
        if (mounted) {
          setState(() {
            _detections = List<Detection>.from(
              _detector.activeDetections.values.expand((e) => e)
            );
          });
        }
      });

      final hikers = await _db.getHikers();
      if (mounted) {
        setState(() {
          _hikerStates = { for (var h in hikers) h.deviceId : h };
        });
      }
    } catch (e) {
      debugPrint("Fatal Init Error in MapScreen: $e");
    }
  }

  void _handlePacket(GpsPacket packet) {
    if (!_hikerStates.containsKey(packet.hikerId)) return;
    _heartbeat.updateLastSeen(packet.hikerId);
    final smoothed = GeoService.smoothGPS(packet.hikerId, packet.lat, packet.lon);
    final currentHiker = _hikerStates[packet.hikerId];
    if (currentHiker == null) return;

    final updatedHiker = currentHiker.copyWith(
      lastLat: smoothed[0],
      lastLon: smoothed[1],
      lastSeen: DateTime.now(),
      status: packet.type == PacketType.sos ? HikerStatus.sos : _heartbeat.getStatus(packet.hikerId),
      batteryLevel: packet.batteryLevel,
      signalStrength: packet.signalStrength,
      hopCount: packet.hopCount,
    );

    if (mounted) {
      setState(() {
        _hikerStates[packet.hikerId] = updatedHiker;
        final history = _hikerHistory[packet.hikerId] ?? [];
        history.add(Offset(smoothed[1], smoothed[0]));
        if (history.length > 10) history.removeAt(0);
        _hikerHistory[packet.hikerId] = history;

        _detector.checkHiker(updatedHiker, 7.0700, 125.6100, []);
        
        final sosDetections = _detections.where((d) => d.type == DetectionType.sos).toList();
        if (sosDetections.isNotEmpty) {
          _alertMessage = "EMERGENCY: ${sosDetections.first.message}";
        } else {
          _alertMessage = null;
        }
      });
    }
    _db.logGPS(packet);
  }

  void _handleLostSignal(String hikerId) {
    if (!_hikerStates.containsKey(hikerId)) return;
    if (mounted) {
      setState(() {
        _hikerStates[hikerId] = _hikerStates[hikerId]!.copyWith(status: HikerStatus.noSignal);
        _alertMessage = "SIGNAL LOST: ${_hikerStates[hikerId]!.name}";
      });
    }
  }

  Timer? _defenseTimer;
  int _scenarioStep = 0;

  Future<void> _runDefenseScenario() async {
    List<Hiker> hikers = await _db.getHikers();
    if (hikers.isEmpty) return;

    if (mounted) {
      setState(() {
        _hikerStates = { for (var h in hikers) h.deviceId : h };
        _scenarioStep = 0;
        for (var id in _hikerStates.keys) {
          _triggerDemoPacket(id, 0.000, 0.000, PacketType.gps, 90, 1);
        }
      });
    }

    _defenseTimer?.cancel();
    _defenseTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _hikerStates.isEmpty) {
        timer.cancel();
        return;
      }
      _scenarioStep++;
      final hikerIds = _hikerStates.keys.toList();
      String targetId = hikerIds[_scenarioStep % hikerIds.length];
      
      switch (_scenarioStep % 4) {
        case 0: _triggerDemoPacket(targetId, 0.001, 0.001, PacketType.gps, 85, 1); break;
        case 1: _triggerDemoPacket(targetId, 0.005, 0.006, PacketType.gps, 82, 2); break;
        case 2: _triggerDemoPacket(targetId, 0.002, -0.001, PacketType.gps, 12, 1); break;
        case 3: _triggerDemoPacket(targetId, -0.002, 0.003, PacketType.sos, 45, 3); break;
      }
      if (_scenarioStep > 20) timer.cancel();
    });
  }

  void _triggerDemoPacket(String id, double latOff, double lonOff, PacketType type, int battery, int hops) {
    _handlePacket(GpsPacket(
      uuid: DateTime.now().millisecondsSinceEpoch.toString(),
      hikerId: id,
      lat: 7.0700 + latOff,
      lon: 125.6100 + lonOff,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      batteryLevel: battery,
      signalStrength: 95,
      hopCount: hops,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HikotColors.darkBackground,
      floatingActionButton: FloatingActionButton(
        onPressed: _runDefenseScenario,
        backgroundColor: HikotColors.surfaceLight,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.white.withOpacity(0.1))),
        child: const Icon(Icons.radar, color: Colors.white),
      ),
      body: Stack(
        children: [
          // Tactical Radar View
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: TacticalRadar(
                hikers: _hikerStates.values.toList(),
                guideLat: 7.0700,
                guideLon: 125.6100,
              ),
            ),
          ),
          
          // HUD Overlays
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(context)),
          
          // Bottom Status Panel
          Positioned(
            bottom: 24, left: 24,
            child: _buildHUDCoordPanel("7.0700 N", "125.6100 E"),
          ),

          // SOS Panel
          Positioned(
            top: 100, right: 20, bottom: 100,
            child: SizedBox(
              width: 240,
              child: DetectorListPanel(
                detections: _detections.where((d) => d.type == DetectionType.sos).toList(),
                onDetectionTap: (detection) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: HikotColors.error,
                    content: Text("Emergency Focus: ${detection.hikerName}"),
                  ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 24, right: 24, bottom: 20),
      child: Row(
        children: [
          _buildHUDIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Offline map · Philippines', style: TextStyle(color: HikotColors.accentTeal, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
              const Text('Mount Apo sector (cached)', style: HikotTextStyles.h2),
            ],
          ),
          const Spacer(),
          _buildHUDIconButton(Icons.layers_outlined, () {}),
        ],
      ),
    );
  }

  Widget _buildHUDIconButton(IconData icon, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: HikotColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: IconButton(icon: Icon(icon, color: Colors.white, size: 18), onPressed: onTap),
    );
  }

  Widget _buildHUDCoordPanel(String lat, String lon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        border: Border.all(color: HikotColors.accent.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCoordRow("LAT", lat),
          const SizedBox(height: 4),
          _buildCoordRow("LON", lon),
        ],
      ),
    );
  }

  Widget _buildCoordRow(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(color: HikotColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
      ],
    );
  }

  @override
  void dispose() {
    _mesh.dispose();
    _heartbeat.stop();
    _detector.dispose();
    _defenseTimer?.cancel();
    super.dispose();
  }
}

class TacticalRadar extends StatefulWidget {
  final List<Hiker> hikers;
  final double guideLat;
  final double guideLon;

  const TacticalRadar({
    super.key,
    required this.hikers,
    required this.guideLat,
    required this.guideLon,
  });

  @override
  State<TacticalRadar> createState() => _TacticalRadarState();
}

class _TacticalRadarState extends State<TacticalRadar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _RadarPainter(
            rotation: _controller.value,
            hikers: widget.hikers,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotation;
  final List<Hiker> hikers;

  _RadarPainter({
    required this.rotation,
    required this.hikers,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42; 

    // 1. Draw Static Grid
    final gridPaint = Paint()
      ..color = HikotColors.accent.withOpacity(0.1) 
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (radius / 4) * i, gridPaint);
    }
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // 2. Draw Fine-line Scanning Arc (Matte)
    final scanPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * math.pi);
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: radius),
      0, 0.5, false, scanPaint
    );
    canvas.restore();

    // 3. Draw Guide Hub (Matte)
    final guidePos = Offset(center.dx, center.dy - radius * 0.4);
    canvas.drawCircle(guidePos, 6, Paint()..color = HikotColors.success);
    
    // 4. Draw Hiker Nodes (Matte)
    final sortedHikers = List<Hiker>.from(hikers)..sort((a, b) => a.hopCount.compareTo(b.hopCount));
    const double verticalSpacing = 60.0;
    final startY = guidePos.dy;

    for (int i = 0; i < sortedHikers.length; i++) {
      final hiker = sortedHikers[i];
      final color = hiker.status == HikerStatus.sos ? HikotColors.error : (hiker.status == HikerStatus.warning ? HikotColors.warning : HikotColors.success);
      final isLeft = (i % 2 == 0);
      final xOffset = (isLeft ? -1 : 1) * 40.0; 
      final yPos = startY + (i + 1) * verticalSpacing;
      final hikerPos = Offset(center.dx + xOffset, yPos);
      final prevPos = i == 0 ? guidePos : Offset(center.dx + (i % 2 != 0 ? -40.0 : 40.0), startY + i * verticalSpacing);

      // Connection Line (Muted)
      canvas.drawLine(prevPos, hikerPos, Paint()..color = color.withOpacity(0.2)..strokeWidth = 1.5);

      // Hiker Marker
      canvas.drawCircle(hikerPos, 5, Paint()..color = color);

      // Text Labels (Minimalist)
      final textPainter = TextPainter(
        text: TextSpan(
          text: hiker.name.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(hikerPos.dx + 12, hikerPos.dy - 5));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
