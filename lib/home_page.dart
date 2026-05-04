import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/widgets/brightness_controller.dart';
import 'package:philips_tv_flutter/widgets/device_details.dart';
import 'package:philips_tv_flutter/widgets/screen_capture.dart';
import 'package:philips_tv_flutter/widgets/screen_rotation.dart';
import 'package:philips_tv_flutter/widgets/terminal_overlay.dart';
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
import 'package:shared_preferences/shared_preferences.dart';
import 'services/remote_key_service.dart';
import 'widgets/key_feedback_overlay.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  bool _isOpeningApp = false;

  String _appVersion = '';
  String _currentDateTime = '';
  late final Timer _timer;

  // NEW: Auto-open toggle variable
  bool _autoOpenEnabled = true;
  bool _isLoaded = false;
  static const String KEY_AUTO_OPEN_ENABLED = 'auto_open_wauly_enabled';

  //OverlayEntry? _terminalOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVersion();
    _startClock(); 
    _loadAutoOpenSetting().then((_) {
      if (_autoOpenEnabled) {
        _autoClickOpenWaulyApp();
      }
    });
    // _loadAutoOpenSetting();
    // _autoClickOpenWaulyApp();
    _checkAppUpdate();
  }

  Future<void> _loadAutoOpenSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _autoOpenEnabled = prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? true;

    setState(() {
      _isLoaded = true;
    });
  }

// Add this method to save setting
  Future<void> _saveAutoOpenSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_AUTO_OPEN_ENABLED, value);
    print('💾 Auto-open setting saved: $value');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && mounted) {
      // ✅ Only trigger if toggle is enabled
      if (!_autoOpenEnabled) {
        print('⏸️ Resume ignored - auto-open disabled');
        return;
      }

      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted && _autoOpenEnabled) {
          print('🔄 App resumed - auto opening Wauly app');
          _autoClickOpenWaulyApp();
        }
      });
    }
  }

  Future<void> _initVersion() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${info.version} (${info.buildNumber})';
    });
  }

  void _startClock() {
    _updateTime(); // initial call

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateTime();
      }
    });
  }

  void _updateTime() {
    final now = DateTime.now();
    final formatted = DateFormat('dd MMM yyyy | hh:mm:ss a').format(now);

    setState(() {
      _currentDateTime = formatted;
    });
  }

  Future<void> _autoClickOpenWaulyApp() async {
    // ✅ HARD STOP
    if (!_autoOpenEnabled) {
      print('⛔ Auto-open disabled — skipping execution');
      return;
    }

    if (_isOpeningApp) {
      print('⏸️ Already opening Wauly app, skipping...');
      return;
    }

    _isOpeningApp = true;

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted && _autoOpenEnabled) {
      print('🤖 Auto-clicking Open Wauly App button (homepage active)');
      await WaulyAppManager.handleAppFlow(context);
    }

    _isOpeningApp = false;
  }

  @override
  void dispose() {
    _timer.cancel();
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
    // Get current URLs
    final currentVersionUrl = WaulyAppManager.versionUrl;
    final currentApkUrl = WaulyAppManager.apkUrl;

    final versionController = TextEditingController(text: currentVersionUrl);
    final apkController = TextEditingController(text: currentApkUrl);

    final shouldUseAzure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text(
          'Configure Update URLs',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Version XML URL:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: versionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://.../version.xml',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
                prefixIcon: const Icon(Icons.link, color: Colors.greenAccent),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            const Text(
              'APK Download URL:',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: apkController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'https://.../app.apk',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                border: const OutlineInputBorder(),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.greenAccent),
                ),
                prefixIcon:
                    const Icon(Icons.cloud_download, color: Colors.greenAccent),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade900.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade700),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_queue,
                      color: Colors.blue.shade300, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Azure Default',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml',
                          style: TextStyle(
                              color: Colors.blue.shade300, fontSize: 10),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final versionUrl = versionController.text.trim();
              final apkUrl = apkController.text.trim();

              if (versionUrl.isNotEmpty && apkUrl.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                // Show error if URLs are empty
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter both URLs'),
                    backgroundColor: Colors.red,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldUseAzure == true) {
      // Build URLs from the text fields
      final versionUrl = versionController.text.trim();
      final apkUrl = apkController.text.trim();

      // Update URLs
      WaulyAppManager.versionUrl = versionUrl;
      WaulyAppManager.apkUrl = apkUrl;

      // Save to SharedPreferences if needed
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(WaulyAppManager.KEY_CUSTOM_VERSION_URL, versionUrl);
      await prefs.setString(WaulyAppManager.KEY_CUSTOM_APK_URL, apkUrl);

      // Show confirmation
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Custom URLs saved successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Test connection
      await _testConnection();

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
          'Monitor Wauly app events in real-time',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        // Add connection indicator to app bar
        actions: [
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
              // Text(
              //   'Monitor Wauly app events in real-time',
              //   style: TextStyle(
              //     color: Colors.white.withOpacity(0.6),
              //     fontSize: 30,
              //   ),
              // ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: Colors.greenAccent, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Signage App Status',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Version: $_appVersion',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: $_currentDateTime',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Status Overlay (shown during updates/checks)
              if (_isChecking)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),

              // ✅ ALWAYS SHOW TOGGLE (moved outside condition)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _autoOpenEnabled
                        ? [
                            Colors.green.shade900.withOpacity(0.3),
                            const Color(0xFF161B22)
                          ]
                        : [
                            Colors.grey.shade900.withOpacity(0.3),
                            const Color(0xFF161B22)
                          ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _autoOpenEnabled
                        ? Colors.greenAccent
                        : Colors.grey.shade700,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _autoOpenEnabled ? Icons.touch_app : Icons.block,
                      color:
                          _autoOpenEnabled ? Colors.greenAccent : Colors.grey,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _autoOpenEnabled
                            ? 'Signage App - Auto launch ENABLED'
                            : 'Signage App - Auto launch DISABLED',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    Switch(
                      value: _autoOpenEnabled,
                      onChanged: (bool value) async {
                        setState(() {
                          _autoOpenEnabled = value;
                        });
                        await _saveAutoOpenSetting(value);

                        if (value) {
                          // Optional: trigger once immediately when turned ON
                          _autoClickOpenWaulyApp();
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 0),

              // Features Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),

              const SizedBox(height: 10),

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
