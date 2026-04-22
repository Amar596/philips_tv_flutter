import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';

class TerminalOverlay extends StatefulWidget {
  final VoidCallback? onClose;

  const TerminalOverlay({Key? key, this.onClose}) : super(key: key);

  @override
  State<TerminalOverlay> createState() => _TerminalOverlayState();
}

class _TerminalOverlayState extends State<TerminalOverlay> {
  List<String> _terminalLines = [];
  Timer? _updateTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTerminalData();
    // Auto-refresh every 2 seconds
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _loadTerminalData();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTerminalData() async {
    try {
      // Method 1: Get logcat output (Android)
      if (Platform.isAndroid) {
        final result = await Process.run('logcat', ['-d', '-t', '50']);
        if (result.exitCode == 0) {
          final lines = result.stdout.toString().split('\n');
          setState(() {
            _terminalLines = lines.reversed.take(50).toList().reversed.toList();
          });
          _autoScroll();
        }
      }

      // Method 2: Get system logs (Alternative)
      // You can also read from your app's log files
      // final directory = await getApplicationDocumentsDirectory();
      // final logFile = File('${directory.path}/app_logs.txt');
      // if (await logFile.exists()) {
      //   final lines = await logFile.readAsLines();
      //   setState(() {
      //     _terminalLines = lines.take(50).toList();
      //   });
      // }
    } catch (e) {
      setState(() {
        _terminalLines = [
          'Error loading terminal data: $e',
          'Make sure the app has appropriate permissions',
        ];
      });
    }
  }

  void _autoScroll() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.95),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              border: Border(bottom: BorderSide(color: Colors.white, width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.black, size: 30),
                const SizedBox(width: 10),
                const Text(
                  'Terminal Monitor',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                // Close button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.black),
                  onPressed: () {
                    if (widget.onClose != null) {
                      widget.onClose!();
                    }
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),

          // Terminal content
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(10),
              itemCount: _terminalLines.length,
              itemBuilder: (context, index) {
                final line = _terminalLines[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: SelectableText(
                    line,
                    style: const TextStyle(
                      color: Colors.green,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer with instructions
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.green,
              border: Border(top: BorderSide(color: Colors.white, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline, color: Colors.black, size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Press 777 again to refresh | Press BACK to close',
                  style: TextStyle(color: Colors.black, fontSize: 12),
                ),
                const Spacer(),
                IconButton(
                  icon:
                      const Icon(Icons.refresh, color: Colors.black, size: 20),
                  onPressed: _loadTerminalData,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
