import 'package:flutter/material.dart';

class AudioControls extends StatelessWidget {
  final bool isStreaming;
  final VoidCallback onStreamingToggled;
  final VoidCallback? onResetAudio;
  final String? errorMessage;

  const AudioControls({
    super.key,
    required this.isStreaming,
    required this.onStreamingToggled,
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

        // Hearing aid mode banner
        if (isStreaming) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.hearing, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hearing Aid Active',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Microphone audio is being streamed to your Bluetooth device',
                        style: TextStyle(color: Colors.green.shade800),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Streaming button
        ElevatedButton.icon(
          onPressed: onStreamingToggled,
          icon: Icon(
            isStreaming ? Icons.hearing_disabled : Icons.hearing,
            color: isStreaming ? Colors.red : Colors.white,
            size: 28,
          ),
          label: Text(
            isStreaming ? 'Stop Hearing Aid' : 'Start Hearing Aid',
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor:
                isStreaming ? Colors.white : Theme.of(context).primaryColor,
            foregroundColor: isStreaming ? Colors.red : Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side:
                  isStreaming
                      ? const BorderSide(color: Colors.red, width: 2)
                      : BorderSide.none,
            ),
          ),
        ),

        // Usage instructions
        if (!isStreaming) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How to use:',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.looks_one,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Connect your Bluetooth earbuds or hearing device',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.looks_two,
                      color: Colors.blue.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Adjust the volume slider to your preferred level',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.looks_3, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Press "Start Hearing Aid" to begin streaming audio',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

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
