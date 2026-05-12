import 'package:flutter/services.dart';

class UsbControlService {
  static const MethodChannel _channel = MethodChannel('com.philips.tv/usb');

  // Send broadcast intent to enable/disable USB ports
  static Future<bool> setUsbPortsEnabled(bool enabled) async {
    try {
      final String action = enabled ? "enable" : "disable";

      final bool result = await _channel
          .invokeMethod('setUsbState', {'enabled': enabled, 'action': action});

      print('✅ USB ports ${enabled ? "enabled" : "disabled"} successfully');
      return result;
    } on PlatformException catch (e) {
      print('❌ Platform error controlling USB ports: ${e.message}');
      return false;
    } catch (e) {
      print('❌ Error controlling USB ports: $e');
      return false;
    }
  }

  // Check current USB port status
  static Future<Map?> getUsbStatus() async {
    try {
      final Map? status = await _channel.invokeMethod('getUsbStatus');

      return status;
    } catch (e) {
      print('Error getting USB status: $e');
      return null;
    }
  }
}
