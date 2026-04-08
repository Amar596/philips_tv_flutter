import 'dart:async';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/services/wauly_app_service.dart';

class AutoInstallHelper {
  static const platform = MethodChannel('auto_install');

  static Future<void> triggerAutoInstall(String apkPath) async {
    try {
      // Reset flags before starting new installation
      await resetAutoClickFlags();

      // First open the installer
      await WaulyAppManager.installApk(apkPath);

      // Wait for installer window and auto-click
      await Future.delayed(const Duration(seconds: 2));
      await platform.invokeMethod('autoClickInstall');
    } catch (e) {
      print('Auto-install failed: $e');
    }
  }

  // static Future<bool> isAccessibilityEnabled() async {
  //   // FORCE RETURN TRUE - BYPASS ACCESSIBILITY CHECK
  //   return true;

  //   // Original code commented out
  //   // try {
  //   //   return await platform.invokeMethod('isAccessibilityEnabled');
  //   // } catch (e) {
  //   //   print('Failed to check accessibility: $e');
  //   //   return false;
  //   // }
  // }

  static Future<void> requestAccessibility() async {
    try {
      await platform.invokeMethod('requestAccessibility');
    } catch (e) {
      print('Failed to request accessibility: $e');
    }
  }

  static Future<void> resetAutoClickFlags() async {
    try {
      await platform.invokeMethod('resetFlags');
    } catch (e) {
      print('Failed to reset flags: $e');
    }
  }

  static const MethodChannel _channel = MethodChannel('auto_install');

  static Future<bool> isAccessibilityEnabled() async {
    try {
      final bool isEnabled =
          await _channel.invokeMethod('isAccessibilityEnabled');
      return isEnabled;
    } catch (e) {
      print('❌ Error checking accessibility: $e');
      return false;
    }
  }
}
