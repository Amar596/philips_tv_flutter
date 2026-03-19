import 'package:flutter/material.dart';
import 'dart:io';

class DeviceDetails extends StatefulWidget {
  const DeviceDetails({super.key});

  @override
  State<DeviceDetails> createState() => _DeviceDetailsState();
}

class _DeviceDetailsState extends State<DeviceDetails> {
  late Map<String, String> _deviceDetails;

  @override
  void initState() {
    super.initState();
    _deviceDetails = {};
    _getBasicDeviceInfo();
  }

  void _getBasicDeviceInfo() {
    // Get basic device information using available APIs that don't need context
    final details = <String, String>{};

    // Platform info - these don't need context
    details['Platform'] = Platform.operatingSystem;
    details['OS Version'] = Platform.operatingSystemVersion;
    details['Local Hostname'] = Platform.localHostname;
    details['Number of Processors'] = '${Platform.numberOfProcessors}';
    details['Path Separator'] = Platform.pathSeparator;

    setState(() {
      _deviceDetails = details;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Get screen info in build method (safe to use MediaQuery here)
    final mediaQuery = MediaQuery.of(context);

    // Create a copy of the details with screen info
    final Map<String, String> allDetails = Map.from(_deviceDetails);
    allDetails['Screen Size'] =
        '${mediaQuery.size.width.toStringAsFixed(0)} x ${mediaQuery.size.height.toStringAsFixed(0)}';
    allDetails['Pixel Ratio'] = mediaQuery.devicePixelRatio.toStringAsFixed(2);
    allDetails['Screen Width'] =
        '${mediaQuery.size.width.toStringAsFixed(0)} px';
    allDetails['Screen Height'] =
        '${mediaQuery.size.height.toStringAsFixed(0)} px';
    allDetails['Text Scale'] = mediaQuery.textScaleFactor.toStringAsFixed(2);

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
          // Header
          const Row(
            children: [
              Icon(Icons.devices, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Device Information',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Device Details Content
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: allDetails.entries.map((entry) {
                return _buildDetailRow(entry.key, entry.value);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
