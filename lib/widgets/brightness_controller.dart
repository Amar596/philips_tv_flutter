import 'package:flutter/material.dart';

class BrightnessController extends StatefulWidget {
  const BrightnessController({super.key});

  @override
  State<BrightnessController> createState() => _BrightnessControllerState();
}

class _BrightnessControllerState extends State<BrightnessController> {
  double _brightness = 0.8;

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
              Icon(Icons.brightness_6, color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Brightness Controller',
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
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _brightness = (_brightness - 0.1).clamp(0.1, 1.0);
                  });
                },
                icon: const Icon(Icons.brightness_low, color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _brightness,
                  onChanged: (value) {
                    setState(() {
                      _brightness = value;
                    });
                  },
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  activeColor: Colors.orangeAccent,
                  inactiveColor: Colors.grey.withOpacity(0.3),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _brightness = (_brightness + 0.1).clamp(0.1, 1.0);
                  });
                },
                icon: const Icon(Icons.brightness_high, color: Colors.white),
              ),
            ],
          ),
          Center(
            child: Text(
              '${(_brightness * 100).toInt()}%',
              style: const TextStyle(color: Colors.orangeAccent, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
