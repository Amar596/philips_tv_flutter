// lib/services/remote_key_service.dart

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

class RemoteKeyService {
  static const MethodChannel _channel = MethodChannel('remote_key_channel');

  static final List<int> _keySequence = [];
  static Timer? _sequenceTimer;
  static bool _isListening = false;
  static bool _processingSequence = false;

  // Track last key to avoid duplicates
  static String _lastKey = '';
  static DateTime _lastKeyTime = DateTime.now();

  // Callback when 777 sequence is detected
  static VoidCallback? on777Detected;

  // Start listening for remote key presses
  static void startListening() {
    if (_isListening) return;

    _isListening = true;
    _channel.setMethodCallHandler(_handleMethodCall);
    print('🎮 Remote key service started listening');
  }

  // Stop listening
  static void stopListening() {
    _isListening = false;
    _channel.setMethodCallHandler(null);
    _clearSequence();
    print('🎮 Remote key service stopped');
  }

  // Handle incoming method calls from Android
  static Future<void> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onKeyPressed') {
      final int keyCode = call.arguments['keyCode'];
      final String keyChar = call.arguments['keyChar'] ?? '';
      await _processKeyPress(keyCode, keyChar);
    }
  }

  // Process key press and detect 777 sequence
  static Future<void> _processKeyPress(int keyCode, String keyChar) async {
    if (_processingSequence) return;

    // Debounce: Ignore if same key pressed within 150ms
    final now = DateTime.now();
    if (keyChar == _lastKey &&
        now.difference(_lastKeyTime).inMilliseconds < 150) {
      print('⏭️ Debounced duplicate key: $keyChar');
      return;
    }

    _lastKey = keyChar;
    _lastKeyTime = now;

    print('🔑 Key pressed: code=$keyCode, char=$keyChar');

    // Only process number keys (7, 8, 9)
    if (keyChar == '7' || keyChar == '8' || keyChar == '9') {
      final int number = int.parse(keyChar);
      print('🔢 Number detected: $number');

      _keySequence.add(number);
      print('📝 Current sequence: $_keySequence');

      // Reset timer after each key press (2 second window)
      _sequenceTimer?.cancel();
      _sequenceTimer = Timer(const Duration(seconds: 2), () {
        print('⏰ Sequence timeout, clearing');
        _clearSequence();
      });

      // Check if we have exactly 3 numbers
      if (_keySequence.length == 3) {
        _processingSequence = true;

        final String sequence = _keySequence.join();
        print('🎯 Complete sequence: $sequence');

        if (sequence == '777') {
          print('✅ 777 SEQUENCE DETECTED!');
          _clearSequence();

          // Trigger the callback with a small delay to ensure UI is ready
          Future.delayed(const Duration(milliseconds: 100), () {
            if (on777Detected != null) {
              on777Detected!();
            }
            _processingSequence = false;
          });
        } else {
          print('❌ Wrong sequence: $sequence (expected 777)');
          _clearSequence();
          _processingSequence = false;
        }
      }
    } else {
      // Non-number key pressed, clear sequence
      if (_keySequence.isNotEmpty) {
        print('🔄 Non-number key pressed, clearing sequence');
        _clearSequence();
      }
    }
  }

  static void _clearSequence() {
    _keySequence.clear();
    _sequenceTimer?.cancel();
    _sequenceTimer = null;
    _processingSequence = false;
  }

  // Manual trigger for testing
  static void manualTrigger() {
    print('🎮 Manual trigger - simulating 777');
    if (on777Detected != null) {
      on777Detected!();
    }
  }
}
