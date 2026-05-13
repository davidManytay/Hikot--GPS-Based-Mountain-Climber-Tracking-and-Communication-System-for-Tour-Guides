import 'package:flutter/material.dart';

class RealisticIotDevice extends StatelessWidget {
  final String nodeId;
  final bool hasGps;
  final int batteryLevel;
  final int meshHops;
  final bool isMeshActive;
  final double sosProgress;
  final bool isSending;
  final VoidCallback onSosDown;
  final VoidCallback onSosUp;

  const RealisticIotDevice({
    super.key,
    required this.nodeId,
    required this.hasGps,
    required this.batteryLevel,
    required this.meshHops,
    required this.isMeshActive,
    this.sosProgress = 0,
    this.isSending = false,
    required this.onSosDown,
    required this.onSosUp,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Side Button (Red)
          Positioned(
            left: 0,
            top: 180,
            child: Container(
              width: 12,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
            ),
          ),
          
          // Main Body Casing (Black Outer)
          Container(
            width: 270,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(35),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Container(
              // Inner Faceplate (Grey)
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              decoration: BoxDecoration(
                color: const Color(0xFFCCCCCC), // Light grey faceplate
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // OLED Screen
                  _buildOledScreen(),
                  const SizedBox(height: 24),
                  
                  // LEDs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildLed('Mesh', isMeshActive ? const Color(0xFF4ADE80) : Colors.green.withOpacity(0.3)),
                      _buildLed('GPS', hasGps ? const Color(0xFF3B82F6) : Colors.blue.withOpacity(0.3)),
                      _buildLed('Battery', batteryLevel > 20 ? const Color(0xFFFACC15) : Colors.redAccent),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // SOS Button
                  _buildSosButton(),
                  
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOledScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF000000), // Pure black
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _oledText('ID:    $nodeId', const Color(0xFF4ADE80)),
          const SizedBox(height: 4),
          _oledText('GPS:   ${hasGps ? 'OK' : '...' }', const Color(0xFF4ADE80)),
          const SizedBox(height: 4),
          _oledText('BAT:   $batteryLevel%', const Color(0xFFFACC15)),
          const SizedBox(height: 4),
          _oledText('MESH:  $meshHops HOP', const Color(0xFF4ADE80)),
        ],
      ),
    );
  }

  Widget _oledText(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontFamily: 'monospace',
        fontSize: 18,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildLed(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.black.withOpacity(0.1), width: 1),
            boxShadow: [
              if (color.opacity > 0.5)
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666666), 
            fontSize: 12, 
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSosButton() {
    return GestureDetector(
      onTapDown: (_) => onSosDown(),
      onTapUp: (_) => onSosUp(),
      onTapCancel: () => onSosUp(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer SOS Border (Grey)
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF555555), // Dark grey border
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          
          // Progress Ring
          if (sosProgress > 0)
            SizedBox(
              width: 144,
              height: 144,
              child: CircularProgressIndicator(
                value: sosProgress,
                strokeWidth: 6,
                color: Colors.white,
                backgroundColor: Colors.transparent,
              ),
            ),

          // Main Button Body
          Container(
            width: 128,
            height: 128,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEF4444), // Bright red
            ),
            child: Center(
              child: isSending
                  ? const SizedBox(
                      width: 40,
                      height: 40,
                      child: CircularProgressIndicator(strokeWidth: 5, color: Colors.white),
                    )
                  : const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.0,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
