import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HdmiControlService {
  static const MethodChannel _channel = MethodChannel('com.philips.tv/hdmi');

  static Future<List<dynamic>> getHdmiSources() async {
    try {
      final result = await _channel.invokeMethod('getHdmiSources');

      return result ?? [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map?> getHdmiSignalStatus() async {
    try {
      return await _channel.invokeMethod(
        'getHdmiSignalStatus',
      );
    } catch (e) {
      return null;
    }
  }

  static Future<bool> stopHdmiSignal(
    int sourceId,
  ) async {
    try {
      return await _channel.invokeMethod(
        'stopHdmiSignal',
        {
          'sourceId': sourceId,
        },
      );
    } catch (e) {
      return false;
    }
  }

  static Future<bool> switchHdmiSource(int sourceId) async {
    try {
      final result = await _channel
          .invokeMethod('switchHdmiSource', {'sourceId': sourceId});
      return result == true;
    } on MissingPluginException catch (e) {
      debugPrint('❌ Channel not registered: $e — did you do flutter clean?');
      return false;
    } catch (e) {
      debugPrint('❌ Switch HDMI source error: $e');
      return false;
    }
  }
}
