import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  late TextEditingController _nameController;
  late double _threshold;
  late double _proximity;
  late double _immobility;
  late double _battery;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _settings.guideName);
    _threshold = _settings.heartbeatThresholdSeconds.toDouble();
    _proximity = _settings.proximityThresholdMeters.toDouble();
    _immobility = _settings.immobilityThresholdMinutes.toDouble();
    _battery = _settings.batteryWarningThreshold.toDouble();
  }

  Future<void> _save() async {
    await _settings.setGuideName(_nameController.text);
    await _settings.setHeartbeatThreshold(_threshold.toInt());
    _settings.proximityThresholdMeters = _proximity.toInt();
    _settings.immobilityThresholdMinutes = _immobility.toInt();
    _settings.batteryWarningThreshold = _battery.toInt();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CONFIG SYNCHRONIZED', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        sliderTheme: SliderThemeData(
          trackHeight: 2,
          activeTrackColor: Colors.blueAccent,
          inactiveTrackColor: Colors.white10,
          thumbColor: Colors.blueAccent,
          overlayColor: Colors.blueAccent.withOpacity(0.1),
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8, elevation: 10),
          overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2),
          activeTickMarkColor: Colors.blueAccent,
          inactiveTickMarkColor: Colors.white24,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF020617),
        appBar: AppBar(
          title: const Text('SYSTEM CONFIG', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 3, color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader('GUIDE IDENTIFICATION'),
              const SizedBox(height: 16),
              _buildGlassCard(
                child: TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    labelText: 'COMMANDER CALLSIGN',
                    labelStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10, letterSpacing: 1),
                    prefixIcon: const Icon(Icons.badge_outlined, color: Colors.blueAccent, size: 20),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('SAFETY THRESHOLDS'),
              const SizedBox(height: 16),
              _buildGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSliderRow('HEARTBEAT TIMEOUT', '${_threshold.toInt()}s', 'MAX ALLOWED LATENCY BEFORE ALERT', Icons.timer_outlined),
                    Slider(
                      value: _threshold,
                      min: 30, max: 300, divisions: 9,
                      onChanged: (val) => setState(() => _threshold = val),
                    ),
                    const SizedBox(height: 24),
                    _buildSliderRow('PROXIMITY RADII', '${_proximity.toInt()}m', 'GEOFENCE LIMIT PER NODE', Icons.radar_outlined),
                    Slider(
                      value: _proximity,
                      min: 100, max: 2000, divisions: 19,
                      onChanged: (val) => setState(() => _proximity = val),
                    ),
                    const SizedBox(height: 24),
                    _buildSliderRow('IMMOBILITY SENSOR', '${_immobility.toInt()}m', 'STATIONARY ALERT TRIGGER TIME', Icons.vibration_outlined),
                    Slider(
                      value: _immobility,
                      min: 1, max: 60, divisions: 59,
                      onChanged: (val) => setState(() => _immobility = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader('CRITICAL HARDWARE'),
              const SizedBox(height: 16),
              _buildGlassCard(
                child: Column(
                  children: [
                    _buildSliderRow('LOW BATTERY MASK', '${_battery.toInt()}%', 'ENERGY DEPLETION WARNING LEVEL', Icons.battery_alert_outlined),
                    Slider(
                      value: _battery,
                      min: 5, max: 50, divisions: 9,
                      activeColor: Colors.redAccent,
                      thumbColor: Colors.redAccent,
                      onChanged: (val) => setState(() => _battery = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              _buildCommitButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommitButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.2), blurRadius: 15)],
      ),
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync_outlined, size: 20),
            const SizedBox(width: 12),
            Text('COMMIT CONFIGURATION', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, String value, String sub, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withOpacity(0.3), size: 14),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.5)),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
              child: Text(value, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 12, fontFamily: 'monospace')),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(sub, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.white.withOpacity(0.05))),
      ],
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: child,
    );
  }
}
