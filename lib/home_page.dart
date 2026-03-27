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

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class AppVersionInfo {
  final String version;
  final String exeUrl;
  final String fileName;

  AppVersionInfo({
    required this.version,
    required this.exeUrl,
    required this.fileName,
  });
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final GlobalKey _screenshotKey = GlobalKey();
  bool _isOpeningApp = false;
  bool _isProcessing = false;
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

  Future<String?> getInstalledAppVersion(String packageName) async {
    try {
      final version = await platform.invokeMethod('getPackageVersion', {
        'packageName': packageName,
      });

      if (version == null) {
        debugPrint('ℹ️ Package $packageName is not installed');
      } else {
        debugPrint('✅ Package $packageName is installed, version: $version');
      }

      return version as String?;
    } catch (e) {
      debugPrint('Error getting version: $e');
      return null;
    }
  }

  Future<AppVersionInfo?> fetchLatestVersionInfo() async {
    try {
      const versionUrl = 'http://192.168.0.169:8080/version.xml';
      debugPrint('🔍 Fetching version from: $versionUrl');

      final response = await http.get(Uri.parse(versionUrl));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📄 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        debugPrint('✅ XML parsed successfully');

        final updateElement = document.findAllElements('Update').first;

        final version = updateElement.findElements('Version').first.text;
        final exeUrl = updateElement.findElements('ExeUrl').first.text;
        final fileName = updateElement.findElements('FileName').first.text;

        debugPrint('📱 Version from server: $version');
        debugPrint('📦 ExeUrl: $exeUrl');
        debugPrint('📁 FileName: $fileName');

        return AppVersionInfo(
          version: version,
          exeUrl: exeUrl,
          fileName: fileName,
        );
      } else {
        debugPrint(
            '❌ Failed to fetch XML. Status code: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching version info: $e');
      return null;
    }
  }

  bool isNewerVersion(String currentVersion, String latestVersion) {
    try {
      final currentParts = currentVersion.split('.').map(int.parse).toList();
      final latestParts = latestVersion.split('.').map(int.parse).toList();

      for (int i = 0;
          i < math.min(currentParts.length, latestParts.length);
          i++) {
        if (latestParts[i] > currentParts[i]) return true;
        if (latestParts[i] < currentParts[i]) return false;
      }

      return latestParts.length > currentParts.length;
    } catch (e) {
      debugPrint('Error parsing versions: $e');
      return false; // If parsing fails, assume no update
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

  // Helper methods
  Future<void> _downloadAndInstallApk(String apkUrl, String fileName) async {
    // Request install permission for Android 8+
    if (await Permission.requestInstallPackages.isDenied) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) {
        throw Exception('Install permission denied');
      }
    }

    // Get storage directory
    final dir = await getExternalStorageDirectory();
    final filePath = '${dir!.path}/$fileName';

    // Download APK
    await Dio().download(apkUrl, filePath);
    debugPrint('✅ APK downloaded at: $filePath');

    // Install APK
    await installApk(filePath);
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

  Future<bool> _showUpdateDialog(
      BuildContext context, String currentVersion, String newVersion) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: Text('Version $newVersion is available.\n'
                'Current version: $currentVersion\n\n'
                'Would you like to update?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child:
                    const Text('Update', style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        ) ??
        false;
  }

// Fallback method if version check fails
  Future<void> _openOrInstallFallback(BuildContext context) async {
    const packageName = 'com.example.wauly_app';
    const apkUrl = 'http://192.168.0.169:8080/WaulySignage.apk';

    // Check if app installed
    final checkIntent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: packageName,
    );

    final isInstalled = await checkIntent.canResolveActivity() ?? false;

    if (isInstalled) {
      await _openWaulyApp(packageName);
    } else {
      await _downloadAndInstallApk(apkUrl, 'wauly.apk');
    }
  }

  Future<void> _openOrInstallWaulyApp(BuildContext context) async {
    if (_isProcessing) {
      debugPrint('⚠️ Already processing, ignoring request');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please wait, operation in progress...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      return;
    }

    _isProcessing = true;
    const packageName = 'com.example.wauly_app';

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Checking for updates...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Step 1: Get installed app version
      final installedVersion = await getInstalledAppVersion(packageName);
      debugPrint(
          '📱 Installed version: ${installedVersion ?? "NOT INSTALLED"}');

      // Step 2: Fetch latest version info from server
      final latestInfo = await fetchLatestVersionInfo();

      // If version info fetch failed
      if (latestInfo == null) {
        debugPrint('⚠️ Could not fetch version info from server');

        if (installedVersion != null) {
          // App is installed, just open it
          debugPrint('✅ App is installed, opening without version check');
          await _openWaulyApp(packageName);
        } else {
          // App not installed, try fallback download
          debugPrint('❌ App not installed, trying fallback download');
          await _openOrInstallFallback(context);
        }
        return;
      }

      debugPrint('🆕 Latest version from server: ${latestInfo.version}');

      // Step 3: Compare versions and decide
      if (installedVersion == null) {
        // App not installed - show install dialog
        debugPrint('❌ Wauly not installed');
        final shouldInstall = await _showInstallDialog(context);
        if (shouldInstall) {
          await _downloadAndInstallApk(latestInfo.exeUrl, latestInfo.fileName);
        }
      } else if (installedVersion == latestInfo.version) {
        // Same version - just open
        debugPrint(
            '✅ Wauly is up to date (version $installedVersion) → opening app');
        await _openWaulyApp(packageName);
      } else if (isNewerVersion(installedVersion, latestInfo.version)) {
        // Update available
        debugPrint(
            '🔄 Update available: $installedVersion → ${latestInfo.version}');

        final shouldUpdate = await _showUpdateDialog(
            context, installedVersion, latestInfo.version);

        if (shouldUpdate) {
          await _downloadAndInstallApk(latestInfo.exeUrl, latestInfo.fileName);
        } else {
          await _openWaulyApp(packageName);
        }
      } else {
        // Installed version is newer than server version (shouldn't happen normally)
        debugPrint(
            'ℹ️ Installed version ($installedVersion) is newer than server version (${latestInfo.version})');
        await _openWaulyApp(packageName);
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
    } finally {
      _isProcessing = false;
    }
  }

  // Add this new method for install dialog
  Future<bool> _showInstallDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Install Wauly App'),
            content: const Text('Wauly app is not installed on this device.\n\n'
                'Would you like to download and install it now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Install',
                    style: TextStyle(color: Colors.green)),
              ),
            ],
          ),
        ) ??
        false;
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
