import 'package:flutter/material.dart';
import '../models/hiker.dart';

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // GPS Coordinates (Mimicking the diagram)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GPS MONITOR',
                style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              Icon(Icons.gps_fixed, size: 12, color: Colors.blueAccent.withOpacity(0.5)),
            ],
          ),
          const Divider(color: Color(0xFF333333)),
          Text(
            'LAT: ${hiker.lastLat.toStringAsFixed(4)}°N',
            style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          Text(
            'LON: ${hiker.lastLon.toStringAsFixed(4)}°E',
            style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          
          // BLE MESH Status Bar
          _buildOledBar('BLE: MESH OK', hiker.signalStrength / 100, Colors.blue),
          const SizedBox(height: 8),
          
          // BATTERY Status Bar
          _buildOledBar('BAT: ${hiker.batteryLevel}%', hiker.batteryLevel / 100, Colors.green),
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
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace')),
            Text('${(progress * 100).toInt()}%', style: TextStyle(color: color, fontSize: 10, fontFamily: 'monospace')),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF1A1A1A),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
