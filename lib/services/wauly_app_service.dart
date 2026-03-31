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

class AppVersionInfo {
  final String version;
  final String exeUrl;
  final String fileName;
  final int versionCode;

  AppVersionInfo({
    required this.version,
    required this.exeUrl,
    required this.fileName,
    required this.versionCode,
  });
}

class WaulyAppManager {
  static const platform = MethodChannel('apk_install');
  static const packageName = 'com.example.wauly_app';
  static const versionUrl = 'http://192.168.0.194:8080/version.xml';
  static const apkUrl = 'http://192.168.0.194:8080/WaulySignage.apk';
  static const String KEY_LAST_INSTALLED_VERSION = 'last_installed_version';

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

  // 🔹 FETCH XML
  static Future<AppVersionInfo?> fetchLatestVersion() async {
    try {
      print('📡 Fetching version from: $versionUrl');
      final response = await http.get(Uri.parse(versionUrl));

      if (response.statusCode == 200) {
        final document = XmlDocument.parse(response.body);
        final update = document.findAllElements('Update').first;

        // Try to get VersionCode, default to 0 if not present
        int versionCode = 0;
        try {
          final versionCodeElement = update.findElements('VersionCode').first;
          versionCode = int.parse(versionCodeElement.text);
        } catch (e) {
          print('⚠️ VersionCode not found in XML, using default: 0');
        }

        return AppVersionInfo(
          version: update.findElements('Version').first.text,
          exeUrl: update.findElements('ExeUrl').first.text,
          fileName: update.findElements('FileName').first.text,
          versionCode: versionCode, 
        );

        // print('📦 Latest version from server: ${versionInfo.version} (code: ${versionInfo.versionCode})');
        // return versionInfo;
      }
    } catch (e) {
      print('❌ Error fetching version: $e');
    }
    return null;
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

    // Delete old APK if exists
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

  // 🔹 INSTALL FLOW - Modified to exit after installation
  static Future<void> downloadAndInstall(String url, String fileName,
      {bool exitAfterInstall = true,String? newVersion}) async {
        print('🚀 Starting download and install process...');
    // Check and request install permission
    if (await Permission.requestInstallPackages.isDenied) {
      final status = await Permission.requestInstallPackages.request();
      if (!status.isGranted) throw Exception('Permission denied');
    }

    // Check storage permission
    if (await Permission.storage.isDenied) {
      final status = await Permission.storage.request();
      if (!status.isGranted) throw Exception('Storage permission denied');
    }

    final path = await downloadApk(url, fileName);

    // Install new APK
    print('📲 Installing APK...');
    await installApk(path);
    print('✅ APK installation initiated');

    // 🔹 ADD THIS - Mark this version as installed before cleaning up
    if (newVersion != null) {
      await markUpdateInstalled(newVersion);
    }

    // Clean up old APKs after successful install
    await cleanupOldApks(path);

    //Exit the app after installation so user can open the new version
    if (exitAfterInstall) {
      print('🚪 Exiting app after installation...');
      await Future.delayed(
          const Duration(seconds: 1)); // Give time for install to complete
      SystemChannels.platform.invokeMethod('SystemNavigator.pop');
      // Or use: exit(0);
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

  // 🔹 MAIN FLOW
  static Future<void> handleAppFlow(BuildContext context) async {
    print('=== Starting App Flow ===');
    final installedVersion = await getInstalledVersion();
    final latest = await fetchLatestVersion();

    print('📱 Installed version: $installedVersion');
    print('🌐 Latest version: ${latest?.version ?? 'null'}');

    if (latest == null) {
      print('⚠️ Could not fetch latest version from server');
      if (installedVersion != null) { 
        await openApp();
      } else {
        await downloadAndInstall(
            'http://192.168.0.169:8080/WaulySignage.apkwauly.apk', 'wauly.apk',
            exitAfterInstall: true, newVersion: '');
      }
      return;
    }

    if (installedVersion == null) {
      print('❌ App not installed');
      final install = await _showInstallDialog(context);
      if (install) {
        await downloadAndInstall(
            latest.exeUrl, latest.fileName,
            exitAfterInstall: true, newVersion: latest.version);
      }
      return;
    } 

        // 🔹 ADD THIS - Check if we already installed this update before
    final lastInstalled = await getLastInstalledVersion();
    print('Installed version: $installedVersion');
    print('Latest version: ${latest.version}');
    print('Last installed marked: $lastInstalled');

    // If we've already installed this update, just open the app
    if (lastInstalled == latest.version) {
      print('Already installed version ${latest.version}, opening app');
      await openApp();
      return;
    }
    
  
      // Compare versions
      if (isNewerVersion(installedVersion, latest.version)) {
        print('🆕 New version available! $installedVersion → ${latest.version}');
        // New version available
        final shouldUpdate =
            await _showUpdateDialog(context, installedVersion, latest.version);

        if (shouldUpdate) {
          // Download and install new APK (this will replace the old one)
          await downloadAndInstall(latest.exeUrl, latest.fileName,
              exitAfterInstall: true, newVersion: latest.version);
          // Note: After installation, the user will need to reopen the app
          // The old version will be replaced by the new one
        } else {
          // User chose to update later, open current version
          print('⏭️ User chose to update later');
          await openApp();
        }
      } else {
        // No update available (same version or installed version is newer)
        print('✅ No update needed');
        await markUpdateInstalled(installedVersion);
        await openApp();
      }

  }

  // Modified update dialog with auto-restart
  static Future<bool> _showUpdateDialog(
      BuildContext context, String current, String latest) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
                'A new version ($latest) is available.\n\nCurrent version: $current\n\nUpdate will download and install. The app will restart after installation.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Update Now')),
            ],
          ),
        ) ??
        false;
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

  // 🔹 FORCE UPDATE (if you want to force users to update)
  static Future<void> forceUpdateIfNeeded(BuildContext context) async {
    final installedVersion = await getInstalledVersion();
    final latest = await fetchLatestVersion();

    if (latest != null && installedVersion != null) {
      if (isNewerVersion(installedVersion, latest.version)) {
        // Force update - no "Later" option
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('Mandatory Update'),
            content: Text(
                'A new version ($latest) is required to continue.\n\nCurrent version: $installedVersion'),
            actions: [
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await downloadAndInstall(latest.exeUrl, latest.fileName);
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
}
