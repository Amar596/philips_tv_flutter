// lib/widgets/key_feedback_overlay.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:philips_tv_flutter/main.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class KeyFeedbackOverlay {
  static OverlayEntry? _overlayEntry;
  static Timer? _hideTimer;

  static void showKeyPressed(String key) {
    // Remove existing overlay
    _hideTimer?.cancel();
    _overlayEntry?.remove();

    // Get the current overlay state
    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 100,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.green, width: 2),
            ),
            child: Text(
              'Pressed: $key',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    // Auto-hide after 1 second
    _hideTimer = Timer(const Duration(seconds: 1), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  static void showSequenceProgress(List<int> sequence) {
    if (sequence.isEmpty) return;

    _hideTimer?.cancel();
    _overlayEntry?.remove();

    final overlay = navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    final sequenceText = sequence.join('');
    final expectedLength = 3 - sequence.length;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        right: 20,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.8),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.cyan, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sequence Detected',
                style: TextStyle(color: Colors.cyan, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...sequence.map((num) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          num.toString(),
                          style: const TextStyle(
                              color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      )),
                  ...List.generate(
                      expectedLength,
                      (index) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('?',
                                style: TextStyle(color: Colors.white)),
                          )),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    _hideTimer = Timer(const Duration(seconds: 2), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }
}
