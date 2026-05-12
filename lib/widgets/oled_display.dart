import 'package:flutter/material.dart';
import '../models/hiker.dart';
import '../theme/app_theme.dart';

class OledDisplayWidget extends StatelessWidget {
  final Hiker hiker;
  final double distance;

  const OledDisplayWidget({
    super.key,
    required this.hiker,
    required this.distance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // OLED Black
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1E293B), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GPS Coordinates
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SYSTEM MONITOR',
                style: TextStyle(color: HikotColors.accent, fontSize: 9, fontWeight: FontWeight.bold, fontFamily: 'monospace', letterSpacing: 1),
              ),
              Icon(Icons.sensors, size: 12, color: HikotColors.accent.withOpacity(0.5)),
            ],
          ),
          const Divider(color: Color(0xFF1E293B), height: 16),
          Text(
            'LAT: ${hiker.lastLat.toStringAsFixed(5)}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          Text(
            'LON: ${hiker.lastLon.toStringAsFixed(5)}',
            style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          
          // BLE MESH Status Bar
          _buildOledBar('MESH SIGNAL', hiker.signalStrength / 100, HikotColors.primary),
          const SizedBox(height: 10),
          
          // BATTERY Status Bar
          _buildOledBar('BATT STATUS', hiker.batteryLevel / 100, HikotColors.success),
        ],
      ),
    );
  }

  Widget _buildOledBar(String label, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: HikotColors.textSecondary, fontSize: 9, fontFamily: 'monospace')),
            Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
