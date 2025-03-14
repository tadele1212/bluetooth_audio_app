import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../business_logic/providers/audio_provider.dart';
import '../../business_logic/providers/bluetooth_provider.dart';
import '../widgets/audio_controls.dart';
import '../widgets/bluetooth_controls.dart';
import '../widgets/volume_slider.dart';
import '../widgets/waveform_display.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Listen to tab changes to track the current index
    _tabController.addListener(_handleTabSelection);
  }

  void _handleTabSelection() {
    // Only update if the tab actually changed and the widget is still mounted
    if (mounted && _tabController.indexIsChanging) {
      setState(() {
        _currentIndex = _tabController.index;
      });
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabSelection);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Audio Streamer'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Audio', icon: Icon(Icons.mic)),
            Tab(text: 'Bluetooth', icon: Icon(Icons.bluetooth)),
          ],
        ),
      ),
      // Use IndexedStack instead of TabBarView to prevent animation issues
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildAudioTab(), _buildBluetoothTab()],
      ),
    );
  }

  Widget _buildAudioTab() {
    return Consumer<AudioProvider>(
      builder: (context, audioProvider, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Audio level waveform display
              Expanded(
                flex: 3,
                child: Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: WaveformDisplay(
                      audioLevel: audioProvider.audioLevel,
                      isRecording: audioProvider.isStreaming,
                      isVisible: _currentIndex == 0,
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
                onResetAudio: audioProvider.resetAudio,
                errorMessage: audioProvider.errorMessage,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBluetoothTab() {
    return Consumer<BluetoothProvider>(
      builder: (context, bluetoothProvider, child) {
        return BluetoothControls(
          isBluetoothOn: bluetoothProvider.isBluetoothOn,
          isScanning: bluetoothProvider.isScanning,
          discoveredDevices: bluetoothProvider.discoveredDevices,
          connectedDevice: bluetoothProvider.connectedDevice,
          connectionMessage: bluetoothProvider.connectionMessage,
          onStartScan: bluetoothProvider.startScan,
          onStopScan: bluetoothProvider.stopScan,
          onConnectToDevice: bluetoothProvider.connectToDevice,
          onDisconnectDevice: bluetoothProvider.disconnectDevice,
          onOpenSystemSettings: () async {
            await bluetoothProvider.openSystemBluetoothSettings();
            // After returning from settings, refresh the devices
            Future.delayed(
              const Duration(seconds: 2),
              () => bluetoothProvider.refreshDevices(),
            );
          },
        );
      },
    );
  }
}
