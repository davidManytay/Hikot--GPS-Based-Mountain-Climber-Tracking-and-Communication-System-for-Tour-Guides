import 'dart:async';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'hiker_list_screen.dart';
import 'settings_screen.dart';
import 'trip_log_screen.dart';
import 'hardware_specs_screen.dart';
import 'climber_node_screen.dart';
import '../models/device_role.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../models/trip.dart';
import '../models/hiker.dart';
import '../services/mesh_relay_service.dart';
import '../services/packet_scheduler.dart';
import '../theme/app_theme.dart';
import '../widgets/tactical_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _db = DatabaseHelper();
  final SettingsService _settings = SettingsService();
  final MeshRelayService _relay = MeshRelayService();
  StreamSubscription? _meshSubscription;

  Trip? _currentTrip;
  int _activeHikers = 0;
  int _totalHikers = 0;
  int _maxHops = 0;
  List<Hiker> _hikerList = [];

  @override
  void initState() {
    super.initState();
    if (_settings.deviceRole != HikotDeviceRole.guideHub) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClimberNodeScreen()),
        );
      });
      return;
    }
    _loadData();
    
    // Listen for mesh packets to update dashboard live
    _meshSubscription = _relay.incomingPackets.listen((packet) {
      _loadData();
    });
  }

  @override
  void dispose() {
    _meshSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    final trip = await _db.getCurrentTrip();
    var hikers = await _db.getHikers();
    
    int activeCount = hikers.where((h) => h.status != HikerStatus.noSignal).length;
    int highestHop = 0;
    for (var h in hikers) {
      if (h.hopCount > highestHop) highestHop = h.hopCount;
    }

    if (mounted) {
      setState(() {
        _currentTrip = trip;
        _hikerList = hikers;
        _totalHikers = hikers.length;
        _activeHikers = activeCount;
        _maxHops = highestHop;
      });
    }
  }

  Future<void> _startNewTrip() async {
    final nameController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: Theme.of(context).cardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.05))),
          title: const Text('INITIALIZE MISSION', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Enter expedition objective or trail sector name:', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'e.g. Mount Apo Summit',
                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: TextStyle(color: HikotColors.textSecondary))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await _db.startTrip(nameController.text);
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadData();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: HikotColors.accentTeal,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('DEPLOY', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HikotColors.darkBackground,
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // No background glow for matte look
          
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildDashboardHeader(),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _buildMissionSummaryGrid(),
                      const SizedBox(height: 24),
                      _buildMapPreview(),
                      const SizedBox(height: 24),
                      _buildSystemHealthSection(),
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionSummaryGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: _buildTacticalStatCard('TOTAL CLIMBERS', '$_activeHikers/$_totalHikers', Icons.group_outlined, HikotColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, 20 * (1 - value)),
                    child: _buildTacticalStatCard('PEAK HOPS', '$_maxHops', Icons.lan_outlined, HikotColors.accent),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusBanner(),
        const SizedBox(height: 12),
        _buildMeshGapBanner(),
      ],
    );
  }

  Widget _buildTacticalStatCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: HikotTextStyles.label),
              Icon(icon, color: accent.withOpacity(0.5), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: HikotTextStyles.tacticalValue),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    bool hasSOS = _hikerList.any((h) => h.status == HikerStatus.sos);
    Color color = hasSOS ? HikotColors.error : HikotColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(hasSOS ? Icons.report_problem_rounded : Icons.shield_outlined, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasSOS ? 'Emergency: SOS received — check map and alerts.' : 'All registered nodes reporting within heartbeat window.',
              style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700, height: 1.25),
            ),
          ),
          if (hasSOS) _buildStatusOrb(HikerStatus.sos),
        ],
      ),
    );
  }

  /// Mesh gap heuristic: offline nodes or very deep hop chains suggest relay risk.
  Widget _buildMeshGapBanner() {
    if (_totalHikers < 2) return const SizedBox.shrink();
    final offline = _hikerList.where((h) => h.status == HikerStatus.noSignal).length;
    final deepChain = _maxHops >= 8;
    if (offline == 0 && !deepChain) return const SizedBox.shrink();

    final msg = offline > 0
        ? '$offline climber(s) offline or out of mesh range. Shorten distance or add a relay node.'
        : 'Hop depth is high ($_maxHops). Consider repositioning relay devices to keep the chain shorter.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: HikotColors.warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HikotColors.warning.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.hub_outlined, color: HikotColors.warning, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                color: HikotColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NETWORK LOG'),
        const SizedBox(height: 16),
        ..._hikerList.map((h) => _buildNodeHealthRow(h)).toList(),
      ],
    );
  }

  Widget _buildNodeHealthRow(Hiker h) {
    bool isSOS = h.status == HikerStatus.sos;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isSOS ? HikotColors.error.withOpacity(0.05) : HikotColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSOS ? HikotColors.error.withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
      ),
      child: Row(
        children: [
          _buildStatusOrb(h.status),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.4)),
                const SizedBox(height: 4),
                Text(
                  '${h.deviceType == DeviceType.hikerNode ? 'Node' : 'Phone'} · ${h.hopCount} hops · signal ${h.signalStrength}%',
                  style: HikotTextStyles.meta,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${h.batteryLevel}%', style: TextStyle(color: _getBatteryColor(h.batteryLevel), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _buildBatteryBar(h.batteryLevel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBatteryBar(int level) {
    Color color = _getBatteryColor(level);
    return Container(
      width: 24,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: level / 100,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 70) return HikotColors.success;
    if (level > 30) return HikotColors.warning;
    return HikotColors.error;
  }

  Widget _buildStatusOrb(HikerStatus status) {
    Color color = switch(status) {
      HikerStatus.sos => HikotColors.error,
      HikerStatus.warning => HikotColors.warning,
      HikerStatus.noSignal => HikotColors.muted,
      _ => HikotColors.success,
    };
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: HikotTextStyles.label);
  }

  Widget _buildDashboardHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left: Title & Mission
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 3, height: 24, color: HikotColors.accentTeal),
                      const SizedBox(width: 12),
                      const Text('Mission Control', style: HikotTextStyles.h1),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.only(left: 15),
                    child: Text(
                      _currentTrip?.name ?? 'No active expedition',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Right: Status & Actions
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildStatusBadge(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HardwareSpecsScreen())),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: HikotColors.accentTeal.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HikotColors.accentTeal.withOpacity(0.2)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.developer_board_outlined, color: HikotColors.accentTeal, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'DEVICE SPECS',
                          style: TextStyle(
                            color: HikotColors.accentTeal,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    bool isActive = _currentTrip != null;
    final accent = isActive ? HikotColors.success : HikotColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8, height: 8, 
            decoration: BoxDecoration(
              shape: BoxShape.circle, 
              color: accent,
              boxShadow: [
                BoxShadow(color: accent.withOpacity(0.5), blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(isActive ? 'MESH ACTIVE' : 'STANDBY', style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildMapPreview() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())).then((_) => _loadData()),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CustomPaint(
                size: Size.infinite,
                painter: _MiniRadarPainter(_hikerList),
              ),
            ),
            Positioned(
              top: 16, left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Offline trail map (Philippines)',
                  style: TextStyle(color: HikotColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return TacticalNavigationBar(
      currentIndex: 0,
      items: [
        TacticalNavItem(
          icon: Icons.grid_view_rounded,
          label: 'HUB',
          onTap: () {},
        ),
        TacticalNavItem(
          icon: Icons.group_outlined,
          label: 'CLIMBERS',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HikerListScreen())).then((_) => _loadData());
          },
        ),
        TacticalNavItem(
          icon: Icons.radar_outlined,
          label: 'MAP',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())).then((_) => _loadData());
          },
        ),
        TacticalNavItem(
          icon: Icons.settings_outlined,
          label: 'SETUP',
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen())).then((_) => _loadData());
          },
        ),
      ],
    );
  }


  Widget _buildMutedGlow(Color color) {
    return Container(
      width: 400,
      height: 400,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
        ),
      ),
    );
  }
}

