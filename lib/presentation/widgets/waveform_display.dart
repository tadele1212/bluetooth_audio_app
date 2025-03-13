import 'package:flutter/material.dart';
import 'dart:math' as math;

class WaveformDisplay extends StatefulWidget {
  final double audioLevel;
  final bool isRecording;
  final bool isVisible;

  const WaveformDisplay({
    super.key,
    required this.audioLevel,
    required this.isRecording,
    this.isVisible = true, // Default to visible
  });

  @override
  State<WaveformDisplay> createState() => _WaveformDisplayState();
}

class _WaveformDisplayState extends State<WaveformDisplay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _waveformLevels = List<double>.filled(
    40,
    0.0,
    growable: true,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    if (widget.isVisible) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WaveformDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle visibility changes
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        if (mounted) _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    }

    // Only update waveform data if visible and recording
    if (widget.isVisible && widget.isRecording) {
      // Update waveform data by shifting values to the left
      setState(() {
        final newLevels = List<double>.from(_waveformLevels);
        newLevels.removeAt(0);
        newLevels.add(widget.audioLevel);
        _waveformLevels.clear();
        _waveformLevels.addAll(newLevels);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If not visible, return a simple container to prevent render issues
    if (!widget.isVisible) {
      return Container();
    }

    return Stack(
      children: [
        // Waveform visualization
        CustomPaint(
          painter: WaveformPainter(
            waveformLevels: _waveformLevels,
            color: Theme.of(context).primaryColor,
            isRecording: widget.isRecording,
            animationValue: _animationController.value,
          ),
          size: Size.infinite,
        ),

        // Recording indicator and status text
        Positioned(
          top: 10,
          left: 10,
          child: Row(
            children: [
              if (widget.isRecording) ...[
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withAlpha(
                          ((0.5 + _animationController.value * 0.5) * 255)
                              .toInt(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                const Text(
                  'Recording',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ] else
                const Text(
                  'Not Recording',
                  style: TextStyle(color: Colors.grey),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class WaveformPainter extends CustomPainter {
  final List<double> waveformLevels;
  final Color color;
  final bool isRecording;
  final double animationValue;

  WaveformPainter({
    required this.waveformLevels,
    required this.color,
    required this.isRecording,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = isRecording ? color : color.withAlpha((0.3 * 255).toInt())
          ..strokeWidth = 3.0
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    final spacing = size.width / (waveformLevels.length - 1);
    final middle = size.height / 2;
    final maxHeight = size.height * 0.8;

    final path = Path();
    var startedPath = false;

    for (var i = 0; i < waveformLevels.length; i++) {
      // Calculate height based on audio level and apply a slight randomization if recording
      var level = waveformLevels[i];
      if (isRecording) {
        final randomFactor = math.Random().nextDouble() * 0.1 - 0.05;
        level = math.max(
          0,
          math.min(1, level + (isRecording ? randomFactor : 0)),
        );
      }

      final x = i * spacing;
      final heightAdjustment = isRecording ? animationValue * 0.1 : 0;
      final height = level * maxHeight * (1 + heightAdjustment);
      final y = middle - height / 2;

      if (!startedPath) {
        path.moveTo(x, y + height);
        startedPath = true;
      } else {
        path.lineTo(x, y);
        path.lineTo(x, y + height);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.isRecording != isRecording ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.waveformLevels != waveformLevels;
  }
}
