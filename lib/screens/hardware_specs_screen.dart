import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HardwareSpecsScreen extends StatelessWidget {
  const HardwareSpecsScreen({super.key});

  static const String _deviceImageAsset = 'assets/hiker_iot_device.jpg';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HikotColors.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('NODE ARCHITECTURE', style: HikotTextStyles.label),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('HIKER TRACKING DEVICE', style: HikotTextStyles.h1),
              const Text(
                'Climber layer prototype — GPS, BLE mesh, OLED, SOS (3s hold), belt clip',
                style: TextStyle(
                  color: HikotColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth >= 520 ? 520.0 : constraints.maxWidth;
                    return SizedBox(
                      width: width,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B1220),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                          ),
                          child: Image.asset(
                            _deviceImageAsset,
                            fit: BoxFit.fitWidth,
                            alignment: Alignment.topCenter,
                            filterQuality: FilterQuality.high,
                            semanticLabel:
                                'Handheld hiker IoT device with OLED status, LEDs, SOS button, and hardware callouts',
                            errorBuilder: (_, error, __) => Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'Could not load device image.\n$error\n\nRun: flutter clean && flutter pub get, then full restart.',
                                style: const TextStyle(color: HikotColors.textSecondary, fontSize: 13, height: 1.4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              _buildSpecSection('CORE PROCESSING', [
                _buildSpecRow('Microcontroller', 'ESP32 / Arduino Nano', '32-bit dual core system for mesh logic.'),
                _buildSpecRow('Memory', '520KB SRAM', 'Optimized for high-speed packet buffering.'),
              ]),
              const SizedBox(height: 32),
              _buildSpecSection('COMMUNICATIONS', [
                _buildSpecRow('BLE Module', 'nRF52840 / ESP32', 'Bluetooth 5.0 Mesh with +8dBm TX power.'),
                _buildSpecRow('GPS Module', 'Neo-6M / u-blox M8', 'High sensitivity with active antenna support.'),
              ]),
              const SizedBox(height: 32),
              _buildSpecSection('POWER & CHASSIS', [
                _buildSpecRow('LiPo Battery', '3.7V 2000mAh', 'Approx. 12 hours per charge for field use.'),
                _buildSpecRow('Chassis', 'ABS / IP65 class', 'Weather-resistant enclosure; belt or backpack clip.'),
              ]),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 4, color: HikotColors.accentTeal),
            const SizedBox(width: 8),
            Text(title, style: HikotTextStyles.label),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildSpecRow(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: HikotColors.accentTeal, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(description, style: const TextStyle(color: HikotColors.textMuted, fontSize: 14, height: 1.35)),
          ),
        ],
      ),
    );
  }
}
