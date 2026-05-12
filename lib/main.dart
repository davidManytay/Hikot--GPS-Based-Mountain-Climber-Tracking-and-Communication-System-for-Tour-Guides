import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final settings = SettingsService();
  await settings.init();

  runApp(const HikotApp());
}

class HikotApp extends StatelessWidget {
  const HikotApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService();
    
    return ListenableBuilder(
      listenable: settings,
      builder: (context, child) {
        return MaterialApp(
          title: 'Hikot - Hiking Safety',
          debugShowCheckedModeBanner: false,
          theme: settings.isDarkMode ? HikotTheme.darkTheme : HikotTheme.lightTheme,
          home: const WelcomeScreen(),
        );
      },
    );
  }
}
