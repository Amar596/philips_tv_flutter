import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/widgets/brightness_controller.dart';
import 'package:philips_tv_flutter/widgets/device_details.dart';
import 'package:philips_tv_flutter/widgets/screen_capture.dart';
import 'package:philips_tv_flutter/widgets/screen_rotation.dart';
import 'package:philips_tv_flutter/widgets/volume_controller.dart';
import 'package:url_launcher/url_launcher.dart';
import 'screens/watchdog_screen.dart';
import 'widgets/simple_connection_indicator.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isOpeningApp = false;

  // ✅ ADD THIS HERE (top of class)
  static const platform = MethodChannel('apk_install');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> installApk(String filePath) async {
    try {
      await platform.invokeMethod('installApk', {
        "path": filePath,
      });
    } catch (e) {
      debugPrint("Install error: $e");
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('App lifecycle state: $state');

    // Reset opening flag when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      debugPrint("App is back to foreground");
      setState(() {
        _isOpeningApp = false;
      });
    }
  }

  Future<void> _openOrInstallWaulyApp(BuildContext context) async {
    const packageName = 'com.example.wauly_app';
    const activityName = 'com.example.wauly_app.MainActivity';
    const apkUrl = 'http://192.168.0.169:8080/WaulySignage.apk';

    try {
      // ✅ Check if app installed
      final checkIntent = AndroidIntent(
        action: 'android.intent.action.MAIN',
        package: packageName,
      );

      final isInstalled = await checkIntent.canResolveActivity() ?? false;

      if (isInstalled) {
        // ✅ Open app
        final intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          package: packageName,
          category: 'android.intent.category.LAUNCHER',
          componentName: activityName,
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );

        await intent.launch();
        debugPrint('✅ Wauly app launched');
      } else {
        debugPrint('❌ Wauly not installed → downloading APK');

        // ✅ Get storage directory
        final dir = await getExternalStorageDirectory();

        // ❌ NOT const
        final filePath = '${dir!.path}/wauly.apk';

        // ✅ Download APK
        await Dio().download(apkUrl, filePath);
        debugPrint('✅ APK downloaded at: $filePath');
        await installApk(filePath);

        // // ✅ Install APK
        // final installIntent = AndroidIntent(
        //   action: 'android.intent.action.VIEW',
        //   data: Uri.file(filePath).toString(),
        //   type: 'application/vnd.android.package-archive',
        //   flags: <int>[
        //     Flag.FLAG_ACTIVITY_NEW_TASK,
        //     Flag.FLAG_GRANT_READ_URI_PERMISSION,
        //   ],
        // );

        // await installIntent.launch();
      }
    } catch (e) {
      debugPrint('🔥 Error: $e');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

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
        // Add connection indicator to app bar
        actions: const [
          SimpleConnectionIndicator(compact: true),
          SizedBox(width: 16),
        ],
      ),
      body: RepaintBoundary(
        key: _screenshotKey, // Key is attached here
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
              const SizedBox(height: 10),

              // Features Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),

              const SizedBox(height: 16),

              // Device Details Section
              const DeviceDetails(),

              // Volume Controller
              const VolumeController(),

              // Screen Rotation
              // const ScreenRotation(),

              // Screen Capture
              ScreenCapture(screenshotKey: _screenshotKey),

              // Brightness Controller
              // const BrightnessController(),

              const SizedBox(height: 20),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Open Watchdog Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WatchdogScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.play_arrow, color: Colors.black),
                        label: const Text(
                          'Open Watchdog',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Open Wauly App Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await _openOrInstallWaulyApp(context);
                        },
                        icon: const Icon(Icons.tv, color: Colors.white),
                        label: const Text(
                          'Open Wauly App',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3748),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    )
                  ],
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
