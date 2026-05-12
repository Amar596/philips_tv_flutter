import 'dart:async';
import 'package:flutter/material.dart';
import 'package:philips_tv_flutter/services/usb_control_service.dart';


class UsbControl extends StatefulWidget {
  const UsbControl({super.key});

  @override
  State<UsbControl> createState() => _UsbControlState();
}

class _UsbControlState extends State<UsbControl> {
  bool? _isUsbEnabled;
  bool _isLoading = true;
  bool _isDeviceConnected = false;
  Timer? _usbTimer;

  @override
  void initState() {
    super.initState();
    _loadUsbStatus();

    _usbTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _loadUsbStatus(),
    );
  }

  Future<void> _loadUsbStatus() async {
    setState(() => _isLoading = true);
    final status = await UsbControlService.getUsbStatus();
    setState(() {
      _isUsbEnabled = status?['portsEnabled'];
      _isDeviceConnected = status?['deviceConnected'] ?? false;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _usbTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleUsbPorts(bool enable) async {
    setState(() => _isLoading = true);

    final success = await UsbControlService.setUsbPortsEnabled(enable);

    if (success) {
      setState(() {
        _isUsbEnabled = enable;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(enable ? 'USB ports enabled' : 'USB ports disabled'),
            backgroundColor: enable ? Colors.green : Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to control USB ports'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2027),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    const Icon(Icons.usb, color: Colors.cyanAccent, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'USB Port Control',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Connection Status Icon
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isUsbEnabled == null
                      ? Colors.grey
                      : (_isDeviceConnected ? Colors.green : Colors.red),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isUsbEnabled == null
                          ? Icons.help_outline
                          : (_isDeviceConnected ? Icons.usb : Icons.usb_off),
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isUsbEnabled == null
                          ? 'Unknown'
                          : (_isDeviceConnected ? 'USB Connected' : 'No USB'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Icon(
                    _isUsbEnabled == true ? Icons.toggle_on : Icons.toggle_off,
                    color: _isUsbEnabled == true ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isUsbEnabled == true
                        ? 'USB Ports Enabled'
                        : 'USB Ports Disabled',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _toggleUsbPorts(true),
                  icon: _isLoading && _isUsbEnabled != true
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.usb, color: Colors.white),
                  label: const Text('Enable USB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => _toggleUsbPorts(false),
                  icon: _isLoading && _isUsbEnabled == true
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.usb_off, color: Colors.white),
                  label: const Text('Disable USB'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
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
                  color: Colors.cyanAccent.withOpacity(0.7),
                  size: 16,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Enable/Disable USB ports on the TV. Disabling USB ports will prevent USB devices from being detected.',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
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
