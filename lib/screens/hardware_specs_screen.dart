import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HardwareSpecsScreen extends StatelessWidget {
  const HardwareSpecsScreen({super.key});

  static const String _deviceImageAsset = 'assets/climber_iot_device.png';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('NODE ARCHITECTURE', style: HikotTextStyles.label.copyWith(color: Theme.of(context).colorScheme.onSurface)),
        centerTitle: true,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Image.asset(
              _deviceImageAsset,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
