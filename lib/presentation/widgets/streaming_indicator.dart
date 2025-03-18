import 'package:flutter/material.dart';

class StreamingIndicator extends StatefulWidget {
  final bool isStreaming;

  const StreamingIndicator({super.key, required this.isStreaming});

  @override
  State<StreamingIndicator> createState() => _StreamingIndicatorState();
}

class _StreamingIndicatorState extends State<StreamingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(StreamingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming != oldWidget.isStreaming) {
      if (widget.isStreaming) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isStreaming ? _scaleAnimation.value : 1.0,
            child: Icon(
              Icons.mic,
              size: 120,
              color:
                  widget.isStreaming
                      ? Theme.of(context).primaryColor
                      : Colors.grey[400],
            ),
          );
        },
      ),
    );
  }
}
