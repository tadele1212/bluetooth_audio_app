import 'package:flutter/foundation.dart';
import '../../services/audio/audio_service.dart';

class AudioProvider with ChangeNotifier {
  final AudioService _audioService = AudioService();
  bool _isInitialized = false;
  String? _errorMessage;

  // Audio state
  bool _isRecording = false;
  double _volume = 1.0;
  double _audioLevel = 0.0;

  AudioProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _audioService.initialize();
      _isInitialized = true;
      _errorMessage = null;

      // Listen to audio level changes
      _audioService.audioLevelStream.listen((level) {
        _audioLevel = level;
        notifyListeners();
      });

      // Listen to recording state changes
      _audioService.recordingStateStream.listen((isRecording) {
        _isRecording = isRecording;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = 'Failed to initialize audio: $e';
      debugPrint('Error initializing audio service: $e');
      notifyListeners();
    }
  }

  Future<void> toggleRecording() async {
    try {
      _errorMessage = null;

      if (!_isInitialized) {
        await _initialize();
      }

      if (_isRecording) {
        await _audioService.stopRecording();
      } else {
        await _audioService.startRecording();
      }

      notifyListeners();
    } catch (e) {
      _errorMessage = 'Recording error: $e';
      debugPrint('Error toggling recording: $e');
      notifyListeners();
    }
  }

  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
  }

  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    _audioService.setVolume(_volume);
    notifyListeners();
  }

  Future<void> playRecording() async {
    try {
      _errorMessage = null;

      if (!_isInitialized) await _initialize();
      await _audioService.playRecording();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Playback error: $e';
      debugPrint('Error playing recording: $e');
      notifyListeners();
    }
  }

  Future<void> stopPlayback() async {
    try {
      if (!_isInitialized) await _initialize();
      await _audioService.stopPlayback();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error stopping playback: $e';
      debugPrint('Error stopping playback: $e');
      notifyListeners();
    }
  }

  Future<void> resetAudio() async {
    try {
      // Dispose current service
      await _audioService.dispose();

      // Reinitialize
      await _initialize();
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Error resetting audio: $e';
      debugPrint('Error resetting audio: $e');
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  // Getters
  bool get isRecording => _isRecording;
  double get volume => _volume;
  double get audioLevel => _audioLevel;
  bool get isInitialized => _isInitialized;
  String? get errorMessage => _errorMessage;
}
