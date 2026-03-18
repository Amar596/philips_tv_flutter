import 'package:flutter/material.dart';
import 'screens/watchdog_screen.dart';

void main() {
  runApp(const WatchdogApp());
}

class WatchdogApp extends StatelessWidget {
  const WatchdogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wauly Watchdog',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          primary: Colors.greenAccent,
          secondary: Colors.cyanAccent,
        ),
      ),
      home: const WatchdogScreen(),
    );
  }
}