class _MiniRadarPainter extends CustomPainter {
  final List<Hiker> hikers;
  _MiniRadarPainter(this.hikers);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.45;
    final baseY = center.dy + radius;
    final startX = center.dx - radius;
    final endX = center.dx + radius;

    // 0. Draw Mini Mountain Hill
    final hillPath = Path();
    hillPath.moveTo(startX, baseY);
    // Simplified 3-peak form for mini view
    hillPath.quadraticBezierTo(startX + radius * 0.4, baseY - radius * 0.8, center.dx - radius * 0.3, baseY - radius * 0.3); // Left
    hillPath.quadraticBezierTo(center.dx, center.dy - radius * 0.3, center.dx + radius * 0.3, baseY - radius * 0.3); // Center
    hillPath.quadraticBezierTo(endX - radius * 0.4, baseY - radius * 0.8, endX, baseY); // Right
    
    final hillPaint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.fill;
    canvas.drawPath(hillPath, hillPaint);

    // 1. Static Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, (radius / 3) * i, gridPaint);
    }
    
    // 2. Guide Hub
    final guidePos = Offset(center.dx, center.dy - radius * 0.15);
    canvas.drawCircle(guidePos, 3, Paint()..color = HikotColors.success);

    // 3. Hiker Nodes
    final sortedHikers = List<Hiker>.from(hikers)
      ..sort((a, b) => a.hopCount.compareTo(b.hopCount));

    const double miniVerticalSpacing = 14.0;
    final miniStartY = guidePos.dy + 15;

    for (int i = 0; i < sortedHikers.length; i++) {
      final hiker = sortedHikers[i];
      if (hiker.status == HikerStatus.noSignal) continue;
      
      final isLeft = (i % 2 == 0);
      final xOffset = (isLeft ? -1 : 1) * 10.0; 
      final yPos = miniStartY + (i * miniVerticalSpacing);
      final hikerPos = Offset(center.dx + xOffset, yPos);
      
      if (hikerPos.dy < center.dy + radius) {
        final color = hiker.status == HikerStatus.sos ? HikotColors.error : HikotColors.primary;
        canvas.drawCircle(hikerPos, 2.5, Paint()..color = color);
        canvas.drawCircle(hikerPos, 5, Paint()..color = color.withOpacity(0.15)..style = PaintingStyle.stroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}


