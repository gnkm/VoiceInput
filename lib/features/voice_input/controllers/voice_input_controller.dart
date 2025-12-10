import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/audio_capture_service.dart';
import '../../../core/services/hotkey_service.dart';
import '../../../core/services/system_tray_service.dart';
import '../../../core/services/whisper_service.dart';
import '../../../core/services/window_service.dart';
import '../../../core/utils/wav_header.dart';

class VoiceInputController {
  final AudioCaptureService _audioCaptureService;
  final WhisperService _whisperService;
  final HotkeyService _hotkeyService;
  final SystemTrayService _systemTrayService;
  final WindowService _windowService;

  // State
  bool _isRecording = false;
  final List<int> _audioBuffer = [];
  Timer? _transcriptionTimer;
  StreamSubscription? _isRecordingStreamSubscription;
  String _currentTranscription = '';

  // Streams
  final _textController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textController.stream;

  final _isRecordingController = StreamController<bool>.broadcast();
  Stream<bool> get isRecordingStream => _isRecordingController.stream;

  VoiceInputController({
    required AudioCaptureService audioCaptureService,
    required WhisperService whisperService,
    required HotkeyService hotkeyService,
    required SystemTrayService systemTrayService,
    required WindowService windowService,
  }) : _audioCaptureService = audioCaptureService,
       _whisperService = whisperService,
       _hotkeyService = hotkeyService,
       _systemTrayService = systemTrayService,
       _windowService = windowService;

  Future<void> init() async {
    await _hotkeyService.init();

    // Register the hotkey: Cmd+Option+Space (MacOS)
    // You might want to make this configurable later.
    final hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.alt],
      scope: HotKeyScope.system, // Make it available system-wide
    );

    await _hotkeyService.register(
      hotKey,
      onKeyDown: () async {
        if (_isRecording) {
          await stopRecordingAndTranscribe();
        } else {
          await startRecording();
        }
      },
      // Remove onKeyUp handler for toggle mode
    );

    // Quick fix: Since our HotkeyService interface currently only exposes onKeyDown,
    // we might need to handle the "hold" logic differently or update the service.
    // For now, let's assume we want "Push to Talk" style.
    // However, existing HotkeyManager package supports keyDown and keyUp.
    // Let's first implementation assume toggle or check if we need to update service.

    // Re-reading implementation plan: "Called on hotkey down... Called on hotkey up".
    // The current HotkeyService signature `register(HotKey hotKey, {VoidCallback? onKeyDown})`
    // is missing onKeyUp. I should probably update the interface and implementation of HotkeyService first
    // to support keyUp, OR implement a toggle.
    // Given the request is likely "Push-to-Talk" or "Hold-to-Record", keyUp is essential.
    // I will proceed with writing this controller assuming I will fix the service in a moment.
  }

  Future<void> startRecording() async {
    if (_isRecording) return;
    _isRecording = true;
    _isRecordingController.add(true);
    _audioBuffer.clear();
    _currentTranscription = '';
    _textController.add(''); // Reset overlay text

    // Feedback
    try {
      await _systemTrayService.setIcon('assets/tray_recording.png');
    } catch (e) {
      debugPrint('Error setting tray icon: $e');
    }

    try {
      await _windowService.show();
    } catch (e) {
      debugPrint('Error showing window: $e');
    }

    try {
      final stream = await _audioCaptureService.startStream();
      debugPrint('Audio stream started');

      _isRecordingStreamSubscription = stream.listen(
        (data) {
          _audioBuffer.addAll(data);
          // Debug sample: log every ~100th chunk or just log size periodically?
          // Let's log if buffer is growing.
        },
        onError: (e) {
          debugPrint('Audio stream error: $e');
          stopRecordingAndTranscribe();
        },
      );

      // Start periodic transcription (Every 1.5 seconds)
      _transcriptionTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        _,
      ) {
        debugPrint('Timer tick. Buffer size: ${_audioBuffer.length}');
        _processCurrentBuffer();
      });

      debugPrint('Started recording stream');
    } catch (e) {
      debugPrint('Error starting recording: $e');
      await stopRecordingAndTranscribe();
    }
  }

  Future<void> stopRecordingAndTranscribe() async {
    if (!_isRecording) return;
    _isRecording = false;
    _isRecordingController.add(false);
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    await _isRecordingStreamSubscription?.cancel();
    _isRecordingStreamSubscription = null;

    try {
      await _audioCaptureService.stop();
      // Final transcription
      await _processCurrentBuffer();

      // Feedback
      await _systemTrayService.setIcon('assets/app_icon.png');

      // Copy to clipboard
      if (_currentTranscription.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: _currentTranscription));
        debugPrint('Copied to clipboard: $_currentTranscription');
        // Clear overlay after a delay? Or keep it?
        // Typically hide it after a few seconds or immediately.
        // Let's keep it for 2 seconds to show confirmation.
        // ignore: unawaited_futures
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isRecording) {
            _textController.add('');
            _windowService.hide();
          }
        });
      } else {
        // If no text, hide immediately or after short delay
        // ignore: unawaited_futures
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_isRecording) _windowService.hide();
        });
      }
    } catch (e) {
      debugPrint('Error stopping/processing: $e');
    }
  }

  Future<void> _processCurrentBuffer() async {
    // Ensure we have at least 1 second of audio (16000 samples * 2 bytes = 32000 bytes)
    // Processing very short audio segments can cause Whisper to crash or output nothing.
    if (_audioBuffer.length < 32000) {
      debugPrint('Buffer too small for transcription: ${_audioBuffer.length}');
      return;
    }

    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'temp_chunk.wav');
      final file = File(tempPath);

      // Create WAV file with header
      final header = WavHeader.createWavHeader(
        dataLength: _audioBuffer.length,
        sampleRate: 16000,
        numChannels: 1,
        bitsPerSample: 16,
      );

      final bytes = <int>[...header, ..._audioBuffer];
      await file.writeAsBytes(bytes, flush: true);

      // Transcribe
      // We are sending the FULL buffer every time, so we don't need 'prompt' for context
      // because the audio *contains* the context.
      // However, as buffer grows, we might want to switch to chunking + prompt.
      // For now, full buffer is safer.
      final text = await _whisperService.transcribe(tempPath);

      if (text != _currentTranscription) {
        _currentTranscription = text;
        _textController.add(text);
        debugPrint('Partial: $text');
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
    }
  }

  void dispose() {
    _textController.close();
    _isRecordingController.close();
    _transcriptionTimer?.cancel();
    _isRecordingStreamSubscription?.cancel();
  }
}
