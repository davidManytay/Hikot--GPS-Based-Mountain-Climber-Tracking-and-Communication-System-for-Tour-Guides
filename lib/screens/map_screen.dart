import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;
import '../models/hiker.dart';
import '../models/gps_packet.dart';
import '../services/mesh_relay_service.dart';
import '../services/packet_scheduler.dart';
import '../services/heartbeat_monitor.dart';
import '../services/database_helper.dart';
import '../services/geo_service.dart';
import '../services/geofence_service.dart';
import '../widgets/dashboard_panel.dart';
import '../widgets/alert_banner.dart';
import '../widgets/hiker_marker.dart';
import '../services/detector_service.dart';
import '../models/detection.dart';
import '../widgets/detector_list_panel.dart';

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
  
  Map<String, Hiker> _hikerStates = {};
  Map<String, List<Offset>> _hikerHistory = {}; // Stores last 10 positions for breadcrumbs
  List<Detection> _detections = [];
  String? _alertMessage;
  
  // Hardcoded trail for demonstration (e.g., Mount Apo area)
  final List<Offset> _trailBoundaryOffsets = [
    const Offset(0, 0),
    const Offset(0.2, 0.5),
    const Offset(0.8, 0.6),
    const Offset(0.5, -0.2),
  ];

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    try {
      _mesh.updateScheduler(_scheduler);
      // Initialize mesh with error handling to prevent crash on emulators
      await _mesh.init().catchError((e) => print("Mesh init error: $e"));
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
            // Safe copy to avoid concurrent modification crashes
            _detections = List<Detection>.from(
              _detector.activeDetections.values.expand((e) => e)
            );
          });
        }
      });

      // Load registered hikers
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
    // Safety check: ensure hiker exists in our local state
    if (!_hikerStates.containsKey(packet.hikerId)) return;

    _heartbeat.updateLastSeen(packet.hikerId);
    
    // Smooth GPS using Kalman Filter
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

        // Update history for breadcrumbs
        final history = _hikerHistory[packet.hikerId] ?? [];
        history.add(Offset(smoothed[1], smoothed[0])); // Store Lon, Lat
        if (history.length > 10) history.removeAt(0);
        _hikerHistory[packet.hikerId] = history;

        // Use the new DetectorService
        _detector.checkHiker(
          updatedHiker, 
          7.0700, // Dummy guide lat
          125.6100, // Dummy guide lon
          [] // No trail boundary for now as requested "remove off trail"
        );
        
        // Update alert message based on detections (SOS only)
        final sosDetections = _detections.where((d) => d.type == DetectionType.sos).toList();
        if (sosDetections.isNotEmpty) {
          final topAlert = sosDetections.first;
          _alertMessage = "EMERGENCY: ${topAlert.message}";
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
        _hikerStates[hikerId] = _hikerStates[hikerId]!.copyWith(
          status: HikerStatus.noSignal,
        );
        _alertMessage = "SIGNAL LOST: ${_hikerStates[hikerId]!.name}";
      });
    }
  }

  Timer? _defenseTimer;
  int _scenarioStep = 0;

  Future<void> _runDefenseScenario() async {
    // 1. Load your actual registered hikers from the database
    List<Hiker> hikers = await _db.getHikers();
    
    // If you haven't registered any hikers yet, add a demo one so the radar isn't empty
    if (hikers.isEmpty) {
      final demo = Hiker(name: "Demo Hiker", deviceId: "demo-hiker", lastLat: 7.0700, lastLon: 125.6100);
      await _db.insertHiker(demo);
      hikers = await _db.getHikers();
    }

    if (mounted) {
      setState(() {
        _hikerStates = { for (var h in hikers) h.deviceId : h };
        _scenarioStep = 0;
        
        // Give every hiker a starting position so they appear on the radar immediately
        for (var id in _hikerStates.keys) {
          _triggerDemoPacket(id, 0.000, 0.000, PacketType.gps, 90, 1);
        }
      });
    }

    // 2. Start automated sequence using the IDs of your registered hikers
    _defenseTimer?.cancel();
    _defenseTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || _hikerStates.isEmpty) {
        timer.cancel();
        return;
      }

      _scenarioStep++;
      final hikerIds = _hikerStates.keys.toList();
      
      // Assign different simulation paths to your hikers
      String targetId = hikerIds[_scenarioStep % hikerIds.length];
      
      switch (_scenarioStep % 4) {
        case 0: // Normal movement
          _triggerDemoPacket(targetId, 0.001, 0.001, PacketType.gps, 85, 1);
          break;
        case 1: // Off-trail check
          _triggerDemoPacket(targetId, 0.005, 0.006, PacketType.gps, 82, 2);
          break;
        case 2: // Battery check
          _triggerDemoPacket(targetId, 0.002, -0.001, PacketType.gps, 12, 1);
          break;
        case 3: // Emergency check
          _triggerDemoPacket(targetId, -0.002, 0.003, PacketType.sos, 45, 3);
          break;
      }
      
      if (_scenarioStep > 20) timer.cancel();
    });
  }

  void _triggerDemoPacket(String id, double latOff, double lonOff, PacketType type, int battery, int hops) {
    final packet = GpsPacket(
      uuid: DateTime.now().millisecondsSinceEpoch.toString(),
      hikerId: id,
      lat: 7.0700 + latOff,
      lon: 125.6100 + lonOff,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: type,
      batteryLevel: battery,
      signalStrength: 95,
      hopCount: hops,
    );
    _handlePacket(packet);
  }

  Future<void> _simulateHikerSignal() async {
    _runDefenseScenario();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A192F), // Dark Blue instead of Black
      floatingActionButton: FloatingActionButton(
        onPressed: _simulateHikerSignal,
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.radar, color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. Tactical Radar Grid (Force to center)
          Center(
            child: SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: TacticalRadar(
                hikers: _hikerStates.values.toList(),
                history: _hikerHistory,
                trailBoundary: _trailBoundaryOffsets,
                guideLat: 7.0700, // Matching dummy center
                guideLon: 125.6100,
              ),
            ),
          ),
          
          // 2. Minimal Top Bar (Transparent)
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopBar(context),
          ),

          // 3. Vertical Sidebar for SOS Detections (Right Side)
          Positioned(
            top: 100, right: 20, bottom: 100,
            child: SizedBox(
              width: 240,
              child: DetectorListPanel(
                detections: _detections.where((d) => d.type == DetectionType.sos).toList(),
                onDetectionTap: (detection) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: Colors.redAccent,
                      content: Text("Emergency Focus: ${detection.hikerName}"),
                      duration: const Duration(seconds: 2),
                    ),
                  );
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
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20, right: 20, bottom: 20,
      ),
      child: Row(
        children: [
          _buildGlassIconButton(Icons.arrow_back_ios_new, () => Navigator.pop(context)),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('MISSION CONTROL', style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 2)),
              Text('Mount Apo Sector', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const Spacer(),
          _buildGlassIconButton(Icons.layers_outlined, () {}),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton(IconData icon, VoidCallback onTap) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withOpacity(0.05),
          child: IconButton(icon: Icon(icon, color: Colors.white, size: 18), onPressed: onTap),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mesh.dispose();
    _heartbeat.stop();
    _detector.dispose();
    super.dispose();
  }
}

