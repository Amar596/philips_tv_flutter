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
import 'package:xml/xml.dart';
import 'package:http/http.dart' as http;
import 'dart:math' as math;
import 'services/wauly_app_service.dart';
import 'screens/settings_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GlobalKey _screenshotKey = GlobalKey();

    // Add these variables
  bool _isChecking = false;
  String _statusMessage = '';
  String _statusDetails = '';
 
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
      _checkAppUpdate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Show status overlay
  void _showStatusOverlay(
      {required bool show, String? message, String? details}) {
    setState(() {
      _isChecking = show;
      _statusMessage = message ?? '';
      _statusDetails = details ?? '';
    });
  }

  Future<void> _checkAppUpdate() async {
    _showStatusOverlay(
      show: true,
      message: 'Checking for updates...',
      details: 'Connecting to ${WaulyAppManager.versionUrl}',
    );

    try {
      await WaulyAppManager.handleAppFlow(context);
    } catch (e) {
      _showStatusOverlay(
        show: true,
        message: 'Update check failed',
        details: e.toString(),
      );
      await Future.delayed(const Duration(seconds: 3));
    } finally {
      if (mounted) {
        _showStatusOverlay(show: false);
      }
    }
  }

  Future<void> _openWaulyApp(String packageName) async {  
    const activityName = 'com.example.wauly_app.MainActivity';

    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: packageName,
      category: 'android.intent.category.LAUNCHER',
      componentName: activityName,
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    await intent.launch();
    debugPrint('✅ Wauly app launched');
  }

  // Quick IP dialog for temporary changes (only IP input)
  Future<void> _showQuickUrlDialog() async {
    // Extract current IP from URL
    String extractIp(String url) {
      try {
        final uri = Uri.parse(url);
        return '${uri.host}:${uri.port}';
      } catch (e) {
        return '192.168.0.169:8080';
      }
    }

    final currentIp = extractIp(WaulyAppManager.versionUrl);
    final controller = TextEditingController(text: currentIp);

    final ip = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Enter Server IP',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: '192.168.0.169:8080',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
                prefixIcon: const Icon(Icons.dns, color: Colors.greenAccent),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 8),
            Text(
              'Version URL: http://${controller.text}/version.xml',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ip = controller.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(context, ip);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Use'),
          ),
        ],
      ),
    );

    if (ip != null && ip.isNotEmpty) {
      // Build URLs from IP
      final versionUrl = 'http://$ip/version.xml';
      final apkUrl = 'http://$ip/WaulySignage.apk';

      // Update URLs
      WaulyAppManager.versionUrl = versionUrl;
      WaulyAppManager.apkUrl = apkUrl;

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Using server: $ip'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Refresh the UI
      setState(() {});
    }
  }

  // Show server info dialog
  Future<void> _showServerInfo() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.greenAccent),
            SizedBox(width: 8),
            // Text(
            //   'Server Configuration',
            //   style: TextStyle(color: Colors.white),
            // ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current Version URL:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                WaulyAppManager.versionUrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Current APK URL:',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                WaulyAppManager.apkUrl,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/settings');
            },
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  // Test connection with status
  Future<void> _testConnection() async {
    _showStatusOverlay(
      show: true,
      message: 'Testing connection...',
      details: 'Connecting to ${WaulyAppManager.versionUrl}',
    );

    try {
      final versionInfo = await WaulyAppManager.fetchLatestVersion();
      if (versionInfo != null) {
        _showStatusOverlay(
          show: true,
          message: 'Connection successful!',
          details: 'Latest version: ${versionInfo.version}',
        );
      } else {
        _showStatusOverlay(
          show: true,
          message: 'Connection failed',
          details: 'Could not fetch version info',
        );
      }
    } catch (e) {
      _showStatusOverlay(
        show: true,
        message: 'Connection failed',
        details: e.toString(),
      );
    }

    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      _showStatusOverlay(show: false);
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
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.cloud_outlined, color: Colors.greenAccent),
          //   onPressed: _showServerInfo,
          //   tooltip: 'Server Configuration',
          // ),
          //Settings button
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              Navigator.pushNamed(context, '/settings');
            },
            tooltip: 'Settings',
          ),
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

                            // Server URL indicator
              // Container(
              //   margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              //   padding:
              //       const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF161B22),
              //     borderRadius: BorderRadius.circular(8),
              //     border: Border.all(color: Colors.grey.shade800),
              //   ),
              //   child: Row(
              //     mainAxisSize: MainAxisSize.min,
              //     children: [
              //       Icon(Icons.link,
              //           size: 14, color: Colors.greenAccent.shade400),
              //       const SizedBox(width: 8),
              //       Flexible(
              //         child: Text(
              //           WaulyAppManager.versionUrl,
              //           style: const TextStyle(
              //             color: Colors.white70,
              //             fontSize: 11,
              //             fontFamily: 'monospace',
              //           ),
              //           overflow: TextOverflow.ellipsis,
              //         ),
              //       ),
              //       const SizedBox(width: 8),
              //       InkWell(
              //         onTap: _showQuickUrlDialog,
              //         child: Icon(
              //           Icons.edit,
              //           size: 14,
              //           color: Colors.blue.shade300,
              //         ),
              //       ),
              //     ],
              //   ),
              // ),

              // Status Overlay (shown during updates/checks)
              if (_isChecking)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent.shade700),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.greenAccent),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _statusMessage,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_statusDetails.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          _statusDetails,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
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
                          await WaulyAppManager.handleAppFlow(context);
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
