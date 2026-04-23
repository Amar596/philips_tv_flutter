import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:xml/xml.dart';
import 'auto_install_helper.dart';

class AppVersionInfo {
  final String version;
  final String exeUrl;
  final String fileName;
  final int versionCode;
  final String url;

  AppVersionInfo({
    required this.version,
    required this.exeUrl,
    required this.fileName,
    required this.versionCode,
    required this.url,
  });
}

// Add this class before WaulyAppManager class
class AutoClickableAlertDialog extends StatefulWidget {
  final String title;
  final String content;
  final String currentVersion;
  final String latestVersion;
  final VoidCallback onUpdateNow;
  final VoidCallback onLater;

  const AutoClickableAlertDialog({
    Key? key,
    required this.title,
    required this.content,
    required this.currentVersion,
    required this.latestVersion,
    required this.onUpdateNow,
    required this.onLater,
  }) : super(key: key);

  @override
  State<AutoClickableAlertDialog> createState() =>
      _AutoClickableAlertDialogState();
}

class _AutoClickableAlertDialogState extends State<AutoClickableAlertDialog> {
  final GlobalKey _updateButtonKey = GlobalKey();
  bool _autoClicked = false;

  @override
  void initState() {
    super.initState();

    // Auto-click after dialog is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_autoClicked) {
        _autoClickUpdateButton();
      }
    });
  }

  Future<void> _autoClickUpdateButton() async {
    // Small delay to ensure dialog is fully rendered
    await Future.delayed(const Duration(milliseconds: 500));

    // Find the button by key and click it
    final RenderBox? renderBox =
        _updateButtonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      print('🤖 Auto-clicking Update Now button');
      widget.onUpdateNow();
      _autoClicked = true;
    } else {
      print('❌ Could not find Update Now button for auto-click');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.content),
      actions: [
        TextButton(
          onPressed: () {
            widget.onLater();
            Navigator.pop(context, false);
          },
          child: const Text('Later'),
        ),
        ElevatedButton(
          key: _updateButtonKey, // Add key to identify the button
          onPressed: () {
            widget.onUpdateNow();
            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text('Update Now'),
        ),
      ],
    );
  }
}

class WaulyAppManager {
  static const platform = MethodChannel('apk_install');
  static const packageName = 'com.example.wauly_app';
  static String versionUrl =
      "https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml";
  static String apkUrl =
      "https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/WaulySignage.apk";

  static const String KEY_LAST_INSTALLED_VERSION = 'last_installed_version';

  // ADD THESE - Pending state keys
  static const String KEY_PENDING_INSTALL = 'pending_install';
  static const String KEY_PENDING_APK_PATH = 'pending_apk_path';
  static const String KEY_PENDING_VERSION = 'pending_version';

  // ADD THESE CONSTANTS
  static const String KEY_CUSTOM_VERSION_URL = 'custom_version_url';
  static const String KEY_CUSTOM_APK_URL = 'custom_apk_url';

  // 🔹 INSTALL APK
  static Future<void> installApk(String filePath) async {
    await platform.invokeMethod('installApk', {"path": filePath});
  }

  // 🔹 GET INSTALLED VERSION
  static Future<String?> getInstalledVersion() async {
    try {
      final version = await platform.invokeMethod('getPackageVersion', {
        'packageName': packageName,
      });
      return version as String?;
    } catch (_) {
      return null;
    }
  }

  // 🔹 GET INSTALLED VERSION CODE (if needed)
  static Future<int?> getInstalledVersionCode() async {
    try {
      final versionCode = await platform.invokeMethod('getPackageVersionCode', {
        'packageName': packageName,
      });
      return versionCode as int?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> markUpdateInstalled(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_installed_version', version);
    print('Marked version $version as installed in SharedPreferences');
  }

  static Future<String?> getLastInstalledVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_installed_version');
  }

  // 🔹 ADD THESE NEW METHODS

  // Load saved URLs from SharedPreferences
  static Future<void> loadSavedUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final savedVersionUrl = prefs.getString(KEY_CUSTOM_VERSION_URL);
    final savedApkUrl = prefs.getString(KEY_CUSTOM_APK_URL);

    if (savedVersionUrl != null && savedVersionUrl.isNotEmpty) {
      versionUrl = savedVersionUrl;
      print('📋 Loaded saved version URL: $versionUrl');
    }

    if (savedApkUrl != null && savedApkUrl.isNotEmpty) {
      apkUrl = savedApkUrl;
      print('📋 Loaded saved APK URL: $apkUrl');
    }
  }

