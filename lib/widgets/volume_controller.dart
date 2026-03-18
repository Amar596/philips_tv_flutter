import 'package:flutter/material.dart';

class VolumeController extends StatefulWidget {
  const VolumeController({super.key});

  @override
  State<VolumeController> createState() => _VolumeControllerState();
}

class _VolumeControllerState extends State<VolumeController> {
  double _volume = 0.5;

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
              Icon(Icons.volume_up, color: Colors.blueAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Volume Controller',
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
                    _volume = (_volume - 0.1).clamp(0.0, 1.0);
                  });
                },
                icon: const Icon(Icons.volume_down, color: Colors.white),
              ),
              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: (value) {
                    setState(() {
                      _volume = value;
                    });
                  },
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.grey.withOpacity(0.3),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _volume = (_volume + 0.1).clamp(0.0, 1.0);
                  });
                },
                icon: const Icon(Icons.volume_up, color: Colors.white),
              ),
            ],
          ),
          Center(
            child: Text(
              '${(_volume * 100).toInt()}%',
              style: const TextStyle(color: Colors.blueAccent, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
