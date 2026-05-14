import 'package:flutter/material.dart';

class VolumeController extends StatefulWidget {
  const VolumeController({super.key});

  @override
  State<VolumeController> createState() => _VolumeControllerState();
}

class _VolumeControllerState extends State<VolumeController> {
  double _volume = 0.5;
  double _previousVolume = 0.5;
  bool _isMuted = false;

  void _toggleMute() {
    setState(() {
      if (_isMuted) {
        // Unmute
        _volume = _previousVolume == 0 ? 0.5 : _previousVolume;
        _isMuted = false;
      } else {
        // Mute
        _previousVolume = _volume;
        _volume = 0.0;
        _isMuted = true;
      }
    });
  }

  void _updateVolume(double value) {
    setState(() {
      _volume = value;

      if (_volume > 0) {
        _previousVolume = _volume;
        _isMuted = false;
      } else {
        _isMuted = true;
      }
    });
  }

  IconData _getVolumeIcon() {
    if (_isMuted || _volume == 0) {
      return Icons.volume_off;
    } else if (_volume < 0.5) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
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
                  _updateVolume(
                    (_volume - 0.1).clamp(0.0, 1.0),
                  );
                },
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: Colors.white,
                ),
              ),

              Expanded(
                child: Slider(
                  value: _volume,
                  onChanged: _updateVolume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 10,
                  activeColor: Colors.blueAccent,
                  inactiveColor: Colors.grey.withOpacity(0.3),
                ),
              ),

              IconButton(
                onPressed: () {
                  _updateVolume(
                    (_volume + 0.1).clamp(0.0, 1.0),
                  );
                },
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                ),
              ),

              const SizedBox(width: 8),

              // Mute / Unmute Button
              IconButton(
                onPressed: _toggleMute,
                icon: Icon(
                  _getVolumeIcon(),
                  color: _isMuted ? Colors.redAccent : Colors.blueAccent,
                ),
              ),
            ],
          ),
          Center(
            child: Text(
              _isMuted ? 'Muted' : '${(_volume * 100).toInt()}%',
              style: TextStyle(
                color: _isMuted ? Colors.redAccent : Colors.blueAccent,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
