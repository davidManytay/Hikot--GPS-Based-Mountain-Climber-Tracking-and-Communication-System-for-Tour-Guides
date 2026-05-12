import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'welcome_screen.dart';

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
  late bool _isDark;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _settings.guideName);
    _threshold = _settings.heartbeatThresholdSeconds.toDouble();
    _proximity = _settings.proximityThresholdMeters.toDouble();
    _immobility = _settings.immobilityThresholdMinutes.toDouble();
    _battery = _settings.batteryWarningThreshold.toDouble();
    _isDark = _settings.isDarkMode;
  }

  Future<void> _save() async {
    HapticFeedback.heavyImpact();
    await _settings.setGuideName(_nameController.text);
    await _settings.setHeartbeatThreshold(_threshold.toInt());
    _settings.proximityThresholdMeters = _proximity.toInt();
    _settings.immobilityThresholdMinutes = _immobility.toInt();
    _settings.batteryWarningThreshold = _battery.toInt();
    _settings.isDarkMode = _isDark;
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: HikotColors.success, size: 18),
              const SizedBox(width: 12),
              const Text('SYSTEM PARAMETERS UPDATED', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10)),
            ],
          ),
          backgroundColor: HikotColors.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.05))),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // No background glow
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildSectionHeader('INTERFACE', 'USR-01'),
                    const SizedBox(height: 16),
                    _buildTacticalCard(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('NIGHT VISION MODE', style: HikotTextStyles.label),
                              const SizedBox(height: 4),
                              Text(_isDark ? 'ACTIVE' : 'INACTIVE', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                          Switch(
                            value: _isDark,
                            activeThumbColor: HikotColors.accentTeal,
                            activeTrackColor: HikotColors.accentTeal.withOpacity(0.35),
                            inactiveThumbColor: HikotColors.textMuted,
                            inactiveTrackColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                            onChanged: (val) {
                              setState(() => _isDark = val);
                              _settings.isDarkMode = val; // Apply immediately
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('IDENTIFICATION', 'ID-02'),
                    const SizedBox(height: 16),
                    _buildTacticalCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('COMMANDER CALLSIGN', style: HikotTextStyles.label),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _nameController,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface, 
                              fontWeight: FontWeight.bold, 
                              fontSize: 16, 
                              letterSpacing: 1
                            ),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.shield_outlined, color: HikotColors.accentTeal, size: 22),
                              hintText: "ENTER CALLSIGN",
                              hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('SAFETY PROTOCOLS', 'SAF-03'),
                    const SizedBox(height: 16),
                    _buildTacticalCard(
                      child: Column(
                        children: [
                          _buildTacticalSlider(
                            'HEARTBEAT TIMEOUT', 
                            _threshold, 30, 300, 's', 
                            'MAX SIGNAL LATENCY', 
                            Icons.timer_outlined,
                            (val) => setState(() => _threshold = val)
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(color: Colors.white10),
                          ),
                          _buildTacticalSlider(
                            'GEOFENCE RADIUS', 
                            _proximity, 100, 2000, 'm', 
                            'PER NODE LIMIT', 
                            Icons.radar_outlined,
                            (val) => setState(() => _proximity = val)
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Divider(color: Colors.white10),
                          ),
                          _buildTacticalSlider(
                            'MOTION TIMEOUT', 
                            _immobility, 1, 60, 'min', 
                            'IMMOBILITY TRIGGER', 
                            Icons.directions_run_outlined,
                            (val) => setState(() => _immobility = val)
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildSectionHeader('POWER MANAGEMENT', 'PWR-04'),
                    const SizedBox(height: 16),
                    _buildTacticalCard(
                      child: _buildTacticalSlider(
                        'LOW BATTERY MASK', 
                        _battery, 5, 50, '%', 
                        'WARNING THRESHOLD', 
                        Icons.battery_alert_outlined,
                        (val) => setState(() => _battery = val),
                        accentColor: HikotColors.error,
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildCommitButton(),
                    const SizedBox(height: 20),
                    _buildSignOutButton(),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: () async {
          await AuthService().logout();
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WelcomeScreen()),
              (route) => false,
            );
          }
        },
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: HikotColors.error.withOpacity(0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('SIGN OUT', style: TextStyle(color: HikotColors.error, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      pinned: true,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: Theme.of(context).colorScheme.onSurface),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('SYSTEM CONFIG', style: HikotTextStyles.label),
    );
  }

  Widget _buildTacticalSlider(String label, double value, double min, double max, String unit, String sub, IconData icon, Function(double) onChanged, {Color accentColor = HikotColors.primary}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: accentColor.withOpacity(0.5), size: 16),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5)),
                    Text(sub, style: const TextStyle(color: HikotColors.textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            Text('${value.toInt()}$unit', style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 13, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            activeTrackColor: accentColor,
            inactiveTrackColor: Theme.of(context).dividerColor.withOpacity(0.1),
            thumbColor: Colors.white,
            overlayColor: accentColor.withOpacity(0.1),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 0),
          ),
          child: Slider(
            value: value,
            min: min, max: max,
            divisions: (max - min).toInt(),
            onChanged: (val) {
              HapticFeedback.selectionClick();
              onChanged(val);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String code) {
    return Row(
      children: [
        Text(title, style: HikotTextStyles.label),
        const Spacer(),
        Text(code, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildTacticalCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildCommitButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: HikotColors.surfaceLight,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.white.withOpacity(0.1))),
          elevation: 0,
        ),
        child: const Text('SAVE PARAMETERS', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
      ),
    );
  }
}