class TacticalRadar extends StatefulWidget {
  final List<Hiker> hikers;
  final Map<String, List<Offset>> history;
  final List<Offset> trailBoundary;
  final double guideLat;
  final double guideLon;

  const TacticalRadar({
    super.key,
    required this.hikers,
    required this.history,
    required this.trailBoundary,
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
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
            history: widget.history,
            trailBoundary: widget.trailBoundary,
            guideLat: widget.guideLat,
            guideLon: widget.guideLon,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double rotation;
  final List<Hiker> hikers;
  final Map<String, List<Offset>> history;
  final List<Offset> trailBoundary;
  final double guideLat;
  final double guideLon;

  _RadarPainter({
    required this.rotation,
    required this.hikers,
    required this.history,
    required this.trailBoundary,
    required this.guideLat,
    required this.guideLon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.8;

    final gridPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4) // Brighter for testing
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw concentric circles
    for (var i = 1; i <= 4; i++) {
      canvas.drawCircle(center, (radius / 4) * i, gridPaint);
    }

    // Draw crosshair lines
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), gridPaint);

    // 1. Draw Rotating Scanning Beam
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation * 2 * 3.14159);
    final beamRect = Rect.fromCircle(center: Offset.zero, radius: radius);
    final beamPaint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.blueAccent.withOpacity(0.0),
          Colors.blueAccent.withOpacity(0.3),
        ],
        stops: const [0.85, 1.0],
      ).createShader(beamRect);
    canvas.drawCircle(Offset.zero, radius, beamPaint);
    canvas.restore();

    // 2. Draw Strict Vertical Trail Line
    final pathPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    // Vertical line extending from guide downwards
    canvas.drawLine(center, Offset(center.dx, center.dy + radius), pathPaint);

    // 3. Draw Guide Hub (Receiver) at Center with GLOW
    final guideGlow = Paint()
      ..color = Colors.teal.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(center, 20, guideGlow);

    final guidePaint = Paint()..color = Colors.teal;
    canvas.drawCircle(center, 10, guidePaint);
    canvas.drawCircle(center, 15, guidePaint..style = PaintingStyle.stroke..strokeWidth = 2);
    
    final guideText = TextPainter(
      text: const TextSpan(text: "GUIDE HUB", style: TextStyle(color: Colors.teal, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
      textDirection: TextDirection.ltr,
    )..layout();
    guideText.paint(canvas, Offset(center.dx - 35, center.dy - 35));



    // Draw Hiker points and trails in a STABLE chain
    // 1. Sort hikers by Hop Count (Topological order)
    final sortedHikers = List<Hiker>.from(hikers)
      ..sort((a, b) => a.hopCount.compareTo(b.hopCount));

    for (int i = 0; i < sortedHikers.length; i++) {
      final hiker = sortedHikers[i];
      final isSOS = hiker.status == HikerStatus.sos;
      final isWarn = hiker.status == HikerStatus.warning;
      final color = isSOS ? Colors.red : (isWarn ? Colors.orangeAccent : Colors.teal);
      
      // Calculate stable vertical position based on rank (i)
      // Each hiker is 90px below the previous node
      final hikerPos = Offset(center.dx, center.dy + (i + 1) * 90.0);

      // Draw Solid + Dotted connecting line from previous node (Guide or previous hiker)
      final prevPos = i == 0 ? center : Offset(center.dx, center.dy + i * 90.0);
      
      // 1. Solid Connection Line (Main Path)
      canvas.drawLine(
        prevPos, 
        hikerPos, 
        Paint()..color = Colors.blueAccent.withOpacity(0.3)..strokeWidth = 3..style = PaintingStyle.stroke
      );

      // 2. Curved Dotted Secondary Line (Mesh Path)
      final dashPaint = Paint()
        ..color = Colors.white.withOpacity(0.2)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      
      final curvePath = Path();
      final start = Offset(center.dx, prevPos.dy + 12);
      final end = Offset(center.dx, hikerPos.dy - 12);
      
      // Control point for the curve (offset to the left)
      final controlX = center.dx - 25;
      final controlY = (start.dy + end.dy) / 2;
      
      curvePath.moveTo(start.dx, start.dy);
      curvePath.quadraticBezierTo(controlX, controlY, end.dx, end.dy);

      // Animated dashing along the curve (Pulse)
      final metrics = curvePath.computeMetrics();
      for (final metric in metrics) {
        // Use 'rotation' to offset the dashes for a flowing animation
        double distance = (1.0 - rotation) * 10.0; 
        const dashLength = 4.0;
        const dashSpace = 4.0;
        while (distance < metric.length) {
          final extract = metric.extractPath(distance, distance + dashLength);
          canvas.drawPath(extract, dashPaint);
          distance += dashLength + dashSpace;
        }
      }

      // Draw Hop label between nodes
      final hopLabel = TextPainter(
        text: TextSpan(text: "HOP ${i + 1}", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 8, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr,
      )..layout();
      hopLabel.paint(canvas, Offset(center.dx + 10, (prevPos.dy + hikerPos.dy) / 2 - 4));

      if (_isInBounds(hikerPos, center, radius)) {
        // Draw Signal Range Circle (Pulsing)
        final rangePaint = Paint()
          ..color = color.withOpacity(0.1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        canvas.drawCircle(hikerPos, 45 + (rotation * 5), rangePaint); // Range circle
        canvas.drawCircle(hikerPos, 45, rangePaint..color = color.withOpacity(0.05));
        // 2. Draw Tactical Reticle (Shape based on status) with GLOW
        final glowPaint = Paint()
          ..color = color.withOpacity(0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(hikerPos, 12, glowPaint); // Node Glow

        canvas.save();
        canvas.translate(hikerPos.dx, hikerPos.dy);
        canvas.rotate(rotation * 3.14159);
        final reticlePaint = Paint()
          ..color = color.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        
        if (isSOS) {
          // Diamond for SOS
          final path = Path()
            ..moveTo(0, -10)..lineTo(10, 0)..lineTo(0, 10)..lineTo(-10, 0)..close();
          canvas.drawPath(path, reticlePaint);
        } else if (isWarn) {
          // Triangle for Warning
          final path = Path()
            ..moveTo(0, -10)..lineTo(10, 8)..lineTo(-10, 8)..close();
          canvas.drawPath(path, reticlePaint);
        } else {
          // Square for Normal
          canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 16, height: 16), reticlePaint);
        }
        canvas.restore();

        // 3. Draw HUD Callout (Name + Status Tag)
        final index = hikers.indexOf(hiker);
        final isEven = index % 2 == 0;
        
        // Alternating sides (Left/Right) for readability in strict vertical stack
        final xOffset = isEven ? 28.0 : -100.0; 
        final yOffset = -5.0; 
        
        final labelPos = Offset(hikerPos.dx + xOffset, hikerPos.dy + yOffset);
        final labelEnd = Offset(labelPos.dx + 5, labelPos.dy);

        String statusTag = "";
        if (isSOS) statusTag = " [SOS!!]";
        else if (isWarn) statusTag = " [WARN]";
        else if (hiker.status == HikerStatus.noSignal) statusTag = " [OFFLINE]";

        final textPainter = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(text: hiker.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
              TextSpan(text: statusTag, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
              TextSpan(text: "\nHOP: ${hiker.hopCount}", style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.normal)),
            ],
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        
        // Draw a small "Leader Line" from point to label
        canvas.drawLine(hikerPos, labelPos, Paint()..color = color.withOpacity(0.3)..strokeWidth = 1);
        
        textPainter.paint(canvas, Offset(labelEnd.dx, labelEnd.dy - 10));
        
        // Draw larger hiker dot for better visibility
        canvas.drawCircle(hikerPos, 6, Paint()..color = color..style = PaintingStyle.fill);
        canvas.drawCircle(hikerPos, 8, Paint()..color = color.withOpacity(0.3)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  Offset _getRadarPos(double lon, double lat, Offset center) {
    // Deprecated for topological view, but kept for bounds checking
    return Offset(center.dx, center.dy + 100); 
  }

  bool _isInBounds(Offset pos, Offset center, double radius) {
    return pos.dx > center.dx - radius && pos.dx < center.dx + radius &&
           pos.dy > center.dy - radius && pos.dy < center.dy + radius;
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}
