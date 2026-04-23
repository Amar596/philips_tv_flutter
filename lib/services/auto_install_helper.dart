import 'dart:async';
import 'package:flutter/services.dart';
import 'package:philips_tv_flutter/services/wauly_app_service.dart';

class AutoInstallHelper {
  static const platform = MethodChannel('auto_install');
  static Timer? _monitoringTimer;

  // Start monitoring for dialogs
  static void startDialogMonitoring() {
    stopDialogMonitoring(); // Stop any existing monitoring
    _monitoringTimer =
        Timer.periodic(const Duration(milliseconds: 800), (timer) async {
      final hasDialog = await isUpdateDialogShowing();
      if (hasDialog) {
        stopDialogMonitoring(); // Stop monitoring
        await autoHandleUpdateIfNeeded();
      }
    });
  }

  // Stop monitoring
  static void stopDialogMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
  }

  static Future<void> triggerAutoInstall(String apkPath) async {
    try {
      // Reset flags before starting new installation
      await resetAutoClickFlags();

      // First open the installer
      await WaulyAppManager.installApk(apkPath);

      // Wait for installer window and auto-click
      await Future.delayed(const Duration(seconds: 2));
      await _channel.invokeMethod('autoClickInstall');
    } catch (e) {
      print('Auto-install failed: $e');
    }
  }

  static Future<void> requestAccessibility() async {
    try {
      await _channel.invokeMethod('requestAccessibility');
    } catch (e) {
      print('Failed to request accessibility: $e');
    }
  }

  static Future<void> resetAutoClickFlags() async {
    try {
      await _channel.invokeMethod('resetFlags');
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

  // Method for clicking dialog buttons
  static Future<void> clickDialogButton(String buttonText) async {
    try {
      await _channel.invokeMethod('clickDialogButton', {
        'buttonText': buttonText,
      });
      print('✅ Attempted to click button: $buttonText');
    } catch (e) {
      print('❌ Failed to click dialog button: $e');
    }
  }

  // Method to check if update dialog is showing
  static Future<bool> isUpdateDialogShowing() async {
    try {
      final result = await _channel.invokeMethod('isUpdateDialogShowing');
      return result ?? false;
    } catch (e) {
      print('❌ Error checking update dialog: $e');
      return false;
    }
  }

  // Method to automatically handle the entire update flow
  static Future<void> autoHandleUpdateIfNeeded() async {
    try {
      // Check if update dialog is showing
      final hasDialog = await isUpdateDialogShowing();
      if (hasDialog) {
        print('🤖 Update dialog detected, auto-clicking Update Now');
        await Future.delayed(
            const Duration(milliseconds: 500)); // Small delay for safety
        await clickDialogButton('Update Now');
      }
    } catch (e) {
      print('❌ Error in auto handle update: $e');
    }
  }

  // ADD THESE TWO NEW METHODS:

  // New method specifically for auto-clicking update button (alias for clickDialogButton)
  static Future<void> autoClickUpdateButton(String buttonText) async {
    try {
      await _channel.invokeMethod('autoClickUpdateButton', {
        'buttonText': buttonText,
      });
      print('✅ Auto-click update button: $buttonText');
    } catch (e) {
      print('❌ Failed to auto-click update button: $e');
    }
  }

  static Future<void> forceCheckForDialog() async {
    try {
      await _channel.invokeMethod('forceCheckForDialog');
      print('✅ Force check for dialog triggered');
    } catch (e) {
      print('❌ Failed to force check for dialog: $e');
    }
  }
}