  // Save custom URLs
  static Future<void> saveCustomUrls(
      String newVersionUrl, String newApkUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(KEY_CUSTOM_VERSION_URL, newVersionUrl);
    await prefs.setString(KEY_CUSTOM_APK_URL, newApkUrl);

    versionUrl = newVersionUrl;
    apkUrl = newApkUrl;

    print('💾 Saved custom URLs - Version: $newVersionUrl, APK: $newApkUrl');
  }

  // Reset to default URLs
  static Future<void> resetToDefaultUrls() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_CUSTOM_VERSION_URL);
    await prefs.remove(KEY_CUSTOM_APK_URL);

    versionUrl =
        "https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/version.xml";
    apkUrl =
        "https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/WaulySignage.apk";

    print('🔄 Reset to default URLs');
  }

  static Future<AppVersionInfo?> fetchLatestVersion() async {
    try {
      final url = versionUrl;
      print('📡 Fetching version from: $url');

      // Check if URL points to APK file
      if (url.toLowerCase().endsWith('.apk')) {
        print('⚠️ Direct APK URL detected - skipping XML parsing');
        String version = '';
        final fileName = url.split('/').last;
        final versionMatch = RegExp(r'v(\d+\.\d+\.\d+)').firstMatch(fileName);
        if (versionMatch != null) {
          version = versionMatch.group(1)!;
        }

        return AppVersionInfo(
          versionCode: 1,
          version: version,
          url: url,
          exeUrl: url,
          fileName: fileName,
        );
      }

      // Parse XML
      final response = await http.get(Uri.parse(url));
      print('📡 Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        print('❌ HTTP Error: ${response.statusCode}');
        return null;
      }

      final body = response.body;
      print('📄 XML Content: $body');

      // Check if XML is empty or invalid
      if (body.isEmpty || !body.contains('<Update>')) {
        print('❌ XML file is empty or invalid');
        return null;
      }

      final document = XmlDocument.parse(body);

      // Find the Update element
      final updateElements = document.findAllElements('Update');
      if (updateElements.isEmpty) {
        print('❌ No <Update> element found in XML');
        return null;
      }

      final updateElement = updateElements.first;

      // Get Version - YOUR XML USES <Version> not <code> or <name>
      final versionElements = updateElement.findElements('Version');
      if (versionElements.isEmpty) {
        print('❌ No <Version> element found');
        return null;
      }
      final version = versionElements.first.text.trim();

      // Get ExeUrl - YOUR XML USES <ExeUrl> not <url>
      final exeUrlElements = updateElement.findElements('ExeUrl');
      if (exeUrlElements.isEmpty) {
        print('❌ No <ExeUrl> element found');
        return null;
      }
      final exeUrl = exeUrlElements.first.text.trim();

      // Get FileName - YOUR XML USES <FileName>
      final fileNameElements = updateElement.findElements('FileName');
      String fileName = 'wauly_app.apk';
      if (fileNameElements.isNotEmpty) {
        fileName = fileNameElements.first.text.trim();
      } else {
        // Fallback: extract from URL
        fileName = exeUrl.split('/').last;
      }

      // Parse version code (convert version string to integer code)
      // Example: "1.0.3" -> 103
      int versionCode = 1;
      try {
        final versionParts = version.split('.');
        if (versionParts.length >= 3) {
          versionCode = int.parse(versionParts[0]) * 100 +
              int.parse(versionParts[1]) * 10 +
              int.parse(versionParts[2]);
        } else if (versionParts.length == 2) {
          versionCode = int.parse(versionParts[0]) * 100 +
              int.parse(versionParts[1]) * 10;
        } else {
          versionCode = int.parse(versionParts[0]) * 100;
        }
      } catch (e) {
        print('⚠️ Could not parse version code, using default: 1');
        versionCode = 1;
      }

      print(
          '✅ Parsed - Version: $version, VersionCode: $versionCode, ExeUrl: $exeUrl, FileName: $fileName');

      return AppVersionInfo(
        versionCode: versionCode,
        version: version,
        url: exeUrl,
        exeUrl: exeUrl,
        fileName: fileName,
      );
    } catch (e) {
      print('❌ Error fetching version: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // 🔹 VERSION COMPARE
  static bool isNewerVersion(String current, String latest) {
    try {
      final c = current.split('.').map(int.parse).toList();
      final l = latest.split('.').map(int.parse).toList();

      for (int i = 0; i < math.min(c.length, l.length); i++) {
        if (l[i] > c[i]) return true;
        if (l[i] < c[i]) return false;
      }
      return l.length > c.length;
    } catch (e) {
      print('Version compare error: $e');
      return false;
    }
  }

  // 🔹 DOWNLOAD APK
  static Future<String> downloadApk(String url, String fileName) async {
    final dir = await getExternalStorageDirectory();
    final path = '${dir!.path}/$fileName';

    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      print('🗑️ Deleted old APK');
    }

    await Dio().download(url, path);
    print('✅ APK downloaded to: $path');
    return path;
  }

  // 🔹 CLEAN UP OLD APKS
  static Future<void> cleanupOldApks(String currentApkPath) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir != null) {
        final files = await dir.list().toList();
        for (var file in files) {
          if (file.path.endsWith('.apk') && file.path != currentApkPath) {
            await File(file.path).delete();
          }
        }
      }
    } catch (e) {
      print('Cleanup error: $e');
    }
  }

  // 🔹 SAVE PENDING INSTALLATION
  static Future<void> savePendingInstallation(
      String apkPath, String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(KEY_PENDING_INSTALL, true);
    await prefs.setString(KEY_PENDING_APK_PATH, apkPath);
    await prefs.setString(KEY_PENDING_VERSION, version);
    print('💾 Saved pending installation - Path: $apkPath, Version: $version');
  }

  // 🔹 CLEAR PENDING INSTALLATION
  static Future<void> clearPendingInstallation() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(KEY_PENDING_INSTALL);
    await prefs.remove(KEY_PENDING_APK_PATH);
    await prefs.remove(KEY_PENDING_VERSION);
    print('🗑️ Cleared pending installation');
  }

  // 🔹 CHECK AND RESUME PENDING INSTALLATION - CALL THIS IN main() OR SPLASH SCREEN
  static Future<bool> checkAndResumePendingInstallation() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPending = prefs.getBool(KEY_PENDING_INSTALL) ?? false;

    if (!hasPending) {
      return false;
    }

    final pendingApkPath = prefs.getString(KEY_PENDING_APK_PATH);
    final pendingVersion = prefs.getString(KEY_PENDING_VERSION) ?? '';

    if (pendingApkPath == null || !await File(pendingApkPath).exists()) {
      print('⚠️ Pending APK not found, clearing state');
      await clearPendingInstallation();
      return false;
    }

    print('🔄 Found pending installation, checking accessibility...');

    // Check if accessibility is now enabled
    final isEnabled = await AutoInstallHelper.isAccessibilityEnabled();

    if (isEnabled) {
      print('✅ Accessibility enabled, resuming installation');

      await AutoInstallHelper.resetAutoClickFlags();
      await AutoInstallHelper.triggerAutoInstall(pendingApkPath);
      print('✅ APK installation initiated from pending state');

      if (pendingVersion.isNotEmpty) {
        await markUpdateInstalled(pendingVersion);
      }

      await cleanupOldApks(pendingApkPath);
      await clearPendingInstallation();

      // Exit after installation
      await Future.delayed(const Duration(seconds: 2));
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      return true;
    } else {
      print('❌ Accessibility still not enabled');
      // Keep pending state for next app launch
      return false;
    }
  }

  // Add this new method before downloadAndInstall
  static Future<bool> _showInstallConfirmationDialog(
      BuildContext context, String version) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Confirm Update'),
            content: Text(
              'A new version ($version) is available.\n\n'
              'Would you like to download and install it now?\n\n'
              'The app will restart after installation.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
                child: const Text('Install Now'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // 🔹 MODIFIED DOWNLOAD AND INSTALL WITH PENDING STATE
  static Future<void> downloadAndInstall(String url, String fileName,
      {bool exitAfterInstall = true,
      String? newVersion,
      BuildContext? context,
      bool showDialog = true}) async {
    print('🚀 Starting download and install process...');

    // If showDialog is true, show confirmation dialog first
    // if (showDialog && context != null) {
    //   final confirmed =
    //       await _showInstallConfirmationDialog(context, newVersion ?? '');
    //   if (!confirmed) {
    //     print('❌ User cancelled installation');
    //     return;
    //   }
    // }
    await AutoInstallHelper.resetAutoClickFlags();

    if (await Permission.requestInstallPackages.isDenied) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) throw Exception('Permission denied');
    }

    if (await Permission.storage.isDenied) {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw Exception('Storage permission denied');
    }

    final path = await downloadApk(url, fileName);

    // Check if accessibility is enabled
    final isEnabled = await AutoInstallHelper.isAccessibilityEnabled();

    if (!isEnabled) {
      print('❌ Accessibility not enabled, saving pending state');

      // Save pending installation
      await savePendingInstallation(path, newVersion ?? '');

      // Show dialog and request accessibility
      if (context != null) {
        final enable = await _showAccessibilityDialog(context);
        if (enable) {
          await openAccessibilitySettings();
          // App will close here, but state is saved
          // User must reopen the app manually
          return;
        } else {
          await clearPendingInstallation();
          throw Exception('Accessibility permission required');
        }
      } else {
        throw Exception(
            'Accessibility permission required and no context provided');
      }
    }

    // Accessibility is enabled, proceed with installation
    print('🔧 Attempting auto-install...');
    await AutoInstallHelper.triggerAutoInstall(path);
    print('✅ APK installation initiated');

    if (newVersion != null) {
      await markUpdateInstalled(newVersion);
    }

    await cleanupOldApks(path);
    await clearPendingInstallation();

    if (exitAfterInstall) {
      print('🚪 Exiting app after installation...');
      await Future.delayed(const Duration(seconds: 2));
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
    }
  }

  // 🔹 OPEN APP
  static Future<void> openApp() async {
    const activity = 'com.example.wauly_app.MainActivity';

    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: packageName,
      componentName: activity,
      category: 'android.intent.category.LAUNCHER',
      flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
    );

    await intent.launch();
  }

  //🔹 MAIN FLOW
  static Future<void> handleAppFlow(BuildContext context) async {
    print('=== Starting App Flow ===');

    // FIRST: Check for pending installation from previous session
    final pendingResumed = await checkAndResumePendingInstallation();
    if (pendingResumed) {
      print('✅ Pending installation resumed and completed');
      return;
    }

    final installedVersion = await getInstalledVersion();
    final latest = await fetchLatestVersion();

    print('📱 Installed version: $installedVersion');
    print('🌐 Latest version: ${latest?.version ?? 'null'}');
    print('🔍 Latest exeUrl: ${latest?.exeUrl ?? 'null'}');
    print('🔍 Latest fileName: ${latest?.fileName ?? 'null'}');

    if (latest == null) {
      print('⚠️ Could not fetch latest version from server');
      if (installedVersion != null) {
        await openApp();
      } else {
        // Use Azure default URL when no version info is available
        final defaultApkUrl =
            'https://waulymvcapp.blob.core.windows.net/waulymvcdev/Builds/Android/Host/WaulySignage.apk';
        await downloadAndInstall(defaultApkUrl, 'wauly.apk',
            exitAfterInstall: true,
            newVersion: '',
            context: context,
            showDialog: true);
      }
      return;
    }

    if (installedVersion == null) {
      print('❌ App not installed');
      final install = await _showInstallDialog(context);
      if (install) {
        await downloadAndInstall(
          latest.exeUrl,
          latest.fileName,
          exitAfterInstall: true,
          newVersion: latest.version,
          context: context,
          showDialog: false,
        );
      }
      return;
    }

    final lastInstalled = await getLastInstalledVersion();
    print('Installed version: $installedVersion');
    print('Latest version: ${latest.version}');
    print('Last installed marked: $lastInstalled');

    if (lastInstalled == latest.version) {
      print('Already installed version ${latest.version}, opening app');
      // ✅ ADD THE POPUP MESSAGE HERE
      if (context.mounted) {
        // Show SnackBar message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✓ Already installed version ${latest.version}, opening app'),
            duration: Duration(seconds: 3),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Small delay to show the message before opening the app
      await Future.delayed(Duration(milliseconds: 1500));
      await openApp();
      return;
    }

    final needsUpdate = isNewerVersion(installedVersion, latest.version);
    print('🔍 Needs update: $needsUpdate');

    if (needsUpdate) {
      print('🆕 New version available! $installedVersion → ${latest.version}');

      // ADD A DELAY TO SEE THE DIALOG
      await Future.delayed(const Duration(milliseconds: 500));

      final shouldUpdate =
          await _showUpdateDialog(context, installedVersion, latest.version);
      print('🔍 User chose to update: $shouldUpdate');

      if (shouldUpdate) {
        print('🚀 Starting download and install...');
        await downloadAndInstall(
          latest.exeUrl,
          latest.fileName,
          exitAfterInstall: true,
          newVersion: latest.version,
          context: context,
        );
      } else {
        print('⏭️ User chose to update later');
        await openApp();
      }
    } else {
      print('✅ No update needed');
      await markUpdateInstalled(installedVersion);
      // ✅ ADD POPUP MESSAGE HERE TOO
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ App is up to date (version $installedVersion)'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        await Future.delayed(Duration(milliseconds: 1000));
      }
      await openApp();
    }
  }

  static Future<bool> checkAccessibility(BuildContext context) async {
    final isEnabled = await AutoInstallHelper.isAccessibilityEnabled();

    if (isEnabled) {
      print('✅ Accessibility already enabled');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accessibility already enabled')),
        );
      }
      return true;
    }

    print('❌ Accessibility NOT enabled');
    final enable = await _showAccessibilityDialog(context);
    return enable;
  }

  static Future<bool> _showAccessibilityDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Enable Auto-Install'),
            content: const Text(
              'To enable automatic app updates, please enable accessibility service for this app.\n\n'
              'This allows the app to automatically click the install button during updates.\n\n'
              '⚠️ IMPORTANT: The app will close when you open Accessibility Settings.\n'
              'After enabling the service, please manually reopen this app to continue the installation.\n\n'
              'Steps:\n'
              '1. Click "Enable Now" below\n'
              '2. Find "" in the list\n'
              '3. Turn it ON\n'
              '4. Press back and reopen this app',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
                child: const Text('Enable Now'),
              ),
            ],
          ),
        ) ??
        false;
  }

  // static Future<bool> _showUpdateDialog(
  //     BuildContext context, String current, String latest) async {
  //   print('🔴 SHOWING UPDATE DIALOG - Current: $current, Latest: $latest');
  //   final result = await showDialog<bool>(
  //         context: context,
  //         barrierDismissible: false,
  //         builder: (_) => AlertDialog(
  //           title: const Text('Update Available'),
  //           content: Text(
  //               'A new version ($latest) is available.\n\nCurrent version: $current\n\nUpdate will download and install. The app will restart after installation.'),
  //           actions: [
  //             TextButton(
  //                 onPressed: () {
  //                   print('🔴 User clicked LATER');
  //                   Navigator.pop(context, false);
  //                 },
  //                 child: const Text('Later')),
  //             ElevatedButton(
  //               onPressed: () {
  //                 print('🔴 User clicked UPDATE NOW');
  //                 Navigator.pop(context, true);
  //               },
  //               style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
  //               child: const Text('Update Now'),
  //             ),
  //           ],
  //         ),
  //       ) ??
  //       false;

  //   print('🔴 Dialog result: $result');
  //   return result;
  // }

  static Future<bool> _showUpdateDialog(
      BuildContext context, String current, String latest) async {
    print('🔴 SHOWING UPDATE DIALOG - Current: $current, Latest: $latest');

    final completer = Completer<bool>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AutoClickableAlertDialog(
        title: 'Update Available',
        content:
            'A new version ($latest) is available.\n\nCurrent version: $current\n\nUpdate will download and install. The app will restart after installation.',
        currentVersion: current,
        latestVersion: latest,
        onUpdateNow: () {
          print('🤖 Update Now clicked (auto or manual)');
          completer.complete(true);
        },
        onLater: () {
          print('🔴 Later clicked');
          completer.complete(false);
        },
      ),
    );

    return await completer.future;
  }

  static Future<bool> _showInstallDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Install App'),
            content: const Text(
                'Wauly app is not installed. Would you like to install it now?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  child: const Text('Install')),
            ],
          ),
        ) ??
        false;
  }

  static Future<void> forceUpdateIfNeeded(BuildContext context) async {
    final installedVersion = await getInstalledVersion();
    final latest = await fetchLatestVersion();

    if (latest != null && installedVersion != null) {
      if (isNewerVersion(installedVersion, latest.version)) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Mandatory Update'),
            content: Text(
                'A new version (${latest.version}) is required to continue.\n\nCurrent version: $installedVersion'),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await downloadAndInstall(latest.exeUrl, latest.fileName,
                      context: context);
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      } else {
        await openApp();
      }
    }
  }

  static Future<void> openAccessibilitySettings() async {
    final intent = AndroidIntent(
      action: 'android.settings.ACCESSIBILITY_SETTINGS',
      flags: [
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_NO_HISTORY,
      ],
    );
    await intent.launch();
  }

  static Future<void> checkAndHandleAccessibility(BuildContext context) async {
    final isEnabled = await AutoInstallHelper.isAccessibilityEnabled();

    if (isEnabled) {
      print('✅ Accessibility already enabled');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Auto-install is already enabled')),
        );
      }
    } else {
      print('❌ Accessibility NOT enabled');
      final enable = await _showAccessibilityDialog(context);
      if (!enable) {
        throw Exception('Accessibility permission required');
      }
      // Note: We don't open settings here - handled in downloadAndInstall
    }
  }
}
