import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';

import '../models/device_role.dart';
import '../models/gps_packet.dart';
import '../services/auth_service.dart';
import '../services/mesh_relay_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import '../widgets/tactical_navigation_bar.dart';
import '../widgets/realistic_iot_device.dart';
import 'hardware_specs_screen.dart';
import 'login_screen.dart';

/// Light "My status" node UI + IoT reference image (climber layer).
class ClimberNodeScreen extends StatefulWidget {
  const ClimberNodeScreen({super.key});

  static const String iotImageAsset = 'assets/climber_iot_device.png';

  @override
  State<ClimberNodeScreen> createState() => _ClimberNodeScreenState();
}


class _ClimberNodeScreenState extends State<ClimberNodeScreen> {
  final _settings = SettingsService();
  final _mesh = MeshRelayService();
  final _nodeIdController = TextEditingController();
  final _scrollController = ScrollController();
  final _sosSectionKey = GlobalKey();

  Timer? _holdTimer;
  Timer? _tickTimer;
  Timer? _gpsTimer;
  Timer? _meshUiTimer;
  double _holdProgress = 0;
  bool _sending = false;
  int _navIndex = 0;

  Position? _lastPosition;
  DateTime? _lastGpsAt;
  DateTime? _lastMeshBroadcastAt;
  String _meshHint = 'Mesh starting…';
  bool _meshReady = false;

  static const _holdDuration = Duration(seconds: 3);
  static const _meshGpsMinInterval = Duration(seconds: 12);
  static const int _climberBatteryPercent = 87;

  @override
  void initState() {
    super.initState();
    _nodeIdController.text = _settings.climberNodeId;
    _initMesh();
    _refreshGps();
    _gpsTimer = Timer.periodic(const Duration(seconds: 5), (_) => _refreshGps());
    _meshUiTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initMesh() async {
    try {
      await _mesh.init();
      if (!mounted) return;
      setState(() {
        _meshReady = _mesh.isMeshRadioActive;
        _meshHint = _meshReady
            ? 'BLE mesh is on: you appear as a peer, relay others’ packets, and can send GPS/SOS.'
            : 'Mesh radio unavailable (emulator, BT off, or timeout). GPS + SOS still run; neighbor count stays 0.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _meshReady = false;
          _meshHint = 'Mesh init failed ($e). SOS and local GPS still work.';
        });
      }
    }
  }

