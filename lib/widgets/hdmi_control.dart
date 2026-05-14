import 'dart:async';

import 'package:flutter/material.dart';
import 'package:philips_tv_flutter/services/hdmi_control_service.dart';

class HdmiControl extends StatefulWidget {
  const HdmiControl({super.key});

  @override
  State<HdmiControl> createState() => _HdmiControlState();
}

class _HdmiControlState extends State<HdmiControl> {
  bool _isLoading = true;

  bool _signalAvailable = false;

  List<dynamic> _hdmiSources = [];

  Timer? _hdmiTimer;

  @override
  void initState() {
    super.initState();

    _loadHdmiData();

    _hdmiTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadHdmiData(),
    );
  }

  Future<void> _loadHdmiData() async {
    try {
      final sources = await HdmiControlService.getHdmiSources();

      final signal = await HdmiControlService.getHdmiSignalStatus();

      if (!mounted) return;

      setState(() {
        _hdmiSources = sources;

        _signalAvailable = signal?['signalAvailable'] ?? false;

        _isLoading = false;
      });
    } catch (e) {
      debugPrint('HDMI load error: $e');
    }
  }

  @override
  void dispose() {
    _hdmiTimer?.cancel();
    super.dispose();
  }

  Future<void> _stopHdmi(int sourceId) async {
    final success = await HdmiControlService.stopHdmiSignal(
      sourceId,
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'HDMI signal stopped' : 'Failed to stop HDMI signal',
        ),
        backgroundColor: success ? Colors.orange : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2027),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.deepPurpleAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurpleAccent.withOpacity(
                    0.2,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.tv,
                  color: Colors.deepPurpleAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'HDMI Control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _signalAvailable ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _signalAvailable
                          ? Icons.settings_input_hdmi
                          : Icons.portable_wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _signalAvailable ? 'Signal' : 'No Signal',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          /// HDMI SOURCES
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            )
          else if (_hdmiSources.isEmpty)
            const Text(
              'No HDMI sources found',
              style: TextStyle(
                color: Colors.white70,
              ),
            )
          else
            Column(
              children: _hdmiSources.map((source) {
                final id = source['id'];

                final name = source['name'];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.settings_input_hdmi,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Source ID: $id',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ElevatedButton(
                            onPressed: () =>
                                HdmiControlService.switchHdmiSource(id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                            ),
                            child: const Text('Open'),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => _stopHdmi(id),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade800,
                            ),
                            child: const Text('Stop'),
                          ),
                        ],
                      )
                      // ElevatedButton(
                      //   onPressed: () => _stopHdmi(id),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.orange.shade800,
                      //   ),
                      //   child: const Text(
                      //     'Stop',
                      //   ),
                      // ),
                    ],
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 12),

          /// INFO BOX
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.deepPurpleAccent.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Monitor HDMI sources and stop HDMI input signals dynamically.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
