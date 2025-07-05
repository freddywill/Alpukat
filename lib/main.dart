import 'package:flutter/material.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const AlpukatDetectorApp());
}

class AlpukatDetectorApp extends StatelessWidget {
  const AlpukatDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Deteksi Daun Alpukat',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}
