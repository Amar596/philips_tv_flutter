import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/device_control.dart';
import 'package:philips_tv_flutter/widgets/brightness_controller.dart';
import 'package:philips_tv_flutter/widgets/device_details.dart';
import 'package:philips_tv_flutter/widgets/hdmi_control.dart';
import 'package:philips_tv_flutter/widgets/screen_capture.dart';
import 'package:philips_tv_flutter/widgets/screen_rotation.dart';
import 'package:philips_tv_flutter/widgets/terminal_overlay.dart';
import 'package:philips_tv_flutter/widgets/usb_control.dart';
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

  String _totalStorage = 'Calculating...';
  String _freeStorage = 'Calculating...';

  String _appVersion = '';
  String _currentDateTime = '';
  late final Timer _timer;

  // NEW: Auto-open toggle variable
  bool _autoOpenEnabled = true;
  bool _isLoaded = false;
  static const String KEY_AUTO_OPEN_ENABLED = 'auto_open_wauly_enabled';
  static const platform = MethodChannel('storage_info');

  //OverlayEntry? _terminalOverlay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initVersion();
    _startClock();
    _getStorageInfo();
    _loadAutoOpenSetting().then((_) {
      if (_autoOpenEnabled) {
        _autoClickOpenWaulyApp();
      }
    });
    _checkAppUpdate();
  }

  // ✅ FIXED: Parse GB-formatted strings back to bytes for progress bar ratio
  double _parseStorageValue(String formatted) {
    try {
      final parts = formatted.split(' ');
      if (parts.length < 2) return 0;
      final value = double.tryParse(parts[0]) ?? 0;
      switch (parts[1]) {
        case 'GB':
          return value * 1024 * 1024 * 1024;
        case 'MB':
          return value * 1024 * 1024;
        case 'KB':
          return value * 1024;
        default:
          return value;
      }
    } catch (_) {
      return 0;
    }
  }

  // ✅ FIXED: Use native StorageInfo channel which returns accurate bytes
  Future<void> _getStorageInfo() async {
    try {
      final Map result = await platform.invokeMethod('getStorage');

      final double totalBytes = (result['total'] as num).toDouble();
      final double freeBytes = (result['free'] as num).toDouble();

      if (totalBytes <= 0) throw Exception("Invalid storage data from native");

      final double totalGB = totalBytes / (1024 * 1024 * 1024);
      final double freeGB = freeBytes / (1024 * 1024 * 1024);

      setState(() {
        _totalStorage = '${totalGB.toStringAsFixed(2)} GB';
        _freeStorage = '${freeGB.toStringAsFixed(2)} GB';
      });
    } catch (e) {
      debugPrint("Storage error: $e");
      setState(() {
        _totalStorage = 'Unavailable';
        _freeStorage = 'Unavailable';
      });
    }
  }

  Future<void> _loadAutoOpenSetting() async {
    final prefs = await SharedPreferences.getInstance();
    _autoOpenEnabled = prefs.getBool(KEY_AUTO_OPEN_ENABLED) ?? true;

    // setState(() {
    //   _isLoaded = true;
    // });
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
      _getStorageInfo();
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

  Widget _buildRotationButton(String label, int angle) {
    return ElevatedButton(
      onPressed: () async {
        await DeviceControl.setScreenRotation(angle);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Screen rotated to ${label}')),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        minimumSize: const Size(70, 35),
      ),
      child: Text(label),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 10),
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
            const SizedBox(height: 6),
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
              const SizedBox(height: 0),
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
                    const SizedBox(height: 5),
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

              // Storage Information Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.storage,
                              color: Colors.orangeAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Device Storage',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Total Space',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(_totalStorage,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Available Space',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                                const SizedBox(height: 1),
                                Text(_freeStorage,
                                    style: const TextStyle(
                                        color: Colors.lightGreenAccent,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    LinearProgressIndicator(
                      value: (_freeStorage != 'Calculating...' &&
                              _freeStorage != 'Unavailable' &&
                              _totalStorage != 'Calculating...' &&
                              _totalStorage != 'Unavailable' &&
                              _parseStorageValue(_totalStorage) > 0)
                          ? (_parseStorageValue(_totalStorage) -
                                  _parseStorageValue(_freeStorage)) /
                              _parseStorageValue(
                                  _totalStorage) // shows USED space (conventional)
                          : 0,
                      backgroundColor: Colors.grey[800],
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.orangeAccent),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 0),

// Device Controls Section
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2027),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: Colors.purpleAccent.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.devices,
                              color: Colors.purpleAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Device Controls',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Backlight Control Row
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DeviceControl.turnScreenOff();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Screen turned OFF')),
                              );
                            },
                            icon: const Icon(Icons.brightness_low,
                                color: Colors.white),
                            label: const Text('Screen OFF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await DeviceControl.turnScreenOn();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Screen turned ON')),
                              );
                            },
                            icon: const Icon(Icons.brightness_high,
                                color: Colors.white),
                            label: const Text('Screen ON'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade800,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Brightness Slider
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Brightness',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        FutureBuilder<int>(
                          future: DeviceControl.getBrightness(),
                          builder: (context, snapshot) {
                            return Row(
                              children: [
                                const Icon(Icons.brightness_low,
                                    color: Colors.white70, size: 20),
                                Expanded(
                                  child: Slider(
                                    value: (snapshot.data ?? 50).toDouble(),
                                    min: 0,
                                    max: 100,
                                    activeColor: Colors.purpleAccent,
                                    onChanged: (value) async {
                                      await DeviceControl.setBrightness(
                                          value.toInt());
                                      setState(() {});
                                    },
                                  ),
                                ),
                                const Icon(Icons.brightness_high,
                                    color: Colors.white70, size: 20),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black26,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${snapshot.data ?? 50}%',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Screen Rotation Buttons
                    const Text(
                      'Screen Rotation',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRotationButton('0°', 0),
                        _buildRotationButton('90°', 90),
                        _buildRotationButton('180°', 180),
                        _buildRotationButton('270°', 270),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Get Device Details Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        await _showDeviceDetailsDialog();
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('Show Device Details'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 40),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // USB Control Section
              const UsbControl(),
              const HdmiControl(),

              // Features Section
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
              ),

              const SizedBox(height: 1),

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

              const SizedBox(height: 2),

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
                          'Watchdog',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Open Wauly App Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await WaulyAppManager.handleAppFlow(context);
                        },
                        icon:
                            const Icon(Icons.tv, color: Colors.white, size: 18),
                        label: const Text(
                          'Wauly',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3748),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Shutdown button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => DeviceControl.shutdown(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Shutdown",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Reboot button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => DeviceControl.reboot(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          "Reboot",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  

  Future<void> _showDeviceDetailsDialog() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      final deviceDetails = {
        'App Version': '${packageInfo.version} (${packageInfo.buildNumber})',
        'Platform': Platform.operatingSystem,
        'OS Version': Platform.operatingSystemVersion,
        'Hostname': Platform.localHostname,
        'Processors': Platform.numberOfProcessors.toString(),
        'Locale': Platform.localeName,
        'Dart Version': Platform.version.split(' ').first,
        'Free Storage': _freeStorage,
        'Total Storage': _totalStorage,
        'Current Time': _currentDateTime,
      };

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF161B22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.devices, color: Colors.blueAccent),
              SizedBox(width: 8),
              Text(
                'Device Details',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: deviceDetails.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 120,
                          child: Text(
                            '${entry.key}:',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            entry.value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.greenAccent),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing device details: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load device details: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
