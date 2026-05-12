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
import 'login_screen.dart';

/// Light "My status" node UI + IoT reference image (climber layer).
class ClimberNodeScreen extends StatefulWidget {
  const ClimberNodeScreen({super.key});

  static const String iotImageAsset = 'assets/climber_iot_device.png';

  @override
  State<ClimberNodeScreen> createState() => _ClimberNodeScreenState();
}

class _ClimberLight {
  static const Color background = Color(0xFFF6F4F0);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE8E4DD);
  static const Color text = Color(0xFF1C1C1E);
  static const Color sub = Color(0xFF6B6B6B);
  static const Color accentBlue = Color(0xFF2563EB);
  static const Color onlineGreen = Color(0xFF16A34A);
  static const Color sosTint = Color(0xFFFFF5F5);
  static const Color sosBorder = Color(0xFFFECACA);
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
      color: color ?? _ClimberLight.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _ClimberLight.cardBorder),
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
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: _ClimberLight.sub,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 13, color: _ClimberLight.sub, height: 1.35)),
          ],
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _ClimberLight.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 20),
                  const Text('Node settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ClimberLight.text)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nodeIdController,
                    decoration: InputDecoration(
                      labelText: 'Mesh node ID',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share GPS on mesh'),
                    subtitle: const Text('Broadcasts position for the guide handset over BLE (no cell service).'),
                    value: _settings.climberBroadcastGpsOnMesh,
                    activeThumbColor: _ClimberLight.accentBlue,
                    onChanged: (v) {
                      _settings.climberBroadcastGpsOnMesh = v;
                      setModal(() {});
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(_meshHint, style: const TextStyle(color: _ClimberLight.sub, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 20),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _changeRole();
                    },
                    child: const Text('Switch to guide role'),
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
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark.copyWith(statusBarColor: Colors.transparent));

    return Scaffold(
      backgroundColor: _ClimberLight.background,
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
                  _sectionHeader('Your node', subtitle: 'Mesh ID and device reference.'),
                  _buildIotHeroCard(),
                  const SizedBox(height: 22),
                  _sectionHeader('Live readings'),
                  _buildMetricGrid(),
                  const SizedBox(height: 22),
                  _sectionHeader('Position'),
                  _buildGpsCard(),
                  const SizedBox(height: 22),
                  _sectionHeader('Emergency'),
                  KeyedSubtree(
                    key: _sosSectionKey,
                    child: _buildSosSection(),
                  ),
                  const SizedBox(height: 16),
                  _buildHowItWorksExpansion(),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: _ClimberLight.card,
                border: Border(top: BorderSide(color: _ClimberLight.cardBorder)),
              ),
              child: _buildBottomNav(),
            ),
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
              const Text(
                'My status',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _ClimberLight.text, height: 1.12, letterSpacing: -0.3),
              ),
              const SizedBox(height: 6),
              Text(
                'Climber node · ${_meshReady ? 'Mesh active' : 'Mesh limited'}',
                style: const TextStyle(fontSize: 14, color: _ClimberLight.sub, fontWeight: FontWeight.w500, height: 1.3),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _meshReady ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _meshReady ? const Color(0xFFC8E6C9) : const Color(0xFFFFE0B2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _meshReady ? _ClimberLight.onlineGreen : const Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _meshReady ? 'Mesh on' : 'GPS only',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _ClimberLight.text),
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
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent, splashColor: _ClimberLight.accentBlue.withOpacity(0.08)),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20, color: _ClimberLight.accentBlue),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'How this node works',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ClimberLight.text),
                  ),
                ),
              ],
            ),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('GPS relay, mesh peers, SOS', style: TextStyle(fontSize: 12, color: _ClimberLight.sub)),
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
        Icon(icon, size: 18, color: _ClimberLight.sub),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.4, color: _ClimberLight.sub))),
      ],
    );
  }

  Widget _buildIotHeroCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: _climberCardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 88,
              height: 88,
              child: Image.asset(
                ClimberNodeScreen.iotImageAsset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                errorBuilder: (_, __, ___) => Image.asset(
                  'assets/hiker_iot_device.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, ___, ____) => ColoredBox(
                    color: Colors.grey.shade300,
                    child: Icon(Icons.image_not_supported_outlined, color: Colors.grey.shade600),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Wearable node',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _ClimberLight.text),
                ),
                const SizedBox(height: 4),
                Text(
                  'Mesh ID ${_settings.climberNodeId} · change in Settings',
                  style: const TextStyle(fontSize: 12, color: _ClimberLight.sub, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
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
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ClimberLight.text, height: 1.05)),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: _ClimberLight.sub, fontWeight: FontWeight.w600)),
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
              Icon(Icons.my_location_outlined, size: 20, color: _ClimberLight.accentBlue),
              SizedBox(width: 8),
              Text('Coordinates', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ClimberLight.text)),
            ],
          ),
          const SizedBox(height: 4),
          const Divider(height: 24, color: _ClimberLight.cardBorder),
          _gpsRow('Latitude', _latStr()),
          const Divider(height: 1, color: _ClimberLight.cardBorder),
          _gpsRow('Longitude', _lonStr()),
          const Divider(height: 1, color: _ClimberLight.cardBorder),
          _gpsRow('Elevation', _elevStr()),
          const Divider(height: 1, color: _ClimberLight.cardBorder),
          _gpsRow('Last sync', _syncStr()),
        ],
      ),
    );
  }

  Widget _gpsRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(k, style: const TextStyle(fontSize: 13, color: _ClimberLight.sub, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(v, textAlign: TextAlign.end, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _ClimberLight.text)),
          ),
        ],
      ),
    );
  }

  Widget _buildSosSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _ClimberLight.sosTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ClimberLight.sosBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.health_and_safety_outlined, size: 20, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'SOS uses BLE mesh with your last coordinates.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _ClimberLight.text, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSosHoldButton(),
          const SizedBox(height: 8),
          const Text(
            'Hold the bar for 3 seconds, or release early to cancel. Mesh broadcast is prioritized.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _ClimberLight.sub, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSosHoldButton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _onSosDown(),
            onTapUp: (_) => _onSosUp(),
            onTapCancel: () => _onSosUp(),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Container(
                  width: double.infinity,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _ClimberLight.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _ClimberLight.text.withOpacity(0.22), width: 1),
                  ),
                  child: _sending
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.touch_app_outlined, size: 20, color: _ClimberLight.text.withOpacity(0.7)),
                            const SizedBox(width: 8),
                            const Text(
                              'Hold for SOS (3 sec)',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ClimberLight.text),
                            ),
                          ],
                        ),
                ),
                if (_holdProgress > 0)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                      child: LinearProgressIndicator(
                        value: _holdProgress,
                        minHeight: 4,
                        backgroundColor: Colors.transparent,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFB91C1C)),
          onPressed: _sending
              ? null
              : () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Send SOS now?'),
                      content: const Text(
                        'For field safety the physical node uses a 3-second hold. '
                        'Use this only if you cannot hold the button (e.g. gloves).',
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _sendSos();
                          },
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
                          child: const Text('Send SOS'),
                        ),
                      ],
                    ),
                  );
                },
          child: const Text('Can’t hold? Confirm to send'),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: _ClimberLight.accentBlue.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((s) {
          final selected = s.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? _ClimberLight.accentBlue : _ClimberLight.sub,
          );
        }),
      ),
      child: NavigationBar(
        height: 64,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        selectedIndex: _navIndex,
        onDestinationSelected: _onBottomNav,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.warning_amber_rounded), selectedIcon: Icon(Icons.warning_amber_rounded), label: 'SOS'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
