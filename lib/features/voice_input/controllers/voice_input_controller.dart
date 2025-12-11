import 'dart:async';

import 'package:file/file.dart';
import 'package:file/local.dart';

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
  final FileSystem _fs;

  // State
  bool _isRecording = false;
  bool _isProcessing = false;
  final List<int> _audioBuffer = [];
  Timer? _transcriptionTimer;
  StreamSubscription? _isRecordingStreamSubscription;
  String _currentTranscription = '';

  // ... (streams are unchanged) ...

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
    FileSystem? fileSystem,
  }) : _audioCaptureService = audioCaptureService,
       _whisperService = whisperService,
       _hotkeyService = hotkeyService,
       _systemTrayService = systemTrayService,
       _windowService = windowService,
       _fs = fileSystem ?? const LocalFileSystem();

  Future<void> init() async {
    await _hotkeyService.init();

    // Register the hotkey: Cmd+Option+Space (MacOS)
    final hotKey = HotKey(
      key: LogicalKeyboardKey.space,
      modifiers: [HotKeyModifier.meta, HotKeyModifier.alt],
      scope: HotKeyScope.system,
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
    );
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
          // Log data reception occasionally to verify mic input
          // 32000 bytes ~ 1 sec
          if (_audioBuffer.length % 32000 < data.length) {
            debugPrint(
              'Audio buffer growing. Total bytes: ${_audioBuffer.length}',
            );
          }
        },
        onError: (e) {
          debugPrint('Audio stream error: $e');
          stopRecordingAndTranscribe();
        },
      );

      // Start periodic transcription
      // Interval increased to 2.0s to reduce load
      _transcriptionTimer = Timer.periodic(const Duration(milliseconds: 2000), (
        _,
      ) async {
        // Make callback async to handle future
        if (_isProcessing) {
          debugPrint('Skipping transcription: previous task still running');
          return;
        }
        debugPrint('Timer tick. Buffer size: ${_audioBuffer.length}');
        await _processCurrentBuffer();
      });

      debugPrint('Started recording stream');
    } catch (e) {
      debugPrint('Error starting recording: $e');
      await stopRecordingAndTranscribe();
    }
  }

  Future<void> stopRecordingAndTranscribe() async {
    if (!_isRecording) return;
    debugPrint('Stopping recording...');
    _isRecording = false;
    _isRecordingController.add(false);
    _transcriptionTimer?.cancel();
    _transcriptionTimer = null;
    await _isRecordingStreamSubscription?.cancel();
    _isRecordingStreamSubscription = null;

    try {
      await _audioCaptureService.stop();
      debugPrint('Audio capture stopped. Processing final buffer...');
      // Final transcription
      await _processCurrentBuffer();

      // Feedback
      await _systemTrayService.setIcon('assets/app_icon.png');

      // Copy to clipboard
      if (_currentTranscription.isNotEmpty) {
        await Clipboard.setData(ClipboardData(text: _currentTranscription));
        debugPrint('Copied to clipboard: $_currentTranscription');

        // ignore: unawaited_futures
        Future.delayed(const Duration(seconds: 2), () {
          if (!_isRecording) {
            _textController.add('');
            _windowService.hide();
          }
        });
      } else {
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
    // Ensure we have at least 1 second of audio
    if (_audioBuffer.length < 32000) {
      debugPrint('Buffer too small for transcription: ${_audioBuffer.length}');
      return;
    }

    _isProcessing = true;
    try {
      final tempDir = await getTemporaryDirectory();
      final tempPath = p.join(tempDir.path, 'temp_chunk.wav');
      final file = _fs.file(tempPath);

      // Create WAV file with header
      final header = WavHeader.createWavHeader(
        dataLength: _audioBuffer.length,
        sampleRate: 16000,
        numChannels: 1,
        bitsPerSample: 16,
      );

      final bytes = <int>[...header, ..._audioBuffer];
      await file.writeAsBytes(bytes, flush: true);

      debugPrint('Transcribing ${bytes.length} bytes...');
      final text = await _whisperService.transcribe(tempPath);
      debugPrint('Transcription done: "$text"');

      if (text != _currentTranscription) {
        _currentTranscription = text;
        _textController.add(text);
      }
    } catch (e) {
      debugPrint('Transcription error: $e');
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _textController.close();
    _isRecordingController.close();
    _transcriptionTimer?.cancel();
    _isRecordingStreamSubscription?.cancel();
  }
}
