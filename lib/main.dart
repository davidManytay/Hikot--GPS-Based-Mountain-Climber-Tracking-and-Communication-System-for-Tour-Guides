import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize services
  final settings = SettingsService();
  await settings.init();

  runApp(const HikotApp());
}

class HikotApp extends StatelessWidget {
  const HikotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hikot - Hiking Safety',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const HomeScreen(),
    );
  }
}