  Future<void> _refreshGps() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      final now = DateTime.now();
      DateTime? newTx = _lastMeshBroadcastAt;
      if (_settings.climberBroadcastGpsOnMesh) {
        final allow = _lastMeshBroadcastAt == null || now.difference(_lastMeshBroadcastAt!) >= _meshGpsMinInterval;
        if (allow) {
          final id = _nodeIdController.text.trim().isEmpty ? _settings.climberNodeId : _nodeIdController.text.trim();
          final sig = math.max(1, 100 - pos.accuracy.round()).clamp(1, 99);
          _mesh.broadcastPacket(
            GpsPacket(
              uuid: const Uuid().v4(),
              hikerId: id,
              lat: pos.latitude,
              lon: pos.longitude,
              timestamp: now.millisecondsSinceEpoch,
              type: PacketType.gps,
              batteryLevel: _climberBatteryPercent,
              signalStrength: sig,
              hopCount: 1,
            ),
          );
          newTx = now;
        }
      }
      setState(() {
        _lastPosition = pos;
        _lastGpsAt = now;
        _lastMeshBroadcastAt = newTx;
      });
    } catch (_) {
      try {
        final last = await Geolocator.getLastKnownPosition();
        if (mounted && last != null) {
          setState(() {
            _lastPosition = last;
            _lastGpsAt = DateTime.now();
          });
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _tickTimer?.cancel();
    _gpsTimer?.cancel();
    _meshUiTimer?.cancel();
    _settings.climberNodeId = _nodeIdController.text.trim();
    _nodeIdController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSosDown() {
    if (_sending) return;
    _holdTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _holdProgress = 0);
    final started = DateTime.now();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(started);
      setState(() {
        _holdProgress = (elapsed.inMilliseconds / _holdDuration.inMilliseconds).clamp(0.0, 1.0);
      });
    });
    _holdTimer = Timer(_holdDuration, () {
      _tickTimer?.cancel();
      _holdTimer = null;
      _sendSos();
    });
  }

  void _onSosUp() {
    if (_sending) return;
    _holdTimer?.cancel();
    _tickTimer?.cancel();
    setState(() => _holdProgress = 0);
  }

  Future<void> _sendSos() async {
    if (_sending) return;
    _holdTimer?.cancel();
    _tickTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _sending = true;
      _holdProgress = 0;
    });
    HapticFeedback.heavyImpact();
    final hasV = await Vibration.hasVibrator();
    if (hasV == true) Vibration.vibrate(duration: 400);

    final id = _nodeIdController.text.trim().isEmpty ? _settings.climberNodeId : _nodeIdController.text.trim();
    _settings.climberNodeId = id;

    Position? pos = _lastPosition;
    pos ??= await Geolocator.getLastKnownPosition();
    final lat = pos?.latitude ?? 0;
    final lon = pos?.longitude ?? 0;

    final packet = GpsPacket(
      uuid: const Uuid().v4(),
      hikerId: id,
      lat: lat,
      lon: lon,
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: PacketType.sos,
      batteryLevel: _climberBatteryPercent,
      signalStrength: 95,
      hopCount: 1,
    );
    _mesh.broadcastPacket(packet);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('SOS sent — $id · mesh priority relay'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _changeRole() async {
    await AuthService().logout();
    await _settings.setDeviceRole(HikotDeviceRole.guideHub);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _onBottomNav(int index) {
    setState(() => _navIndex = index);
    switch (index) {
      case 0:
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
        break;
      case 1:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Live team map is only on the guide handset.')),
        );
        break;
      case 2:
        final ctx = _sosSectionKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
        break;
      case 3:
        _showSettingsSheet();
        break;
    }
  }

  BoxDecoration _climberCardDecoration({Color? color}) {
    return BoxDecoration(
      color: color ?? Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      border: null,
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              color: HikotColors.accentTeal,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: HikotColors.textSecondary, height: 1.35)),
          ],
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + MediaQuery.paddingOf(ctx).bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'NODE SETTINGS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nodeIdController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'MESH NODE ID',
                      labelStyle: const TextStyle(color: HikotColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w800),
                      hintText: 'Enter callsign',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('SHARE GPS ON MESH', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w700, fontSize: 14)),
                    subtitle: const Text(
                      'Broadcasts position for the guide handset over BLE (no cell service).',
                      style: TextStyle(color: HikotColors.textSecondary, fontSize: 12),
                    ),
                    value: _settings.climberBroadcastGpsOnMesh,
                    activeColor: HikotColors.accentTeal,
                    onChanged: (v) {
                      _settings.climberBroadcastGpsOnMesh = v;
                      setModal(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Text(
                      _meshHint,
                      style: const TextStyle(color: HikotColors.textMuted, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _changeRole();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: HikotColors.surfaceLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('SWITCH TO GUIDE ROLE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _latStr() {
    final p = _lastPosition;
    if (p == null) return '—';
    final h = p.latitude >= 0 ? 'N' : 'S';
    return '${p.latitude.abs().toStringAsFixed(4)}° $h';
  }

  String _lonStr() {
    final p = _lastPosition;
    if (p == null) return '—';
    final h = p.longitude >= 0 ? 'E' : 'W';
    return '${p.longitude.abs().toStringAsFixed(4)}° $h';
  }

  String _elevStr() {
    final p = _lastPosition;
    if (p == null) return '—';
    return '${p.altitude.toStringAsFixed(0)} m';
  }

  String _accuracyStr() {
    final p = _lastPosition;
    if (p?.accuracy == null) return '—';
    return '${p!.accuracy.toStringAsFixed(0)}m';
  }

  String _lastMeshSendLabel() {
    if (!_settings.climberBroadcastGpsOnMesh) return 'Off';
    if (_lastMeshBroadcastAt == null) return '—';
    final s = DateTime.now().difference(_lastMeshBroadcastAt!).inSeconds;
    if (s < 90) return '${s}s';
    return '${s ~/ 60}m';
  }

  String _syncStr() {
    if (_lastGpsAt == null) return '—';
    final s = DateTime.now().difference(_lastGpsAt!).inSeconds;
    if (s < 120) return '$s sec ago';
    return '${s ~/ 60} min ago';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  _buildTopHeader(),
                  const SizedBox(height: 22),
                  const SizedBox(height: 12),
                  RealisticIotDevice(
                    nodeId: _nodeIdController.text.trim().isEmpty ? _settings.climberNodeId : _nodeIdController.text.trim(),
                    hasGps: _lastPosition != null,
                    batteryLevel: _climberBatteryPercent,
                    meshHops: 1, // Simplified for UI
                    isMeshActive: _meshReady,
                    sosProgress: _holdProgress,
                    isSending: _sending,
                    onSosDown: _onSosDown,
                    onSosUp: _onSosUp,
                  ),
                  const SizedBox(height: 32),
                  _sectionHeader('Live readings'),
                  _buildMetricGrid(),
                  const SizedBox(height: 22),
                  _sectionHeader('Position'),
                  _buildGpsCard(),
                  const SizedBox(height: 22),
                  _buildHowItWorksExpansion(),
                ],
              ),
            ),
            _buildBottomNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My status',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.onSurface, height: 1.1, letterSpacing: -0.5),
              ),
              const SizedBox(height: 6),
              Text(
                'Climber node · ${_meshReady ? 'Mesh active' : 'Mesh limited'}',
                style: const TextStyle(fontSize: 14, color: HikotColors.textSecondary, fontWeight: FontWeight.w500, height: 1.3),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HardwareSpecsScreen())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: HikotColors.accentTeal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: HikotColors.accentTeal.withOpacity(0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.developer_board_rounded, color: HikotColors.accentTeal, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'DEVICE SPECS',
                        style: TextStyle(color: HikotColors.accentTeal, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _meshReady ? HikotColors.success.withOpacity(0.1) : HikotColors.warning.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (_meshReady ? HikotColors.success : HikotColors.warning).withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _meshReady ? HikotColors.success : HikotColors.warning,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_meshReady ? HikotColors.success : HikotColors.warning).withOpacity(0.5),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _meshReady ? 'Mesh on' : 'GPS only',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.white, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHowItWorksExpansion() {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: _climberCardDecoration(),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: HikotColors.accentTeal.withOpacity(0.08),
          ),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            iconColor: HikotColors.accentTeal,
            collapsedIconColor: HikotColors.textMuted,
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: HikotColors.accentTeal),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'How this node works',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('GPS relay, mesh peers, SOS', style: TextStyle(fontSize: 12, color: HikotColors.textMuted)),
            ),
            children: [
              _howLine(Icons.share_location_outlined, 'When enabled, shares GPS on the mesh (~every 12s) so the guide handset can follow you offline.'),
              const SizedBox(height: 10),
              _howLine(Icons.route_outlined, 'Relays other climbers’ packets when BLE peers are connected (mesh service applies TTL / dedupe).'),
              const SizedBox(height: 10),
              _howLine(Icons.sos, 'SOS: hold 3 seconds, or use confirmation, to send a priority packet with your last known coordinates.'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _howLine(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: HikotColors.textMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: HikotColors.textSecondary))),
      ],
    );
  }



  Widget _metricCell(String value, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      decoration: _climberCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 11, color: HikotColors.textSecondary, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildMetricGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.52,
      children: [
        _metricCell('${_mesh.meshNeighborCount}', 'Peers nearby'),
        _metricCell('$_climberBatteryPercent%', 'Battery'),
        _metricCell(_lastMeshSendLabel(), 'Last mesh send'),
        _metricCell(_accuracyStr(), 'GPS accuracy'),
      ],
    );
  }

  Widget _buildGpsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _climberCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.my_location_outlined, size: 20, color: HikotColors.accentTeal),
              SizedBox(width: 10),
              Text('Coordinates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
            ],
          ),
          const SizedBox(height: 8),
          Divider(height: 24, color: Colors.white.withOpacity(0.05)),
          _gpsRow('Latitude', _latStr()),
          Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          _gpsRow('Longitude', _lonStr()),
          Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          _gpsRow('Elevation', _elevStr()),
          Divider(height: 1, color: Colors.white.withOpacity(0.05)),
          _gpsRow('Last sync', _syncStr()),
        ],
      ),
    );
  }

  Widget _gpsRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: const TextStyle(fontSize: 13, color: HikotColors.textMuted, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.2)),
          ),
        ],
      ),
    );
  }



  Widget _buildBottomNav() {
    return TacticalNavigationBar(
      currentIndex: _navIndex,
      items: [
        TacticalNavItem(
          icon: Icons.home_rounded,
          label: 'HOME',
          onTap: () => _onBottomNav(0),
        ),
        TacticalNavItem(
          icon: Icons.radar_rounded,
          label: 'MAP',
          onTap: () => _onBottomNav(1),
        ),
        TacticalNavItem(
          icon: Icons.health_and_safety_rounded,
          label: 'SOS',
          onTap: () => _onBottomNav(2),
        ),
        TacticalNavItem(
          icon: Icons.settings_rounded,
          label: 'SETUP',
          onTap: () => _onBottomNav(3),
        ),
      ],
    );
  }
}
