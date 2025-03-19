import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  bool _isRecorderInitialized = false;
  bool _isStreaming = false;
  StreamSubscription? _recorderSubscription;
  double _volume = 1.0; // 0.0 to 1.0
  AudioSession? _audioSession;
  String? _tempFilePath;
  bool _useRecorderForVisualization = true;

  // Performance tracking
  final Stopwatch _latencyStopwatch = Stopwatch();
  int _bufferUnderruns = 0;
  int _bufferOverruns = 0;
  DateTime? _lastAudioProcessTime;

  // Method channel for native audio control
  static const MethodChannel _audioChannel = MethodChannel(
    'com.example.bluetooth_audio_app/audio',
  );

  // Streams for audio level and streaming state
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  final StreamController<bool> _streamingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get streamingStateStream => _streamingStateController.stream;

  Future<void> initialize() async {
    try {
      debugPrint('Initializing audio service');

      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // Create temp directory for audio files (required even if we don't save)
      final tempDir = await getTemporaryDirectory();
      _tempFilePath = '${tempDir.path}/hearing_aid_temp.pcm';
      debugPrint('Temp audio file path: $_tempFilePath');

      // Initialize audio session for better control over audio routing
      _audioSession = await AudioSession.instance;
      await _configureAudioSession();

      // Close any existing recorder to ensure a clean state
      if (_isRecorderInitialized) {
        await _recorder.closeRecorder();
        _isRecorderInitialized = false;
      }

      if (_useRecorderForVisualization) {
        // Initialize recorder for visualization only
        await _recorder.openRecorder();
        await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 50), // Faster updates for lower latency
        );
        _isRecorderInitialized = true;
        debugPrint('Recorder initialized for visualization');
      }

      // Check connected audio devices
      _logConnectedAudioDevices();

      debugPrint('Audio service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
      rethrow;
    }
  }

  // Log connected audio devices (useful for debugging)
  Future<void> _logConnectedAudioDevices() async {
    try {
      final List<dynamic>? devices = await _audioChannel.invokeMethod(
        'getConnectedDevices',
      );
      if (devices != null && devices.isNotEmpty) {
        debugPrint('Connected Audio Devices:');
        for (var device in devices) {
          debugPrint('  - $device');
        }
      } else {
        debugPrint('No audio devices found or not supported on this device');
      }
    } catch (e) {
      debugPrint('Error checking audio devices: $e');
    }
  }

  // Enable Bluetooth SCO (used for headset audio/mic)
  Future<bool> _enableBluetoothSco(bool enable) async {
    try {
      final result = await _audioChannel.invokeMethod<bool>(
        'enableBluetoothSco',
        {'enable': enable},
      );
      debugPrint('Bluetooth SCO ${enable ? 'enabled' : 'disabled'}: $result');
      return result ?? false;
    } catch (e) {
      debugPrint('Error toggling Bluetooth SCO: $e');
      return false;
    }
  }

  // Configure audio session for optimal hearing aid behavior
  Future<void> _configureAudioSession() async {
    if (_audioSession == null) {
      _audioSession = await AudioSession.instance;
    }

    // Configure for ultra-low latency
    final configuration = AudioSessionConfiguration(
      // iOS configuration
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth |
          AVAudioSessionCategoryOptions.defaultToSpeaker |
          AVAudioSessionCategoryOptions.mixWithOthers,
      avAudioSessionMode: AVAudioSessionMode.voiceChat,

      // Android configuration
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        usage: AndroidAudioUsage.voiceCommunication,
        // Remove unsupported flags but keep low latency settings
      ),
      androidAudioFocusGainType:
          AndroidAudioFocusGainType.gainTransientExclusive,
      androidWillPauseWhenDucked: true,
    );

    try {
      await _audioSession!.configure(configuration);

      // Set optimal buffer configuration
      try {
        final Map<dynamic, dynamic>? bufferConfig = await _audioChannel
            .invokeMethod('getOptimalBufferConfig');
        if (bufferConfig != null) {
          debugPrint('🎯 Optimal buffer config: $bufferConfig');

          // Apply the optimal buffer configuration
          await _audioChannel.invokeMethod('setAudioConfig', {
            'sampleRate': 44100,
            'bufferSize':
                bufferConfig['minBuffer'] ??
                512, // Default to 512 if not specified
            'lowLatencyMode': true,
          });
        }
      } catch (e) {
        debugPrint('⚠️ Error setting optimal buffer size: $e');
      }

      debugPrint('✅ Audio session configured for low latency');

      // Listen for route changes
      _audioSession!.devicesChangedEventStream.listen((event) {
        debugPrint('🔄 Audio route changed:');
        debugPrint(
          '   Added devices: ${event.devicesAdded.map((d) => d.name).join(', ')}',
        );
        debugPrint(
          '   Removed devices: ${event.devicesRemoved.map((d) => d.name).join(', ')}',
        );
      });

      // Listen for interruptions
      _audioSession!.interruptionEventStream.listen((event) {
        debugPrint(
          '⚡ Audio interruption: ${event.begin ? 'began' : 'ended'} (type: ${event.type})',
        );
        if (event.begin) {
          // Interruption began
          if (_isStreaming) {
            stopAudioStreaming();
          }
        }
      });
    } catch (e) {
      debugPrint('❌ Failed to configure audio session: $e');
      rethrow;
    }
  }

  Future<void> _updateAudioRouting() async {
    try {
      final devices = await _audioChannel.invokeMethod('getConnectedDevices');
      debugPrint('🎧 Connected audio devices: $devices');

      // Check for low-latency capable devices
      final hasLowLatencyDevice =
          await _audioChannel.invokeMethod<bool>('hasLowLatencyDevice') ??
          false;

      if (hasLowLatencyDevice) {
        debugPrint('✨ Low-latency audio device detected');
        await _audioChannel.invokeMethod('enableLowLatencyMode', {
          'enable': true,
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error updating audio routing: $e');
    }
  }

  // Start streaming audio (acts as a hearing aid)
  Future<void> startAudioStreaming() async {
    try {
      if (!_isRecorderInitialized && _useRecorderForVisualization) {
        await initialize();
      }

      if (_isStreaming) return;

      // Start performance monitoring
      _latencyStopwatch.start();
      _lastAudioProcessTime = DateTime.now();

      // Ensure audio session is active
      if (_audioSession != null) {
        await _audioSession!.setActive(true);
      }

      // Configure and start native audio loopback
      final success =
          await _audioChannel.invokeMethod<bool>('startAudioLoopback', {
            'gain': _volume,
            'lowLatencyMode': true,
            'bufferSize': 512, // Minimum buffer size for low latency
            'sampleRate': 44100,
          }) ??
          false;

      if (!success) throw Exception('Failed to start native audio loopback');

      if (_useRecorderForVisualization) {
        // Set minimum possible subscription duration for visualization
        await _recorder.setSubscriptionDuration(
          const Duration(milliseconds: 10),
        );

        await _recorder.startRecorder(
          toFile: _tempFilePath,
          codec: Codec.pcm16,
          sampleRate: 44100,
          numChannels: 1,
        );

        _recorderSubscription = _recorder.onProgress!.listen((event) {
          final dbLevel = event.decibels ?? 0.0;
          final normalizedLevel = (dbLevel + 160) / 160;

          // Monitor performance
          if (_latencyStopwatch.elapsedMilliseconds >= 1000) {
            _logPerformanceMetrics();
          }

          // Track buffer issues
          final duration = event.duration?.inMilliseconds ?? 0;
          if (duration > 15) {
            // Reduced threshold for stricter monitoring
            _bufferOverruns++;
          } else if (duration < 5) {
            _bufferUnderruns++;
          }

          _audioLevelController.add(
            (normalizedLevel * _volume).clamp(0.0, 1.0),
          );
        });
      }

      _isStreaming = true;
      _streamingStateController.add(true);

      debugPrint('''
🚀 Low-latency audio streaming started
📊 Configuration:
   • Buffer Size: 512 samples
   • Sample Rate: 44.1 kHz
   • Target Latency: <20ms
   • Visualization Update: 10ms
''');
    } catch (e) {
      debugPrint('❌ Error starting audio streaming: $e');
      _isStreaming = false;
      _streamingStateController.add(false);
      rethrow;
    }
  }

  Future<void> stopAudioStreaming() async {
    if (!_isStreaming) {
      debugPrint('Not streaming, ignoring stop request');
      return;
    }

    try {
      debugPrint('Stopping audio streaming');

      // Update state first to prevent restart loops
      _isStreaming = false;
      _streamingStateController.add(_isStreaming);

      // Stop native audio loopback
      try {
        await _audioChannel.invokeMethod('stopAudioLoopback');
        debugPrint('Native audio loopback stopped');
      } catch (e) {
        debugPrint('Error stopping native audio loopback: $e');
        // Continue with cleanup
      }

      // Cancel subscriptions
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Stop recorder for visualization if it was started
      if (_useRecorderForVisualization && _isRecorderInitialized) {
        try {
          await _recorder.stopRecorder();
          debugPrint('Recorder stopped');
        } catch (e) {
          debugPrint('Error stopping recorder: $e');
          // Not critical, continue
        }
      }

      // Disable Bluetooth SCO
      await _enableBluetoothSco(false);

      // Deactivate audio session
      if (_audioSession != null) {
        await _audioSession!.setActive(false);
      }

      debugPrint('Audio streaming stopped');
    } catch (e) {
      debugPrint('Error stopping audio streaming: $e');
      // Already updated state, just try to reset the system
      await _tryResetAudioSystem();
    }
  }

  // Helper method to reset the audio system if it gets into a bad state
  Future<void> _tryResetAudioSystem() async {
    try {
      debugPrint('Attempting to reset audio system');

      // Stop native audio loopback
      try {
        await _audioChannel.invokeMethod('stopAudioLoopback');
      } catch (e) {
        debugPrint('Error stopping audio loopback during reset: $e');
        // Continue with reset
      }

      // Disable Bluetooth SCO
      await _enableBluetoothSco(false);

      // Cancel subscriptions
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Reset recorder if we're using it
      if (_useRecorderForVisualization) {
        if (_isRecorderInitialized) {
          try {
            await _recorder.closeRecorder();
          } catch (e) {
            debugPrint('Error closing recorder: $e');
          }
          _isRecorderInitialized = false;
        }

        // Reinitialize recorder
        try {
          await _recorder.openRecorder();
          await _recorder.setSubscriptionDuration(
            const Duration(milliseconds: 50), // Lower latency
          );
          _isRecorderInitialized = true;
        } catch (e) {
          debugPrint('Error reopening recorder: $e');
          _useRecorderForVisualization = false;
        }
      }

      // Reconfigure audio session
      await _configureAudioSession();

      debugPrint('Audio system reset successfully');
    } catch (e) {
      debugPrint('Error resetting audio system: $e');
    }
  }

  // Set volume for audio processing - this is the key function for hearing aid
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    debugPrint('Volume set to: $_volume');

    // Update gain in native audio loopback if streaming
    if (_isStreaming) {
      try {
        _audioChannel.invokeMethod('setAudioGain', {'gain': _volume});
        debugPrint('Applied volume to native audio loopback: $_volume');
      } catch (e) {
        debugPrint('Error setting volume: $e');
      }
    }

    // Also update visualization level if not using recorder
    if (!_useRecorderForVisualization) {
      _audioLevelController.add(_volume * 0.5);
    }
  }

  // Clean up resources
  Future<void> dispose() async {
    debugPrint('Disposing audio service');

    // Make sure to stop streaming
    if (_isStreaming) {
      await stopAudioStreaming();
    }

    // Clean up all resources
    await _recorderSubscription?.cancel();
    _audioLevelController.close();
    _streamingStateController.close();

    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
    }

    // Release audio session
    if (_audioSession != null) {
      await _audioSession!.setActive(false);
    }
  }

  bool get isStreaming => _isStreaming;
  double get volume => _volume;

  void _logPerformanceMetrics() {
    final now = DateTime.now();
    final processingLatency = _latencyStopwatch.elapsedMilliseconds;

    debugPrint('\n📊 AUDIO PERFORMANCE METRICS 📊');
    debugPrint('⏱️ Processing Latency: ${processingLatency}ms');
    debugPrint('📈 Buffer Underruns: $_bufferUnderruns');
    debugPrint('📉 Buffer Overruns: $_bufferOverruns');

    if (_lastAudioProcessTime != null) {
      final timeSinceLastProcess =
          now.difference(_lastAudioProcessTime!).inMilliseconds;
      debugPrint('⌛ Time between processes: ${timeSinceLastProcess}ms');
    }

    _lastAudioProcessTime = now;
    _latencyStopwatch.reset();
  }
}
