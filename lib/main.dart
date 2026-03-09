import 'package:flutter/material.dart';

void main() {
  runApp(const ZylenCutApp());
}

class ZylenCutApp extends StatelessWidget {
  const ZylenCutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZylenCut',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ZylenCut Studio')),
      body: const Center(child: Text('V2 Bootstrap Environment')),
    );
  }
}
