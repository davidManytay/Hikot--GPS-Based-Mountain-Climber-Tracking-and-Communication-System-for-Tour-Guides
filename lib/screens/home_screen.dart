import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'map_screen.dart';
import 'hiker_list_screen.dart';
import 'settings_screen.dart';
import 'trip_log_screen.dart';
import '../services/database_helper.dart';
import '../services/settings_service.dart';
import '../models/trip.dart';
import '../models/hiker.dart';
import '../services/mesh_relay_service.dart';
import '../services/packet_scheduler.dart';

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
    
    // Auto-seed demo hikers if empty for defense ease
    if (hikers.isEmpty) {
      await _db.insertHiker(Hiker(deviceId: 'hiker_1', name: 'David', lastLat: 7.0700, lastLon: 125.6100, lastSeen: DateTime.now(), deviceType: DeviceType.hikerNode));
      await _db.insertHiker(Hiker(deviceId: 'hiker_2', name: 'Albert', lastLat: 7.0700, lastLon: 125.6100, lastSeen: DateTime.now(), deviceType: DeviceType.hikerNode));
      await _db.insertHiker(Hiker(deviceId: 'hiker_3', name: 'Jian', lastLat: 7.0700, lastLon: 125.6100, lastSeen: DateTime.now(), deviceType: DeviceType.smartphone));
      hikers = await _db.getHikers();
    }

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
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          title: const Text('New Mission', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Trail Name (e.g., Mount Apo)',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text('CANCEL', style: TextStyle(color: Colors.white.withOpacity(0.5)))),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  await _db.startTrip(nameController.text);
                  Navigator.pop(context);
                  _loadData();
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('START'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020817), // Deepest Space Navy
      bottomNavigationBar: _buildBottomNav(),
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(top: -100, right: -100, child: _buildGlow(const Color(0xFF1E3A8A).withOpacity(0.2))),
          Positioned(bottom: -100, left: -100, child: _buildGlow(const Color(0xFF0D9488).withOpacity(0.1))),
          
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
                      _buildMeshTopologySection(),
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
            Expanded(child: _buildTacticalStatCard('CLIMBERS', '$_activeHikers/$_totalHikers', Icons.group_outlined, Colors.blueAccent)),
            const SizedBox(width: 16),
            Expanded(child: _buildTacticalStatCard('MAX HOPS', '$_maxHops', Icons.lan_outlined, Colors.purpleAccent)),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusBanner(),
      ],
    );
  }

  Widget _buildTacticalStatCard(String label, String value, IconData icon, Color accent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
              Icon(icon, color: accent.withOpacity(0.5), size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    bool hasSOS = _hikerList.any((h) => h.status == HikerStatus.sos);
    Color color = hasSOS ? Colors.redAccent : Colors.teal;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(hasSOS ? Icons.warning_rounded : Icons.verified_user_outlined, color: color, size: 18),
          const SizedBox(width: 12),
          Text(
            hasSOS ? 'EMERGENCY PROTOCOL ACTIVE' : 'ALL SYSTEMS OPERATIONAL',
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
          ),
          const Spacer(),
          if (hasSOS) _buildPulseDot(Colors.redAccent),
        ],
      ),
    );
  }

  Widget _buildPulseDot(Color color) {
    return Container(
      width: 8, height: 8,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color, boxShadow: [BoxShadow(color: color, blurRadius: 4, spreadRadius: 2)]),
    );
  }

  Widget _buildMeshTopologySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('RELAY TOPOLOGY'),
        const SizedBox(height: 16),
        Container(
          height: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: CustomPaint(
            size: Size.infinite,
            painter: _MeshTopologyPainter(_hikerList),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('NODE HEALTH'),
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
        color: isSOS ? Colors.red.withOpacity(0.05) : Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSOS ? Colors.red.withOpacity(0.2) : Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          _buildStatusOrb(h.status),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                Text(h.deviceType == DeviceType.hikerNode ? 'HIKOT V1 • ${h.hopCount} HOPS' : 'SMARTPHONE • ${h.hopCount} HOPS', 
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${h.batteryLevel}%', style: TextStyle(color: _getBatteryColor(h.batteryLevel), fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('RSSI: -${65 + (100 - h.signalStrength) ~/ 2}dBm', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  Color _getBatteryColor(int level) {
    if (level > 70) return Colors.teal;
    if (level > 30) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _buildStatusOrb(HikerStatus status) {
    Color color = switch(status) {
      HikerStatus.sos => Colors.redAccent,
      HikerStatus.warning => Colors.orangeAccent,
      HikerStatus.noSignal => Colors.white24,
      _ => Colors.teal,
    };
    return Container(
      width: 10, height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2));
  }

  Widget _buildDashboardHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Guide dashboard', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                Text(_currentTrip?.name ?? 'No active mission', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16)),
              ],
            ),
            _buildStatusBadge(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge() {
    bool isActive = _currentTrip != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isActive ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isActive ? Colors.greenAccent : Colors.orangeAccent).withOpacity(0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: isActive ? Colors.greenAccent : Colors.orangeAccent),
          const SizedBox(width: 8),
          Text(isActive ? 'Mesh on' : 'Standby', style: TextStyle(color: isActive ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMainStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatTile('$_activeHikers/$_totalHikers', 'Online')),
        const SizedBox(width: 16),
        Expanded(child: _buildStatTile('$_maxHops', 'Hops max')),
      ],
    );
  }

  Widget _buildStatTile(String value, String label) {
    bool isMissing = _hikerList.any((h) => h.status == HikerStatus.missing);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: isMissing && label == 'Online' ? Colors.redAccent.withOpacity(0.05) : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: isMissing && label == 'Online' ? Border.all(color: Colors.redAccent.withOpacity(0.3)) : null,
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: isMissing && label == 'Online' ? Colors.redAccent : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: isMissing && label == 'Online' ? Colors.redAccent.withOpacity(0.5) : Colors.white.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildHeadcountCard() {
    int missingCount = _hikerList.where((h) => h.status == HikerStatus.missing || h.status == HikerStatus.noSignal).length;
    bool allPresent = missingCount == 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (allPresent ? Colors.greenAccent : Colors.redAccent).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (allPresent ? Colors.greenAccent : Colors.redAccent).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(allPresent ? Icons.group_sharp : Icons.group_remove_sharp, color: allPresent ? Colors.greenAccent : Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Text(
            allPresent ? 'ALL CLIMBERS ACCOUNTED FOR' : '$missingCount CLIMBER(S) UNACCOUNTED',
            style: TextStyle(
              color: allPresent ? Colors.greenAccent : Colors.redAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArchitectureStatus() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SYSTEM ARCHITECTURE', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildLayerBadge('CLIMBER', Colors.blueAccent),
            const SizedBox(width: 8),
            _buildLayerBadge('MESH', Colors.teal),
            const SizedBox(width: 8),
            _buildLayerBadge('GUIDE', Colors.purpleAccent),
          ],
        ),
      ],
    );
  }

  Widget _buildLayerBadge(String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ),
    );
  }

  Widget _buildMapPreview() {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen())),
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.greenAccent.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _MiniRadarPainter(_hikerList),
            ),
            Positioned(
              top: 15, left: 15,
              child: Text('Live trail map', style: TextStyle(color: Colors.greenAccent.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSOSAlertCard(String name, String hops, String battery) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              const SizedBox(width: 10),
              Text('SOS active — $name', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Active Now • $hops • Battery $battery', style: TextStyle(color: Colors.redAccent.withOpacity(0.7), fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSafetyStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 20),
          const SizedBox(width: 12),
          Text('All hikers secure', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildSystemSpecs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SYSTEM SPECS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildSpecCard(
                'BT range per hop',
                '~5-10m (forest)\n~15-30m (ridge)\nEach phone = 1 node',
                Icons.bluetooth_searching,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSpecCard(
                'Recommended spacing',
                'Max 10m between\nany two climbers\nfor stable relay',
                Icons.straighten,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSpecCard(String title, String content, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent.withOpacity(0.6), size: 16),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(content, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildMeshTopology() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('MESH TOPOLOGY', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          height: 300,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: CustomPaint(
            painter: _MeshTopologyPainter(_hikerList),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.8),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTacticalNavItem(Icons.grid_view_rounded, 'HUB', true, () {}),
                _buildTacticalNavItem(Icons.group_outlined, 'TEAM', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HikerListScreen())).then((_) => _loadData());
                }),
                _buildTacticalNavItem(Icons.radar_outlined, 'TACTICAL', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
                }),
                _buildTacticalNavItem(Icons.settings_outlined, 'CONFIG', false, () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTacticalNavItem(IconData icon, String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Holographic Indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: 2, width: active ? 24 : 0,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              boxShadow: [
                if (active) BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 8, spreadRadius: 1)
              ],
            ),
          ),
          const SizedBox(height: 12),
          Icon(icon, color: active ? Colors.blueAccent : Colors.white.withOpacity(0.2), size: 22),
          const SizedBox(height: 4),
          Text(
            label, 
            style: TextStyle(
              color: active ? Colors.blueAccent : Colors.white.withOpacity(0.2), 
              fontSize: 9, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1
            )
          ),
        ],
      ),
    );
  }

  Widget _buildNodeHealthSection() {
    final activeNodes = _hikerList.where((h) => h.status != HikerStatus.noSignal).toList();
    if (activeNodes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('NODE HEALTH (ESP32 SYNC)', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2)),
        const SizedBox(height: 16),
        ...activeNodes.map((hiker) => _buildNodeHealthCard(hiker)).toList(),
      ],
    );
  }

  Widget _buildNodeHealthCard(Hiker hiker) {
    bool isNode = hiker.deviceType == DeviceType.hikerNode;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Icon(isNode ? Icons.memory : Icons.smartphone, color: Colors.blueAccent.withOpacity(0.7), size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hiker.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(isNode ? 'HIKOT V1 Node • Active' : 'Smartphone • Active', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text('${hiker.batteryLevel}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  _buildOledBatteryBar(hiker.batteryLevel),
                ],
              ),
              const SizedBox(height: 4),
              Text('RSSI: -${60 + (100 - hiker.signalStrength) ~/ 2} dBm', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOledBatteryBar(int level) {
    return Container(
      width: 24,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: level / 100,
          child: Container(color: Colors.greenAccent),
        ),
      ),
    );
  }



  Widget _buildGlow(Color color) {
    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: 100,
            spreadRadius: 50,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MiniRadarPainter extends CustomPainter {
  final List<Hiker> hikers;
  _MiniRadarPainter(this.hikers);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke;

    for (int i = 1; i <= 3; i++) {
      canvas.drawCircle(center, i * 35.0, paint);
    }
    
    // Draw Vertical Trail Line
    canvas.drawLine(center, Offset(center.dx, size.height), paint..color = Colors.blueAccent.withOpacity(0.2));

    final dotPaint = Paint()..style = PaintingStyle.fill;
    // Draw Guide Hub at center
    canvas.drawCircle(center, 5, dotPaint..color = Colors.teal);
    
    final sortedHikers = List<Hiker>.from(hikers)
      ..sort((a, b) => a.hopCount.compareTo(b.hopCount));

    for (int i = 0; i < sortedHikers.length; i++) {
      final hiker = sortedHikers[i];
      if (hiker.status == HikerStatus.noSignal) continue;
      
      final hikerPos = Offset(center.dx, center.dy + (i + 1) * 30.0);
      
      if (hikerPos.dy < size.height) {
        // Draw Hiker Node with Glow
        canvas.drawCircle(hikerPos, 6, dotPaint..color = (hiker.status == HikerStatus.sos ? Colors.redAccent : Colors.blueAccent).withOpacity(0.2));
        canvas.drawCircle(hikerPos, 3, dotPaint..color = hiker.status == HikerStatus.sos ? Colors.redAccent : Colors.blueAccent);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MeshTopologyPainter extends CustomPainter {
  final List<Hiker> hikers;
  _MeshTopologyPainter(this.hikers);

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final startY = 40.0;
    final spacing = 60.0;

    final paintLine = Paint()
      ..color = Colors.greenAccent.withOpacity(0.3)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintNode = Paint()..style = PaintingStyle.fill;

    // 1. Draw Guide (Hub)
    canvas.drawCircle(Offset(centerX, startY), 18, paintNode..color = Colors.greenAccent.withOpacity(0.2));
    canvas.drawCircle(Offset(centerX, startY), 18, paintLine..color = Colors.greenAccent);
    _drawText(canvas, Offset(centerX - 12, startY - 8), "G", 12, Colors.greenAccent);

    // 2. Draw Hikers in chain
    final chain = hikers.where((h) => h.status != HikerStatus.noSignal).toList();
    chain.sort((a, b) => b.hopCount.compareTo(a.hopCount));

    for (int i = 0; i < chain.length; i++) {
      final hiker = chain[i];
      final nodeY = startY + (i + 1) * spacing;
      final prevY = startY + i * spacing;

      canvas.drawLine(Offset(centerX, prevY + 18), Offset(centerX, nodeY - 18), paintLine..color = Colors.blueAccent.withOpacity(0.5));
      _drawText(canvas, Offset(centerX + 25, (prevY + nodeY) / 2 - 7), "Hop ${hiker.hopCount}", 9, Colors.white38);

      final isSOS = hiker.status == HikerStatus.sos;
      final isMissing = hiker.status == HikerStatus.missing;
      final color = isSOS || isMissing ? Colors.redAccent : Colors.blueAccent;
      
      canvas.drawCircle(Offset(centerX, nodeY), 18, paintNode..color = color.withOpacity(0.1));
      canvas.drawCircle(Offset(centerX, nodeY), 18, paintLine..color = color);
      
      final label = isMissing ? "!" : (hiker.name.length > 2 ? hiker.name.substring(0, 2).toUpperCase() : hiker.name);
      _drawText(canvas, Offset(centerX - 10, nodeY - 8), label, 11, color);

      if (isMissing) {
        _drawText(canvas, Offset(centerX + 25, nodeY - 5), "MISSING", 8, Colors.redAccent);
      }
    }
  }

  void _drawText(Canvas canvas, Offset offset, String text, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
