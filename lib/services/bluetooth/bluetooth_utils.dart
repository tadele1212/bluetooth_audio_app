import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';

/// Utility class for Bluetooth testing and diagnostics
class BluetoothUtils {
  /// Get a list of all paired/bonded devices for debugging
  static Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final devices = await FlutterBluePlus.bondedDevices;
      debugPrint('Found ${devices.length} bonded devices:');
      for (var device in devices) {
        debugPrint(' - ${device.platformName} (${device.remoteId})');
      }
      return devices;
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  /// Check if Bluetooth is available and on
  static Future<bool> isBluetoothReady() async {
    try {
      // Check if Bluetooth is available
      final isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        debugPrint('Bluetooth is not available on this device');
        return false;
      }

      // Check if Bluetooth is turned on
      final adapterState = await FlutterBluePlus.adapterState.first;
      final isOn = adapterState == BluetoothAdapterState.on;
      debugPrint('Bluetooth adapter state: $adapterState (isOn: $isOn)');

      return isOn;
    } catch (e) {
      debugPrint('Error checking Bluetooth status: $e');
      return false;
    }
  }

  /// Log comprehensive device information for debugging
  static void logDeviceInfo(BluetoothDevice device) {
    debugPrint('------- DEVICE INFO -------');
    debugPrint('Name: ${device.platformName}');
    debugPrint('ID: ${device.remoteId}');

    final isAudioDevice = isLikelyAudioDevice(device);
    debugPrint('Likely audio device? $isAudioDevice');
    debugPrint('--------------------------');
  }

  /// Determine if a device is likely an audio device based on its name and characteristics
  static bool isLikelyAudioDevice(BluetoothDevice device) {
    final name = device.platformName.toLowerCase();

    // Common audio device keywords
    final audioKeywords = [
      'headphone',
      'earphone',
      'headset',
      'speaker',
      'audio',
      'sound',
      'ear',
      'pod',
      'bud',
      'airpod',
      'earpod',
      'beats',
      'bose',
      'sony',
      'jabra',
      'jbl',
      'samsung',
      'galaxy',
    ];

    // Check if name contains any audio-related keywords
    for (final keyword in audioKeywords) {
      if (name.contains(keyword)) {
        debugPrint('Device identified as audio device: contains "$keyword"');
        return true;
      }
    }

    // Check for specific device patterns for popular headphones
    if (name.contains('wf-') || // Sony earbuds pattern
        name.contains('wh-') || // Sony headphones pattern
        name.startsWith('wd-') || // Some wireless audio devices
        name.contains('airpods') ||
        name.contains('a2dp')) {
      debugPrint('Device identified as audio device: matches pattern');
      return true;
    }

    return false;
  }

  /// Open the system's Bluetooth settings
  static Future<void> openSystemBluetoothSettings() async {
    try {
      const platform = MethodChannel(
        'com.example.bluetooth_audio_app/settings',
      );
      await platform.invokeMethod('openBluetoothSettings');
      debugPrint('Opened system Bluetooth settings');
    } catch (e) {
      debugPrint('Error opening system Bluetooth settings: $e');
      // Fallback to showing instructions if the method channel fails
      debugPrint('User should manually open Settings > Bluetooth');
    }
  }

  /// Get more useful error information for Bluetooth operations
  static String getReadableError(dynamic error) {
    final message = error.toString();

    if (message.contains('connect')) {
      return 'Connection failed. Make sure your device is in pairing mode and try again.';
    } else if (message.contains('permission')) {
      return 'Missing Bluetooth permission. Please check app settings.';
    } else if (message.contains('timeout')) {
      return 'Connection timed out. The device might be out of range.';
    } else {
      return 'Bluetooth error: $message';
    }
  }
}
