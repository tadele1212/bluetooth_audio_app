import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'bluetooth_utils.dart';

class BluetoothService {
  // We don't need to create an instance variable since we access static methods
  bool _isScanning = false;
  List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  StreamSubscription? _scanResultsSubscription;

  // Stream controllers
  final StreamController<List<BluetoothDevice>> _devicesController =
      StreamController<List<BluetoothDevice>>.broadcast();
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;

  final StreamController<BluetoothDevice?> _connectedDeviceController =
      StreamController<BluetoothDevice?>.broadcast();
  Stream<BluetoothDevice?> get connectedDeviceStream =>
      _connectedDeviceController.stream;

  // New stream for connection errors or messages
  final StreamController<String?> _connectionMessageController =
      StreamController<String?>.broadcast();
  Stream<String?> get connectionMessageStream =>
      _connectionMessageController.stream;

  Future<void> initialize() async {
    // Request ALL necessary permissions for Bluetooth scanning
    final bluetoothStatus = await Permission.bluetooth.request();
    final bluetoothScanStatus = await Permission.bluetoothScan.request();
    final bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    final locationStatus =
        await Permission.location
            .request(); // Required for BLE scanning on Android

    if (bluetoothStatus != PermissionStatus.granted ||
        bluetoothScanStatus != PermissionStatus.granted ||
        bluetoothConnectStatus != PermissionStatus.granted ||
        locationStatus != PermissionStatus.granted) {
      throw Exception('One or more required permissions not granted');
    }

    // Initialize BluetoothAdapter if needed
    final isAvailable = await FlutterBluePlus.isAvailable;
    if (!isAvailable) {
      throw Exception('Bluetooth is not available on this device');
    }

    // Try to turn on Bluetooth if it's not already on
    if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
      // Note: this may not work on all devices and requires user interaction on iOS
      await FlutterBluePlus.turnOn();
    }

    // Listen to Bluetooth state changes
    FlutterBluePlus.adapterState.listen((state) {
      debugPrint('Bluetooth state changed: $state');
      if (state == BluetoothAdapterState.off) {
        stopScan();
        _connectedDevice = null;
        _connectedDeviceController.add(null);
      }
    });

