import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/audio_capture_service.dart';
import '../../../core/services/hotkey_service.dart';
import '../../../core/services/whisper_service.dart';

class VoiceInputController {
  final AudioCaptureService _audioCaptureService;
  final WhisperService _whisperService;
  final HotkeyService _hotkeyService;

  bool _isRecording = false;

  VoiceInputController({
    required AudioCaptureService audioCaptureService,
    required WhisperService whisperService,
    required HotkeyService hotkeyService,
  })  : _audioCaptureService = audioCaptureService,
        _whisperService = whisperService,
        _hotkeyService = hotkeyService;

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
      onKeyDown: () => startRecording(),
      onKeyUp: () => stopRecordingAndTranscribe(),
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
  
  // Note: I will need to update HotkeyService to pass keyUp
  Future<void> startRecording() async {
    if (_isRecording) return;
    _isRecording = true;
    
    try {
      final tempDir = await getTemporaryDirectory();
      final path = p.join(tempDir.path, 'voice_input_recording.m4a');
      
      await _audioCaptureService.start(path: path);
      debugPrint('Started recording to $path');
    } catch (e) {
      debugPrint('Error starting recording: $e');
      _isRecording = false;
    }
  }

  Future<void> stopRecordingAndTranscribe() async {
    if (!_isRecording) return;
    _isRecording = false;

    try {
      final path = await _audioCaptureService.stop();
      if (path != null) {
        debugPrint('Stopped recording, transcribing from $path');
        final text = await _whisperService.transcribe(path);
        _handleTranscription(text);
      }
    } catch (e) {
      debugPrint('Error processing audio: $e');
    }
  }

  void _handleTranscription(String text) {
    debugPrint('Transcribed text: $text');
    // TODO: Copy to clipboard or inject to active window
  }
}
