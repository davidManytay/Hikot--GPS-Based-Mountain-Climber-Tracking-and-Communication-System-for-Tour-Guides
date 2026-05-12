import 'dart:ui';
import 'package:flutter/material.dart';
import '../models/detection.dart';
import '../theme/app_theme.dart';

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
                'TACTICAL ALERTS',
                style: HikotTextStyles.label,
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: HikotColors.error.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: HikotColors.error.withOpacity(0.3)),
                ),
                child: Text(
                  '${detections.length}',
                  style: const TextStyle(color: HikotColors.error, fontSize: 10, fontWeight: FontWeight.bold),
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
    final color = _getDetectionColor(detection.type);

    return Container(
      width: 240,
      margin: const EdgeInsets.only(left: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: HikotColors.surface,
              border: Border.all(
                color: color.withOpacity(0.2),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
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
                      detection.typeLabel.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(detection.timestamp),
                      style: const TextStyle(
                        color: HikotColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  detection.hikerName.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  detection.message,
                  style: const TextStyle(
                    color: HikotColors.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getDetectionColor(DetectionType type) {
    switch (type) {
      case DetectionType.sos: return HikotColors.error;
      case DetectionType.offTrail: return HikotColors.warning;
      case DetectionType.stationary: return HikotColors.accent;
      case DetectionType.lowBattery: return HikotColors.warning;
      case DetectionType.proximityAlert: return HikotColors.primary;
    }
  }

  IconData _getDetectionIcon(DetectionType type) {
    switch (type) {
      case DetectionType.sos: return Icons.report_problem_rounded;
      case DetectionType.offTrail: return Icons.explore_off_outlined;
      case DetectionType.stationary: return Icons.accessibility_new_outlined;
      case DetectionType.lowBattery: return Icons.battery_alert_outlined;
      case DetectionType.proximityAlert: return Icons.spatial_audio_off_outlined;
    }
  }

  String _formatTime(DateTime time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}
