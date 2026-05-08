import 'package:flutter/services.dart';

class DeviceControl {
  static const _channel = MethodChannel('storage_info');

  static Future<void> shutdown() async {
    try {
      final result = await _channel.invokeMethod('shutdownDevice');
      print(result); // "Shutdown broadcast sent"
    } on PlatformException catch (e) {
      print("Shutdown failed: ${e.message}");
    }
  }

  static Future<void> reboot() async {
    try {
      final result = await _channel.invokeMethod('rebootDevice');
      print(result); // "Reboot broadcast sent"
    } on PlatformException catch (e) {
      print("Reboot failed: ${e.message}");
    }
  }
}
