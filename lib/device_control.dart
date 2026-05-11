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

  static Future<void> setBacklight(bool enable) async {
    try {
      final result = await _channel
          .invokeMethod('setBacklight', {'switch': enable ? '1' : '0'});
      print(result);
    } on PlatformException catch (e) {
      print("Set backlight failed: ${e.message}");
    }
  }

  static Future<String> getBacklightStatus() async {
    try {
      final status = await _channel.invokeMethod('getBacklightStatus');
      return status.toString();
    } on PlatformException catch (e) {
      print("Get backlight status failed: ${e.message}");
      return '0';
    }
  }

  static Future<String> getModelName() async {
    try {
      final modelName = await _channel.invokeMethod('getModelName');
      return modelName.toString();
    } on PlatformException catch (e) {
      print("Get model name failed: ${e.message}");
      return '';
    }
  }

  static Future<String> getPlatformName() async {
    try {
      final platformName = await _channel.invokeMethod('getPlatformName');
      return platformName.toString();
    } on PlatformException catch (e) {
      print("Get platform name failed: ${e.message}");
      return '';
    }
  }

  static Future<String> getSerialNumber() async {
    try {
      final serialNo = await _channel.invokeMethod('getSerialNumber');
      return serialNo.toString();
    } on PlatformException catch (e) {
      print("Get serial number failed: ${e.message}");
      return '';
    }
  }

  static Future<String> getModelNumber() async {
    try {
      final modelNo = await _channel.invokeMethod('getModelNumber');
      return modelNo.toString();
    } on PlatformException catch (e) {
      print("Get model number failed: ${e.message}");
      return '';
    }
  }

  static Future<String> getMacAddress() async {
    try {
      final macAddress = await _channel.invokeMethod('getMacAddress');
      return macAddress.toString();
    } on PlatformException catch (e) {
      print("Get MAC address failed: ${e.message}");
      return '';
    }
  }

  static Future<Map<String, String>> getAllDeviceDetails() async {
    try {
      final details = await _channel.invokeMethod('getAllDeviceDetails');
      return Map<String, String>.from(details);
    } on PlatformException catch (e) {
      print("Get all device details failed: ${e.message}");
      return {};
    }
  }

  static Future<String> getCurrentRotation() async {
    try {
      final rotation = await _channel.invokeMethod('getCurrentRotation');
      return rotation.toString();
    } on PlatformException catch (e) {
      print("Get current rotation failed: ${e.message}");
      return 'landscape';
    }
  }

  static Future<void> setScreenRotation(int angle) async {
    if (![0, 90, 180, 270].contains(angle)) {
      print("Invalid angle: $angle. Must be 0, 90, 180, or 270");
      return;
    }

    try {
      final result = await _channel
          .invokeMethod('setScreenRotation', {'angle': angle.toString()});
      print(result);
    } on PlatformException catch (e) {
      print("Set screen rotation failed: ${e.message}");
    }
  }

  static Future<void> setScreenRotationWithBlackScreen(int angle) async {
    if (![0, 90, 180, 270].contains(angle)) {
      print("Invalid angle: $angle. Must be 0, 90, 180, or 270");
      return;
    }

    try {
      final result = await _channel.invokeMethod(
          'setScreenRotationWithBlackScreen', {'angle': angle.toString()});
      print(result);
    } on PlatformException catch (e) {
      print("Set screen rotation with black screen failed: ${e.message}");
    }
  }

  static Future<int> getBrightness() async {
    try {
      final brightness = await _channel.invokeMethod('getBrightness');
      return int.tryParse(brightness.toString()) ?? 0;
    } on PlatformException catch (e) {
      print("Get brightness failed: ${e.message}");
      return 0;
    }
  }

  static Future<void> setBrightness(int value) async {
    if (value < 0 || value > 100) {
      print("Invalid brightness value: $value. Must be between 0 and 100");
      return;
    }

    try {
      final result = await _channel
          .invokeMethod('setBrightness', {'brightness': value.toString()});
      print(result);
    } on PlatformException catch (e) {
      print("Set brightness failed: ${e.message}");
    }
  }

  static Future<void> turnScreenOff() async {
    await setBacklight(false);
  }

  static Future<void> turnScreenOn() async {
    await setBacklight(true);
  }

  static Future<String> getDeviceInfo() async {
    try {
      final info = await _channel.invokeMethod('getDeviceInfo');
      return info.toString();
    } on PlatformException catch (e) {
      print("Get device info failed: ${e.message}");
      return '';
    }
  }
}
