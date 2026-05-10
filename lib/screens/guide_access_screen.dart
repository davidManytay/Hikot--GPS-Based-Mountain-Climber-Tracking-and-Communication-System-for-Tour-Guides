import 'dart:ui';
import 'package:flutter/material.dart';
import 'home_screen.dart';

class GuideAccessScreen extends StatefulWidget {
  const GuideAccessScreen({super.key});

  @override
  State<GuideAccessScreen> createState() => _GuideAccessScreenState();
}

class _GuideAccessScreenState extends State<GuideAccessScreen> {
  String _pin = "";
  final String _correctPin = "1234";
  bool _isError = false;

  void _onKeyTap(String val) {
    if (_pin.length < 4) {
      setState(() {
        _pin += val;
        _isError = false;
      });
      if (_pin.length == 4) {
        _verifyPin();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  void _verifyPin() {
    if (_pin == _correctPin) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      setState(() {
        _pin = "";
        _isError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: Stack(
        children: [
          // Background Glow
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.05),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                // Header
                const Icon(Icons.security_rounded, color: Colors.blueAccent, size: 48),
                const SizedBox(height: 24),
                const Text(
                  'GUIDE ACCESS',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 4),
                ),
                Text(
                  'MISSION CONTROL AUTHENTICATION',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                
                const SizedBox(height: 60),
                
                // PIN Display
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    bool isFilled = index < _pin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 12),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? Colors.blueAccent : Colors.white.withOpacity(0.05),
                        border: Border.all(color: _isError ? Colors.redAccent : Colors.blueAccent.withOpacity(0.3)),
                        boxShadow: isFilled ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 10)] : null,
                      ),
                    );
                  }),
                ),
                
                if (_isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text('INVALID ACCESS CODE', style: TextStyle(color: Colors.redAccent.withOpacity(0.8), fontSize: 10, fontWeight: FontWeight.bold)),
                  ),

                const Spacer(),
                
                // Keypad
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  child: Column(
                    children: [
                      _buildRow(['1', '2', '3']),
                      _buildRow(['4', '5', '6']),
                      _buildRow(['7', '8', '9']),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          const SizedBox(width: 80),
                          _buildKey('0'),
                          _buildIconButton(Icons.backspace_outlined, _onDelete),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(List<String> keys) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: keys.map((k) => _buildKey(k)).toList(),
      ),
    );
  }

  Widget _buildKey(String val) {
    return InkWell(
      onTap: () => _onKeyTap(val),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          color: Colors.white.withOpacity(0.02),
        ),
        child: Center(
          child: Text(
            val,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w300),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: SizedBox(
        width: 80,
        height: 80,
        child: Icon(icon, color: Colors.white.withOpacity(0.5), size: 24),
      ),
    );
  }
}
