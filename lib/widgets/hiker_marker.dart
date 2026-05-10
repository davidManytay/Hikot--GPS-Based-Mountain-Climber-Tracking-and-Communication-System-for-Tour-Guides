import 'package:flutter/material.dart';
import '../models/hiker.dart';

class HikerMarkerWidget extends StatelessWidget {
  final String name;
  final HikerStatus status;
  final bool showLabel;
  final int batteryLevel;

  const HikerMarkerWidget({
    super.key,
    required this.name,
    required this.status,
    this.batteryLevel = 100,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _getStatusColor(status);
    final bool isSOS = status == HikerStatus.sos;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          _buildLabel(statusColor),
        const SizedBox(height: 4),
        _buildMarker(statusColor, isSOS),
      ],
    );
  }

  Widget _buildLabel(Color statusColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 10, 
              fontWeight: FontWeight.bold,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            batteryLevel < 20 ? Icons.battery_alert : Icons.battery_std,
            size: 10,
            color: batteryLevel < 20 ? Colors.red : Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(Color statusColor, bool isSOS) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: statusColor,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.6),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: isSOS 
        ? const Icon(Icons.sos, color: Colors.white, size: 12)
        : Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
    );
  }

  Color _getStatusColor(HikerStatus status) {
    switch (status) {
      case HikerStatus.active: return Colors.greenAccent;
      case HikerStatus.warning: return Colors.orangeAccent;
      case HikerStatus.noSignal: return Colors.redAccent;
      case HikerStatus.sos: return Colors.red;
      case HikerStatus.missing: return Colors.purple;
    }
  }
}
