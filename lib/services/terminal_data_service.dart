import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TerminalDataService {
  static final TerminalDataService _instance = TerminalDataService._internal();
  factory TerminalDataService() => _instance;
  TerminalDataService._internal();

  final List<String> _logBuffer = [];
  final int _maxBufferSize = 1000;

  StreamController<List<String>> _logStreamController =
      StreamController<List<String>>.broadcast();
  Stream<List<String>> get logStream => _logStreamController.stream;

  // Store original print function
  void Function(Object?)? _originalPrint;

  // Start capturing logs
  void startCapturing() {
    _captureFlutterLogs();
    if (Platform.isAndroid) {
      _captureLogcat();
    }
    print('📝 Terminal data service started');
  }

  // Capture Android logcat
  Future<void> _captureLogcat() async {
    if (!Platform.isAndroid) return;

    try {
      // Use logcat command to get logs
      final result = await Process.run('logcat', ['-d', '-t', '50']);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) {
            _addLog(line);
          }
        }
      }

      // Alternative: Use Runtime to continuously read logs
      // Note: This requires READ_LOGS permission
      _startContinuousLogcat();
    } catch (e) {
      _addLog('[ERROR] Failed to capture logcat: $e');
    }
  }

  void _startContinuousLogcat() async {
    try {
      final process = await Process.start('logcat', ['-v', 'threadtime']);

      // Read stdout
      process.stdout.transform(SystemEncoding().decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) {
            _addLog(line);
          }
        }
      });

      // Read stderr
      process.stderr.transform(SystemEncoding().decoder).listen((data) {
        final lines = data.split('\n');
        for (var line in lines) {
          if (line.isNotEmpty) {
            _addLog('[STDERR] $line');
          }
        }
      });

      // Handle process exit
      process.exitCode.then((code) {
        _addLog('[INFO] Logcat process exited with code: $code');
      });
    } catch (e) {
      _addLog('[ERROR] Failed to start continuous logcat: $e');
    }
  }

  // Capture Flutter logs using Zone
  void _captureFlutterLogs() {
    // Method 1: Use runZoned to capture all print statements
    // You need to wrap your app initialization with this

    // Method 2: Override print by using a custom callback
    // Since we can't reassign print, we'll create a custom logging system

    // Capture Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      final errorMessage = _formatErrorDetails(details);
      _addLog('[FLUTTER ERROR] $errorMessage');
      // Don't suppress the original error
      FlutterError.presentError(details);
    };

    // Capture uncaught exceptions
    PlatformDispatcher.instance.onError = (error, stack) {
      _addLog('[UNCAUGHT ERROR] $error');
      _addLog('[STACKTRACE] $stack');
      return false; // Allow the error to continue propagating
    };
  }

  String _formatErrorDetails(FlutterErrorDetails details) {
    return '${details.exception}\nStack trace: ${details.stack}';
  }

  // Custom logging function to use instead of print
  static void log(String message) {
    _instance._addLog('[CUSTOM LOG] $message');
    // Still print to console
    debugPrint(message);
  }

  void _addLog(String log) {
    final timestamp = DateTime.now().toIso8601String();
    final formattedLog = '[$timestamp] $log';

    _logBuffer.add(formattedLog);

    // Keep buffer size limited
    while (_logBuffer.length > _maxBufferSize) {
      _logBuffer.removeAt(0);
    }

    // Notify listeners
    _logStreamController.add(_logBuffer.toList());
  }

  List<String> getRecentLogs({int count = 100}) {
    final startIndex = _logBuffer.length - count;
    if (startIndex < 0) {
      return List.from(_logBuffer);
    }
    return List.from(_logBuffer.sublist(startIndex));
  }

  void clearLogs() {
    _logBuffer.clear();
    _logStreamController.add([]);
  }

  void dispose() {
    _logStreamController.close();
  }
}

// Extension to easily add logs from anywhere
extension TerminalLog on String {
  void toTerminal() {
    TerminalDataService.log(this);
  }
}
