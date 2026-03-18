import 'package:flutter/material.dart';
import 'package:philips_tv_flutter/widgets/brightness_controller.dart';
import 'package:philips_tv_flutter/widgets/screen_capture.dart';
import 'package:philips_tv_flutter/widgets/screen_rotation.dart';
import 'package:philips_tv_flutter/widgets/volume_controller.dart';
import 'screens/watchdog_screen.dart';

class HomePage extends StatelessWidget {
  //const HomePage({super.key});

  final GlobalKey _screenshotKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Wauly Watchdog Monitor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: RepaintBoundary(
        key: _screenshotKey,  // Key is attached here
        child: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Subtitle
            Text(
              'Monitor Wauly app events in real-time',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 30,
              ),
            ),
            const SizedBox(height: 100),

                        // Features Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Device Controls',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Volume Controller
            const VolumeController(),

            // Screen Rotation
            // const ScreenRotation(),

            // Screen Capture
            ScreenCapture(screenshotKey: _screenshotKey),

            // Brightness Controller
            // const BrightnessController(),

            const SizedBox(height: 20),

            // Button to open Watchdog
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const WatchdogScreen()),
                );
              },
              icon: const Icon(Icons.play_arrow, color: Colors.black),
              label: const Text(
                'Open Watchdog',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }
}
