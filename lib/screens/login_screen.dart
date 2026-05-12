import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/device_role.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'climber_node_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  final _settings = SettingsService();
  bool _isLoading = false;
  late AnimationController _scanController;
  late HikotDeviceRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = _settings.deviceRole;
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.toLowerCase() != 'david' || password != '123') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid credentials. Use the demo account provided by your administrator.'),
          backgroundColor: HikotColors.error,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    await _auth.login(username);
    await _settings.setDeviceRole(HikotDeviceRole.guideHub);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }

  Future<void> _enterClimberMode() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    await _settings.setDeviceRole(HikotDeviceRole.climberNode);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ClimberNodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/hiker_welcome.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF020617).withOpacity(0.55),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor.withOpacity(0.96),
                      border: Border.all(color: HikotColors.accentTeal.withOpacity(0.45), width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'DEVICE ROLE',
                          style: TextStyle(color: HikotColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
                        ),
                        const SizedBox(height: 12),
                        _buildRoleSelector(),
                        const SizedBox(height: 24),
                        if (_selectedRole == HikotDeviceRole.guideHub) ...[
                          const Text(
                            'OPERATOR AUTHENTICATION',
                            style: TextStyle(color: HikotColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Monitor the team map, head count, mesh health, and SOS alerts.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: HikotColors.textSecondary, fontSize: 15, height: 1.45),
                          ),
                          const SizedBox(height: 24),
                          _buildTacticalField('Username', Icons.account_circle_outlined, _usernameController),
                          const SizedBox(height: 20),
                          _buildTacticalField('Password', Icons.fingerprint_rounded, _passwordController, isPassword: true),
                          const SizedBox(height: 28),
                          _buildLoginButton(),
                        ] else ...[
                          const Text(
                            'MESH NODE',
                            style: TextStyle(color: HikotColors.accentTeal, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Broadcast GPS over BLE, relay packets for others, and hold SOS for 3 seconds for a priority emergency. No guide map on this handset.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: HikotColors.textSecondary, fontSize: 15, height: 1.45),
                          ),
                          const SizedBox(height: 28),
                          _buildClimberContinueButton(),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelector() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<HikotDeviceRole>(
        showSelectedIcon: false,
        style: SegmentedButton.styleFrom(
          backgroundColor: Colors.black.withOpacity(0.35),
          foregroundColor: HikotColors.textSecondary,
          selectedForegroundColor: Colors.white,
          selectedBackgroundColor: HikotColors.surfaceLight,
          side: BorderSide(color: HikotColors.accentTeal.withOpacity(0.35)),
        ),
        segments: const [
          ButtonSegment<HikotDeviceRole>(
            value: HikotDeviceRole.guideHub,
            label: Text('Guide'),
            icon: Icon(Icons.dashboard_customize_outlined, size: 18),
          ),
          ButtonSegment<HikotDeviceRole>(
            value: HikotDeviceRole.climberNode,
            label: Text('Climber'),
            icon: Icon(Icons.hiking_outlined, size: 18),
          ),
        ],
        selected: {_selectedRole},
        onSelectionChanged: _isLoading
            ? null
            : (Set<HikotDeviceRole> next) async {
                final r = next.single;
                await _settings.setDeviceRole(r);
                if (!mounted) return;
                setState(() => _selectedRole = r);
              },
      ),
    );
  }

  Widget _buildClimberContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _enterClimberMode,
        style: ElevatedButton.styleFrom(
          backgroundColor: HikotColors.surfaceLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: HikotColors.accentTeal.withOpacity(0.35)),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text('ENTER CLIMBER MODE', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 14)),
      ),
    );
  }

  Widget _buildTacticalField(String label, IconData icon, TextEditingController controller, {bool isPassword = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 4, height: 4, color: HikotColors.accentTeal),
            const SizedBox(width: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(color: HikotColors.textMuted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _scanController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _FieldBorderPainter(progress: _scanController.value),
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
              ),
              child: TextField(
                controller: controller,
                obscureText: isPassword,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16, height: 1.35),
                cursorColor: HikotColors.accentTeal,
                decoration: InputDecoration(
                  prefixIcon: Icon(icon, color: HikotColors.accentTeal.withOpacity(0.65), size: 22),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: HikotColors.surfaceLight,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            : const Text('SIGN IN', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2, fontSize: 15)),
      ),
    );
  }

}

class _FieldBorderPainter extends CustomPainter {
  final double progress;

  _FieldBorderPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRect(rect, paint);

    final path = Path()..addRect(rect);
    final pathMetrics = path.computeMetrics();

    final strokeColor = Color.lerp(
          HikotColors.accentTeal,
          const Color(0xFF3B82F6),
          math.sin(progress * math.pi * 2).abs(),
        ) ??
        HikotColors.accentTeal;

    for (final metric in pathMetrics) {
      final totalLength = metric.length;
      final extractLength = totalLength * 0.25;
      final start = totalLength * progress;

      final glowPaint = Paint()
        ..color = strokeColor.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      if (start + extractLength <= totalLength) {
        canvas.drawPath(metric.extractPath(start, start + extractLength), glowPaint);
      } else {
        canvas.drawPath(metric.extractPath(start, totalLength), glowPaint);
        canvas.drawPath(metric.extractPath(0, extractLength - (totalLength - start)), glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FieldBorderPainter oldDelegate) => true;
}
