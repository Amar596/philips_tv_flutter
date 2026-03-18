import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class NativeEventService {
  static const String channelName = 'com.example.watchdog_app/wauly_events';
  static const _channel = EventChannel(channelName);

  static Stream<String> get eventStream {
    debugPrint('🟢 NativeEventService: Setting up stream on $channelName');

    // Add a small delay to ensure native side is ready
    return _channel.receiveBroadcastStream().map((event) {
      debugPrint('📦 NativeEventService: Received → $event');
      return event.toString();
    }).handleError((error) {
      debugPrint('🔴 NativeEventService ERROR: $error');
      // Return an empty stream on error to prevent app crash
      return Stream.empty();
    });
  }
}
