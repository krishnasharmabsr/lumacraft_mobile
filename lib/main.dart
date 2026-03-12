import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/services/revenuecat_service.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RevenueCatService.init();
  runApp(const LumaCraftApp());
}

class LumaCraftApp extends StatelessWidget {
  const LumaCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumaCraft',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