    // Check for devices that are already connected via system settings
    await _checkForSystemConnectedDevices();
  }

  // Check for devices that are already connected via system settings
  Future<void> _checkForSystemConnectedDevices() async {
    try {
      final bondedDevices = await BluetoothUtils.getBondedDevices();

      // If we have a previously selected audio device, update the UI to reflect it's connected
      for (final device in bondedDevices) {
        if (BluetoothUtils.isLikelyAudioDevice(device)) {
          debugPrint(
            'Found previously bonded audio device: ${device.platformName}',
          );

          // We'll consider bonded audio devices as "connected" for UI purposes
          _connectedDevice = device;
          _connectedDeviceController.add(device);

          // No need to check more devices
          break;
        }
      }
    } catch (e) {
      debugPrint('Error checking for system-connected devices: $e');
    }
  }

  Future<void> startScan() async {
    if (_isScanning) return;

    // Clear any previous connection message
    _connectionMessageController.add(null);

    // Cancel any existing subscription
    await _scanResultsSubscription?.cancel();

    // Clear previously discovered devices
    _scanResults = [];
    _devicesController.add([]);

    try {
      // Start listening for scan results
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen(
        (results) {
          debugPrint('Received ${results.length} scan results');
          _scanResults = results;

          // Don't filter by name - include all devices
          final devices = _scanResults.map((result) => result.device).toList();

          // Debug output
          for (var device in devices) {
            debugPrint(
              'Found device: ${device.platformName} (${device.remoteId})',
            );
          }

          _devicesController.add(devices);
        },
        onError: (error) {
          debugPrint('Scan error: $error');
          _isScanning = false;
        },
      );

      // Set scanning flag
      _isScanning = true;

      // Configure scan settings for better device discovery
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidScanMode:
            AndroidScanMode
                .lowLatency, // Use more power but find devices faster
      );

      // Scan finished
      _isScanning = false;
      debugPrint('Bluetooth scan completed');
    } catch (e) {
      _isScanning = false;
      debugPrint('Error starting Bluetooth scan: $e');
      rethrow;
    }
  }

  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      debugPrint('Error stopping scan: $e');
    }

    _isScanning = false;

    // Don't cancel the subscription here, as we still want to receive any pending results
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      // Log device info for debugging
      BluetoothUtils.logDeviceInfo(device);
      debugPrint(
        'Connecting to device: ${device.platformName} (${device.remoteId})',
      );

      // Check if this is an audio device
      if (BluetoothUtils.isLikelyAudioDevice(device)) {
        debugPrint(
          'This is an audio device - using system settings connection flow',
        );
        return await _handleAudioDeviceConnection(device);
      }

      // For non-audio devices, use the regular connection flow
      // For audio devices, we need to use the system pairing first
      // This shows a system dialog for pairing on Android
      bool bondResult = await _bondDeviceIfNeeded(device);
      if (!bondResult) {
        debugPrint('Failed to bond with device ${device.platformName}');
        return false;
      }

      // Get list of already bonded devices for debugging
      await BluetoothUtils.getBondedDevices();

      // Set connection parameters for better reliability
      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 30),
      );

      debugPrint('Successfully connected to device: ${device.platformName}');

      // For audio devices, we need to route audio through the system
      // This typically happens automatically once the device is connected

      _connectedDevice = device;
      _connectedDeviceController.add(device);
      return true;
    } catch (e) {
      final errorMessage = BluetoothUtils.getReadableError(e);
      debugPrint('Error connecting to device: $errorMessage');

      // Try to clean up any partial connection
      try {
        await device.disconnect();
      } catch (_) {
        // Ignore errors in cleanup
      }

      return false;
    }
  }

  // Special handling for audio devices like headphones, speakers, etc.
  Future<bool> _handleAudioDeviceConnection(BluetoothDevice device) async {
    try {
      // Check if device is already bonded (paired)
      List<BluetoothDevice> bondedDevices = [];
      try {
        bondedDevices = await FlutterBluePlus.bondedDevices;
      } catch (e) {
        debugPrint('Error getting bonded devices: $e');
      }

      bool isBonded = bondedDevices.any((d) => d.remoteId == device.remoteId);

      if (isBonded) {
        // If the device is already bonded, we can consider it "connected" for our purposes
        _connectedDevice = device;
        _connectedDeviceController.add(device);

        // Notify the user about using system media controls
        _connectionMessageController.add(
          'Audio device "${device.platformName}" is paired. Use your system media controls to play audio.',
        );

        return true;
      } else {
        // We need to direct the user to system settings for audio devices
        _connectionMessageController.add(
          'Audio devices like "${device.platformName}" need to be connected through system settings. Opening settings now.',
        );

        // Open system Bluetooth settings
        await BluetoothUtils.openSystemBluetoothSettings();

        // After opening settings, mark this as "in progress" in the UI
        return true;
      }
    } catch (e) {
      debugPrint('Error handling audio device connection: $e');
      _connectionMessageController.add(
        'Failed to set up audio device. Please try connecting manually in system settings.',
      );
      return false;
    }
  }

  // Helper method to bond with the device if needed
  Future<bool> _bondDeviceIfNeeded(BluetoothDevice device) async {
    try {
      // Check if device is already bonded (paired)
      List<BluetoothDevice> bondedDevices = [];
      try {
        bondedDevices = await FlutterBluePlus.bondedDevices;
      } catch (e) {
        debugPrint('Error getting bonded devices: $e');
      }

      bool isBonded = bondedDevices.any((d) => d.remoteId == device.remoteId);

      if (isBonded) {
        debugPrint('Device ${device.platformName} is already bonded');
        return true;
      }

      // For Android, we need to explicitly bond (pair) the device
      debugPrint('Trying to bond with device ${device.platformName}');

      // Request to bond - this usually shows a system pairing dialog
      await device.pair();

      // Wait for bonding to complete (this can take some time)
      bool success = await Future.delayed(
        const Duration(seconds: 10),
        () async {
          try {
            bondedDevices = await FlutterBluePlus.bondedDevices;
            return bondedDevices.any((d) => d.remoteId == device.remoteId);
          } catch (e) {
            debugPrint('Error checking bond status: $e');
            return false;
          }
        },
      );

      debugPrint('Bond result for ${device.platformName}: $success');
      return success;
    } catch (e) {
      debugPrint('Bonding error: $e');
      return false;
    }
  }

  Future<void> disconnectDevice() async {
    if (_connectedDevice == null) return;

    // Clear any connection messages
    _connectionMessageController.add(null);

    try {
      // For audio devices, just update the UI state since we can't really disconnect them programmatically
      if (BluetoothUtils.isLikelyAudioDevice(_connectedDevice!)) {
        debugPrint('Audio device - just updating UI state, not disconnecting');
        _connectionMessageController.add(
          'To disconnect audio devices, use your system Bluetooth settings.',
        );
      } else {
        // For non-audio devices, actually disconnect
        await _connectedDevice!.disconnect();
      }

      _connectedDevice = null;
      _connectedDeviceController.add(null);
    } catch (e) {
      debugPrint('Error disconnecting from device: $e');
    }
  }

  // Clean up resources
  void dispose() {
    _scanResultsSubscription?.cancel();
    stopScan();
    _devicesController.close();
    _connectedDeviceController.close();
    _connectionMessageController.close();
  }

  bool get isScanning => _isScanning;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get discoveredDevices =>
      _scanResults.map((result) => result.device).toList();
}
