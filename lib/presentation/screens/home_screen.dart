import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../business_logic/providers/audio_provider.dart';
import '../widgets/audio_controls.dart';
import '../widgets/volume_slider.dart';
import '../widgets/streaming_indicator.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bluetooth Audio Streamer')),
      body: Consumer<AudioProvider>(
        builder: (context, audioProvider, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Streaming status indicator
                Expanded(
                  flex: 3,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: StreamingIndicator(
                        isStreaming: audioProvider.isStreaming,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Volume adjustment slider
                Text(
                  'Amplification Level',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Adjust volume to amplify sounds through your Bluetooth device',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                VolumeSlider(
                  volume: audioProvider.volume,
                  onVolumeChanged: audioProvider.setVolume,
                ),
                const SizedBox(height: 24),

                // Audio controls
                AudioControls(
                  isStreaming: audioProvider.isStreaming,
                  onStreamingToggled: audioProvider.toggleStreaming,
                  errorMessage: audioProvider.errorMessage,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
