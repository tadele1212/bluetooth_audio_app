import 'package:flutter/material.dart';

class AudioControls extends StatelessWidget {
  final bool isRecording;
  final VoidCallback onRecordingToggled;
  final VoidCallback onPlayRecording;
  final VoidCallback onStopPlayback;
  final VoidCallback? onResetAudio;
  final String? errorMessage;

  const AudioControls({
    super.key,
    required this.isRecording,
    required this.onRecordingToggled,
    required this.onPlayRecording,
    required this.onStopPlayback,
    this.onResetAudio,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Error message display
        if (errorMessage != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio Error',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (onResetAudio != null)
                      TextButton.icon(
                        onPressed: onResetAudio,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red.shade700,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage!,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Recording button
        ElevatedButton.icon(
          onPressed: onRecordingToggled,
          icon: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: isRecording ? Colors.red : Colors.white,
          ),
          label: Text(isRecording ? 'Stop Recording' : 'Start Recording'),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isRecording ? Colors.white : Theme.of(context).primaryColor,
            foregroundColor: isRecording ? Colors.red : Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 12),

        // Playback controls
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPlayRecording,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play Recording'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onStopPlayback,
                icon: const Icon(Icons.stop),
                label: const Text('Stop Playback'),
              ),
            ),
          ],
        ),

        // Reset button if needed
        if (onResetAudio != null && errorMessage == null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onResetAudio,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset Audio System'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
            ),
          ),
        ],
      ],
    );
  }
}
