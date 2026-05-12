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
  double _guideLat = 7.0700;
  double _guideLon = 125.6100;

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

      // Add slight jitter to guide coords to simulate live sensor data
      if (mounted) {
        setState(() {
          _guideLat = 7.0700 + (math.Random().nextDouble() - 0.5) * 0.0002;
          _guideLon = 125.6100 + (math.Random().nextDouble() - 0.5) * 0.0002;
        });
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: _runDefenseScenario,
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
        child: Icon(Icons.radar, color: Theme.of(context).colorScheme.onSurface),
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
                guideLat: _guideLat,
                guideLon: _guideLon,
                isDarkMode: Theme.of(context).brightness == Brightness.dark,
              ),
            ),
          ),
          
          // HUD Overlays
          Positioned(top: 0, left: 0, right: 0, child: _buildTopBar(context)),
          
          // Bottom Status Panel
          Positioned(
            bottom: 24, left: 24,
            child: _buildHUDCoordPanel(
              "${_guideLat.toStringAsFixed(4)} N", 
              "${_guideLon.toStringAsFixed(4)} E"
            ),
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
              Row(
                children: [
                  const Text('Mount Apo sector (cached)', style: HikotTextStyles.h2),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _alertMessage = "Sector deletion requires admin privileges"),
                    child: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), size: 16),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          _buildHUDIconButton(Icons.add, () => setState(() => _alertMessage = "Searching for local offline maps...")),
          const SizedBox(width: 12),
          _buildHUDIconButton(Icons.layers_outlined, () {}),
        ],
      ),
    );
  }

  Widget _buildHUDIconButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          ),
          child: Center(child: Icon(icon, color: Theme.of(context).colorScheme.onSurface, size: 18)),
        ),
      ),
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
        Text(value, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14, fontFamily: 'monospace')),
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
  final bool isDarkMode;

  const TacticalRadar({
    super.key,
    required this.hikers,
    required this.guideLat,
    required this.guideLon,
    this.isDarkMode = true,
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
          size: Size.infinite,
          painter: _RadarPainter(
            rotation: _controller.value,
            hikers: widget.hikers,
            guideLat: widget.guideLat,
            guideLon: widget.guideLon,
            isDarkMode: widget.isDarkMode,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotation;
  final List<Hiker> hikers;
  final double guideLat;
  final double guideLon;
  final bool isDarkMode;

  _RadarPainter({
    required this.rotation,
    required this.hikers,
    required this.guideLat,
    required this.guideLon,
    required this.isDarkMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.42; 
    final baseY = center.dy + radius;
    final startX = -50.0; 
    final endX = size.width + 50.0;

    // 0. Detailed Mountain Silhouette
    final hillPath = Path();
    hillPath.moveTo(startX, baseY);
    
    // Left Hill
    hillPath.lineTo(startX + 40, baseY - 5);
    hillPath.quadraticBezierTo(center.dx - radius * 0.9, baseY - radius * 1.3, center.dx - radius * 0.55, baseY - radius * 0.4);
    // Valley 1
    hillPath.quadraticBezierTo(center.dx - radius * 0.45, baseY - radius * 0.1, center.dx - radius * 0.3, baseY - radius * 0.4);
    // Main Summit
    hillPath.quadraticBezierTo(center.dx - radius * 0.15, center.dy - radius * 0.3, center.dx, center.dy - radius * 0.5); 
    hillPath.quadraticBezierTo(center.dx + radius * 0.2, center.dy - radius * 0.2, center.dx + radius * 0.4, baseY - radius * 0.4);
    // Valley 2
    hillPath.quadraticBezierTo(center.dx + radius * 0.55, baseY - radius * 0.1, center.dx + radius * 0.7, baseY - radius * 0.4);
    // Right Hill
    hillPath.quadraticBezierTo(center.dx + radius * 0.75, baseY - radius * 1.4, endX - 180, baseY - 5);
    hillPath.lineTo(endX, baseY);

    final hillPaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    
    final fillPath = Path.from(hillPath);
    fillPath.lineTo(endX, size.height);
    fillPath.lineTo(startX, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, hillPaint);

    final guidePos = Offset(center.dx, center.dy - radius * 0.5);

    // Calculate hiker positions
    final sortedHikers = List<Hiker>.from(hikers)..sort((a, b) => a.hopCount.compareTo(b.hopCount));
    final hikerPositions = <Offset>[];
    
    const double verticalSpacing = 45.0;
    final startY = guidePos.dy;

    for (int i = 0; i < sortedHikers.length; i++) {
      final isLeft = (i % 2 == 0);
      final xOffset = (isLeft ? -1 : 1) * 40.0; 
      final yPos = startY + (i + 1) * verticalSpacing;
      hikerPositions.add(Offset(center.dx + xOffset, yPos));
    }

    // 1. Static Grid Lines
    final gridPaint = Paint()
      ..color = isDarkMode ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (radius / 4) * i, gridPaint);
    }
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // 2. Scanning Arc
    final scanPaint = Paint()
      ..color = HikotColors.accentTeal.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * math.pi);
    
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        colors: [HikotColors.accentTeal.withOpacity(0.2), Colors.transparent],
        stops: const [0.1, 0.4],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius));
    
    canvas.drawCircle(Offset.zero, radius, sweepPaint);
    canvas.drawLine(Offset.zero, Offset(radius, 0), scanPaint);
    canvas.restore();

    // 3. Guide Hub
    canvas.drawCircle(guidePos, 6, Paint()..color = HikotColors.success);
    
    final guideTextPainter = TextPainter(
      text: const TextSpan(
        text: 'TOUR GUIDE',
        style: TextStyle(color: HikotColors.success, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.0)
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    guideTextPainter.paint(canvas, Offset(guidePos.dx + 12, guidePos.dy - 6));
    
    // 4. Hiker Nodes
    for (int i = 0; i < sortedHikers.length; i++) {
      final hiker = sortedHikers[i];
      final hikerPos = hikerPositions[i];
      final color = hiker.status == HikerStatus.sos ? HikotColors.error : (hiker.status == HikerStatus.warning ? HikotColors.warning : HikotColors.success);
      final prevPos = i == 0 ? guidePos : hikerPositions[i - 1];

      canvas.drawLine(prevPos, hikerPos, Paint()..color = color.withOpacity(0.2)..strokeWidth = 1.5);

      final blink = (math.sin(rotation * 2 * math.pi * 4) + 1) / 2;
      final markerOpacity = 0.5 + (0.5 * blink);
      
      canvas.drawCircle(hikerPos, 8, Paint()..color = color.withOpacity(0.2 * markerOpacity));
      canvas.drawCircle(hikerPos, 5, Paint()..color = color.withOpacity(markerOpacity));

      final textPainter = TextPainter(
        text: TextSpan(
          text: hiker.name.toUpperCase(),
          style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(markerOpacity) : Colors.black.withOpacity(markerOpacity), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(hikerPos.dx + 12, hikerPos.dy - 5));
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

