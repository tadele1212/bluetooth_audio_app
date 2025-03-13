import 'package:flutter/material.dart';

class VolumeSlider extends StatelessWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const VolumeSlider({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.volume_mute),
        Expanded(
          child: Slider(
            value: volume,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            onChanged: onVolumeChanged,
            activeColor: Theme.of(context).primaryColor,
          ),
        ),
        const Icon(Icons.volume_up),
      ],
    );
  }
}
