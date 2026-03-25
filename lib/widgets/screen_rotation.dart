import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ScreenRotation extends StatefulWidget {
  const ScreenRotation({super.key});

  @override
  State<ScreenRotation> createState() => _ScreenRotationState();
}

class _ScreenRotationState extends State<ScreenRotation>
    with WidgetsBindingObserver {
  String _currentOrientation = 'Auto';
  final List<String> _orientations = ['Portrait', 'Landscape', 'Auto'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Don't call _getCurrentOrientation here - it needs context
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safe to use MediaQuery here
    _getCurrentOrientation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Also update when screen metrics change (orientation change)
    if (mounted) {
      _getCurrentOrientation();
    }
  }

  void _getCurrentOrientation() {
    // This is now safe because it's called after initState
    final orientation = MediaQuery.of(context).orientation;
    setState(() {
      if (orientation == Orientation.portrait) {
        _currentOrientation = 'Portrait';
      } else if (orientation == Orientation.landscape) {
        _currentOrientation = 'Landscape';
      }
    });
  }

  Future<void> _setOrientation(String orientation) async {
    try {
      switch (orientation) {
        case 'Portrait':
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
          break;
        case 'Landscape':
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          break;
        case 'Auto':
          await SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
          break;
      }

      setState(() {
        _currentOrientation = orientation;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Orientation changed to $orientation'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 1),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to change orientation'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.screen_rotation, color: Colors.greenAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Screen Rotation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _orientations.map((orientation) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () => _setOrientation(orientation),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentOrientation == orientation
                          ? Colors.greenAccent
                          : Colors.grey.withOpacity(0.2),
                      foregroundColor: _currentOrientation == orientation
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(orientation),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Current: $_currentOrientation',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
