import 'dart:async';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class AudioService {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  StreamSubscription? _recorderSubscription;
  String? _recordingPath;
  double _volume = 1.0; // 0.0 to 1.0

  // Streams for audio level and recording state
  final StreamController<double> _audioLevelController =
      StreamController<double>.broadcast();
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  final StreamController<bool> _recordingStateController =
      StreamController<bool>.broadcast();
  Stream<bool> get recordingStateStream => _recordingStateController.stream;

  Future<void> initialize() async {
    try {
      // Request microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        throw Exception('Microphone permission not granted');
      }

      // Close any existing recorder to ensure a clean state
      if (_isRecorderInitialized) {
        await _recorder.closeRecorder();
        _isRecorderInitialized = false;
      }

      // Initialize recorder with explicit settings
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );
      _isRecorderInitialized = true;

      // Initialize player
      if (_isPlayerInitialized) {
        await _player.closePlayer();
        _isPlayerInitialized = false;
      }

      await _player.openPlayer();
      _isPlayerInitialized = true;

      debugPrint('Audio service initialized successfully');
    } catch (e) {
      debugPrint('Error initializing audio service: $e');
      rethrow;
    }
  }

  Future<void> startRecording() async {
    try {
      // Make sure recorder is initialized
      if (!_isRecorderInitialized) {
        debugPrint('Initializing recorder before starting');
        await initialize();
      }

      // Don't try to start if already recording
      if (_isRecording) {
        debugPrint('Already recording, ignoring start request');
        return;
      }

      // Get temporary directory for saving recording
      final tempDir = await getTemporaryDirectory();
      _recordingPath = '${tempDir.path}/temp_recording.aac';

      debugPrint('Starting recording to: $_recordingPath');

      // Make sure any existing subscription is cancelled
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Configure and start recording with explicit parameters
      await _recorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
        bitRate: 16000,
        sampleRate: 16000,
        numChannels: 1,
      );

      _isRecording = true;
      _recordingStateController.add(_isRecording);

      // Listen to recording updates for audio level
      _recorderSubscription = _recorder.onProgress!.listen((e) {
        final dbLevel = e.decibels ?? 0.0;
        // Convert dB level to a normalized value between 0 and 1
        final normalizedLevel =
            (dbLevel + 160) / 160; // Assuming dB range of -160 to 0
        _audioLevelController.add(normalizedLevel.clamp(0.0, 1.0));
      });

      debugPrint('Recording started successfully');
    } catch (e) {
      _isRecording = false;
      _recordingStateController.add(_isRecording);
      debugPrint('Error starting recording: $e');
      // Try to reset the recorder if there was an error
      await _tryResetRecorder();
      rethrow;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) {
      debugPrint('Not recording, ignoring stop request');
      return;
    }

    try {
      debugPrint('Stopping recording');

      // Cancel the subscription first to avoid callbacks after stopping
      await _recorderSubscription?.cancel();
      _recorderSubscription = null;

      // Stop the recorder
      final path = await _recorder.stopRecorder();

      _isRecording = false;
      _recordingStateController.add(_isRecording);

      debugPrint('Recording stopped, saved to: $path');
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      // Even if there's an error, update the state and try to reset
      _isRecording = false;
      _recordingStateController.add(_isRecording);
      await _tryResetRecorder();
    }
  }

  // Helper method to reset the recorder if it gets into a bad state
  Future<void> _tryResetRecorder() async {
    try {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );
      _isRecorderInitialized = true;
      debugPrint('Recorder reset successfully');
    } catch (e) {
      debugPrint('Error resetting recorder: $e');
    }
  }

  Future<void> playRecording() async {
    if (!_isPlayerInitialized || _recordingPath == null) return;

    try {
      debugPrint('Playing recording from: $_recordingPath');
      await _player.startPlayer(
        fromURI: _recordingPath,
        whenFinished: () {
          _isPlaying = false;
          debugPrint('Playback finished');
        },
      );
      _isPlaying = true;
    } catch (e) {
      debugPrint('Error playing recording: $e');
    }
  }

  Future<void> stopPlayback() async {
    if (!_isPlaying) return;

    try {
      await _player.stopPlayer();
      _isPlaying = false;
      debugPrint('Playback stopped');
    } catch (e) {
      debugPrint('Error stopping playback: $e');
    }
  }

  // Set volume for audio processing
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    debugPrint('Volume set to: $_volume');
    // Note: FlutterSound doesn't directly support volume adjustment for recording
    // In a production app, we'd implement more sophisticated audio processing here
  }

  // Clean up resources
  Future<void> dispose() async {
    debugPrint('Disposing audio service');

    await _recorderSubscription?.cancel();
    _audioLevelController.close();
    _recordingStateController.close();

    if (_isRecorderInitialized) {
      await _recorder.closeRecorder();
      _isRecorderInitialized = false;
    }

    if (_isPlayerInitialized) {
      await _player.closePlayer();
      _isPlayerInitialized = false;
    }
  }

  bool get isRecording => _isRecording;
  double get volume => _volume;
}
