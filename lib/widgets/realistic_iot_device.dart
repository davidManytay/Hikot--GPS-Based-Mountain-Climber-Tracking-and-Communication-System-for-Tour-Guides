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
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 4,
                    offset: const Offset(-2, 0),
                  ),
                ],
              ),
            ),
          ),
          
          // Main Body Casing (Matte Black)
          Container(
            width: 320, // Increased width
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A), // Matte black casing
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.black, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.05),
                  blurRadius: 1,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // OLED Screen
                _buildOledScreen(),
                const SizedBox(height: 28),
                
                // LEDs
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildLed('Mesh', isMeshActive ? const Color(0xFF2DD4BF) : Colors.teal.withOpacity(0.2)),
                    _buildLed('GPS', hasGps ? const Color(0xFF3B82F6) : Colors.blue.withOpacity(0.2)),
                    _buildLed('Battery', batteryLevel > 20 ? const Color(0xFFFACC15) : Colors.redAccent),
                  ],
                ),
                const SizedBox(height: 36),
                
                // SOS Button
                _buildSosButton(),
                
                const SizedBox(height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOledScreen() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _oledText('ID:   $nodeId', const Color(0xFF2DD4BF)),
          const SizedBox(height: 6),
          _oledText('GPS:  ${hasGps ? 'OK' : 'SEARCHING'}', const Color(0xFF2DD4BF)),
          const SizedBox(height: 6),
          _oledText('BAT:  $batteryLevel%', const Color(0xFFFACC15)),
          const SizedBox(height: 6),
          _oledText('MESH: $meshHops HOP', const Color(0xFF2DD4BF)),
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
        fontSize: 20, // Slightly larger text
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildLed(String label, Color color) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              if (color.opacity > 0.3)
                BoxShadow(
                  color: color.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
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
          // Button Glow/Shadow
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDC2626).withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
          ),
          
          // Progress Ring
          if (sosProgress > 0)
            SizedBox(
              width: 140,
              height: 140,
              child: CircularProgressIndicator(
                value: sosProgress,
                strokeWidth: 8,
                color: const Color(0xFFDC2626),
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),

          // Main Button Body
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                center: Alignment(-0.2, -0.3),
                radius: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: isSending
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: CircularProgressIndicator(strokeWidth: 4, color: Colors.white),
                    )
                  : const Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
