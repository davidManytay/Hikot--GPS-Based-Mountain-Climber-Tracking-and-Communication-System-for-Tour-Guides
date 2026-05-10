import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/detection.dart';

class DetectorListPanel extends StatelessWidget {
  final List<Detection> detections;
  final VoidCallback? onClearAll;
  final Function(Detection)? onDetectionTap;

  const DetectorListPanel({
    super.key,
    required this.detections,
    this.onClearAll,
    this.onDetectionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (detections.isEmpty) return const SizedBox.shrink();

    // Sort detections by priority (SOS first)
    final sortedDetections = List<Detection>.from(detections)
      ..sort((a, b) {
        if (a.type == DetectionType.sos) return -1;
        if (b.type == DetectionType.sos) return 1;
        return b.timestamp.compareTo(a.timestamp);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACTIVE SOS ALERTS',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Text(
                  '${detections.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 10),
            scrollDirection: Axis.vertical,
            itemCount: sortedDetections.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DetectionCard(
                detection: sortedDetections[index],
                onTap: () => onDetectionTap?.call(sortedDetections[index]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetectionCard extends StatelessWidget {
  final Detection detection;
  final VoidCallback onTap;

  const _DetectionCard({required this.detection, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isSOS = detection.type == DetectionType.sos;
    final color = _getDetectionColor(detection.type);

    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  border: Border.all(
                    color: color.withOpacity(0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _getDetectionIcon(detection.type),
                          size: 14,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          detection.typeLabel,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(detection.timestamp),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      detection.hikerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        detection.message,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 11,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _getDetectionColor(DetectionType type) {
    switch (type) {
      case DetectionType.sos: return Colors.red;
      case DetectionType.offTrail: return Colors.orangeAccent;
      case DetectionType.stationary: return Colors.cyanAccent;
      case DetectionType.lowBattery: return Colors.deepOrangeAccent;
      case DetectionType.proximityAlert: return Colors.blueAccent;
    }
  }

  IconData _getDetectionIcon(DetectionType type) {
    switch (type) {
      case DetectionType.sos: return Icons.sos;
      case DetectionType.offTrail: return Icons.explore_off;
      case DetectionType.stationary: return Icons.accessibility_new;
      case DetectionType.lowBattery: return Icons.battery_alert;
      case DetectionType.proximityAlert: return Icons.spatial_audio_off;
    }
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
