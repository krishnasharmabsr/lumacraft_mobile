import 'package:flutter/material.dart';
import 'features/home/presentation/screens/home_screen.dart';

void main() {
  runApp(const LumaCraftApp());
}

class LumaCraftApp extends StatelessWidget {
  const LumaCraftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LumaCraft',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
