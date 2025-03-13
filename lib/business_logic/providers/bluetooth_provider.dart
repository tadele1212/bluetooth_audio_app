import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' hide BluetoothService;
import '../../services/bluetooth/bluetooth_service.dart';
import '../../services/bluetooth/bluetooth_utils.dart';

class BluetoothProvider with ChangeNotifier {
  final BluetoothService _bluetoothService = BluetoothService();
  bool _isInitialized = false;
  bool _isBluetoothOn = false;
  bool _isScanning = false;
  List<BluetoothDevice> _discoveredDevices = [];
  BluetoothDevice? _connectedDevice;
  String? _connectionMessage;

  BluetoothProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _bluetoothService.initialize();
      _isInitialized = true;

      // Check if Bluetooth is on
      FlutterBluePlus.adapterState.listen((state) {
        _isBluetoothOn = state == BluetoothAdapterState.on;
        notifyListeners();
      });

      // Listen to discovered devices
      _bluetoothService.devicesStream.listen((devices) {
        _discoveredDevices = devices;
        notifyListeners();
      });

      // Listen to connected device changes
      _bluetoothService.connectedDeviceStream.listen((device) {
        _connectedDevice = device;
        notifyListeners();
      });

      // Listen to connection messages
      _bluetoothService.connectionMessageStream.listen((message) {
        _connectionMessage = message;
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error initializing Bluetooth service: $e');
    }
  }

  Future<void> startScan() async {
    if (!_isInitialized) await _initialize();

    if (_isBluetoothOn) {
      await _bluetoothService.startScan();
      _isScanning = true;
      notifyListeners();

      // Automatically set to false after scan completes (15 seconds)
      Future.delayed(const Duration(seconds: 15), () {
        _isScanning = false;
        notifyListeners();
      });
    }
  }

  Future<void> stopScan() async {
    await _bluetoothService.stopScan();
    _isScanning = false;
    notifyListeners();
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    final result = await _bluetoothService.connectToDevice(device);
    notifyListeners();
    return result;
  }

  Future<void> disconnectDevice() async {
    await _bluetoothService.disconnectDevice();
    notifyListeners();
  }

  Future<void> openSystemBluetoothSettings() async {
    try {
      await BluetoothUtils.openSystemBluetoothSettings();
    } catch (e) {
      debugPrint('Error opening system Bluetooth settings: $e');
    }
  }

  /// Check for already connected/bonded devices after returning from system settings
  Future<void> refreshDevices() async {
    try {
      final bondedDevices = await BluetoothUtils.getBondedDevices();
      debugPrint('Found ${bondedDevices.length} bonded devices after refresh');
      // The BluetoothService will handle updating the connected device if needed
    } catch (e) {
      debugPrint('Error refreshing devices: $e');
    }
  }

  @override
  void dispose() {
    _bluetoothService.dispose();
    super.dispose();
  }

  // Getters
  bool get isBluetoothOn => _isBluetoothOn;
  bool get isScanning => _isScanning;
  List<BluetoothDevice> get discoveredDevices => _discoveredDevices;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isInitialized => _isInitialized;
  String? get connectionMessage => _connectionMessage;
}
