import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../services/bluetooth/bluetooth_utils.dart';

class BluetoothControls extends StatefulWidget {
  final bool isBluetoothOn;
  final bool isScanning;
  final List<BluetoothDevice> discoveredDevices;
  final BluetoothDevice? connectedDevice;
  final String? connectionMessage;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final Future<bool> Function(BluetoothDevice) onConnectToDevice;
  final VoidCallback onDisconnectDevice;
  final VoidCallback? onOpenSystemSettings;

  const BluetoothControls({
    super.key,
    required this.isBluetoothOn,
    required this.isScanning,
    required this.discoveredDevices,
    required this.connectedDevice,
    this.connectionMessage,
    required this.onStartScan,
    required this.onStopScan,
    required this.onConnectToDevice,
    required this.onDisconnectDevice,
    this.onOpenSystemSettings,
  });

  @override
  State<BluetoothControls> createState() => _BluetoothControlsState();
}

class _BluetoothControlsState extends State<BluetoothControls> {
  // Track which device is currently being connected to
  BluetoothDevice? _connectingDevice;
  String? _connectionError;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Bluetooth status card
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bluetooth Status',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth,
                            color:
                                widget.isBluetoothOn
                                    ? Colors.blue
                                    : Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.isBluetoothOn ? 'On' : 'Off',
                            style: TextStyle(
                              color:
                                  widget.isBluetoothOn
                                      ? Colors.blue
                                      : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Connected device info
                  if (widget.connectedDevice != null) ...[
                    Row(
                      children: [
                        Icon(
                          BluetoothUtils.isLikelyAudioDevice(
                                widget.connectedDevice!,
                              )
                              ? Icons.headphones
                              : Icons.bluetooth_connected,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Connected to:',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              Text(
                                widget.connectedDevice!.platformName.isNotEmpty
                                    ? widget.connectedDevice!.platformName
                                    : widget.connectedDevice!.remoteId
                                        .toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (BluetoothUtils.isLikelyAudioDevice(
                                widget.connectedDevice!,
                              ))
                                Text(
                                  'Audio Device',
                                  style: TextStyle(
                                    color: Colors.blue[700],
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: widget.onDisconnectDevice,
                          icon: const Icon(Icons.link_off),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Connection message (for audio devices)
                  if (widget.connectionMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: Colors.blue,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.connectionMessage!,
                                  style: TextStyle(color: Colors.blue.shade700),
                                ),
                              ),
                            ],
                          ),
                          if (widget.onOpenSystemSettings != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: widget.onOpenSystemSettings,
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Open Settings'),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],

                  // Connection error message
                  if (_connectionError != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _connectionError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () {
                              setState(() {
                                _connectionError = null;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Scan button
          ElevatedButton.icon(
            onPressed:
                widget.isBluetoothOn
                    ? (widget.isScanning
                        ? widget.onStopScan
                        : widget.onStartScan)
                    : null,
            icon: Icon(widget.isScanning ? Icons.stop : Icons.search),
            label: Text(
              widget.isScanning ? 'Stop Scanning' : 'Scan for Devices',
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),

          // System settings button
          if (widget.onOpenSystemSettings != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenSystemSettings,
              icon: const Icon(Icons.settings),
              label: const Text('Open Bluetooth Settings'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 40),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Device list
          Expanded(
            child: Card(
              elevation: 2,
              child:
                  widget.isScanning
                      ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Scanning for devices...'),
                          ],
                        ),
                      )
                      : widget.discoveredDevices.isEmpty
                      ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text('No devices found'),
                            SizedBox(height: 8),
                            Text(
                              'Make sure your device is in pairing mode',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                      : ListView.builder(
                        itemCount: widget.discoveredDevices.length,
                        itemBuilder: (context, index) {
                          final device = widget.discoveredDevices[index];
                          final isConnected =
                              widget.connectedDevice != null &&
                              widget.connectedDevice!.remoteId ==
                                  device.remoteId;
                          final isConnecting =
                              _connectingDevice?.remoteId == device.remoteId;
                          final isAudioDevice =
                              BluetoothUtils.isLikelyAudioDevice(device);

                          return ListTile(
                            leading: Icon(
                              isAudioDevice
                                  ? Icons.headphones
                                  : (isConnected
                                      ? Icons.bluetooth_connected
                                      : Icons.bluetooth),
                              color: isConnected ? Colors.green : Colors.blue,
                            ),
                            title: Text(
                              device.platformName.isNotEmpty
                                  ? device.platformName
                                  : 'Unknown Device (${device.remoteId.toString().substring(0, 8)}...)',
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isConnected
                                      ? 'Connected'
                                      : isConnecting
                                      ? 'Connecting...'
                                      : isAudioDevice
                                      ? 'Audio device - Tap to set up'
                                      : 'Tap to connect',
                                ),
                                if (isAudioDevice)
                                  Text(
                                    'Uses system audio connection',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                      color: Colors.blue[700],
                                    ),
                                  ),
                              ],
                            ),
                            trailing:
                                isConnected
                                    ? const Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                    )
                                    : isConnecting
                                    ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : ElevatedButton(
                                      onPressed: () => _connectToDevice(device),
                                      child: Text(
                                        isAudioDevice ? 'Set Up' : 'Connect',
                                      ),
                                    ),
                          );
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // Handle device connection with proper UI updates
  Future<void> _connectToDevice(BluetoothDevice device) async {
    setState(() {
      _connectingDevice = device;
      _connectionError = null;
    });

    try {
      final result = await widget.onConnectToDevice(device);

      if (!result && mounted) {
        setState(() {
          _connectionError =
              'Failed to connect to ${device.platformName}. Make sure it\'s in pairing mode.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionError = 'Connection error: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _connectingDevice = null;
        });
      }
    }
  }
}
