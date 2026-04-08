import 'package:flutter/material.dart';
import 'package:philips_tv_flutter/services/wauly_app_service.dart';
import 'screens/watchdog_screen.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'home_page.dart';

void main() async{
    WidgetsFlutterBinding
      .ensureInitialized(); 

      final hasPending = await WaulyAppManager.checkAndResumePendingInstallation();

  if (hasPending) {
    // App will exit after installation, no need to continue
    return;
  }
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final path = join(documentsDirectory.path, 'events.db');
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
      home: HomePage(),
    );
  }
}
