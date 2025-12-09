import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/core/services/audio_capture_service.dart';
import 'package:voice_input/core/services/hotkey_service.dart';
import 'package:voice_input/core/services/whisper_service.dart';
import 'package:voice_input/features/voice_input/controllers/voice_input_controller.dart';

class MockAudioCaptureService extends Mock implements AudioCaptureService {}
class MockWhisperService extends Mock implements WhisperService {}
class MockHotkeyService extends Mock implements HotkeyService {}

void main() {
  late MockAudioCaptureService mockAudioCaptureService;
  late MockWhisperService mockWhisperService;
  late MockHotkeyService mockHotkeyService;
  late VoiceInputController controller;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(HotKey(key: LogicalKeyboardKey.space, modifiers: []));
  });

  setUp(() {
    mockAudioCaptureService = MockAudioCaptureService();
    mockWhisperService = MockWhisperService();
    mockHotkeyService = MockHotkeyService();
    controller = VoiceInputController(
      audioCaptureService: mockAudioCaptureService,
      whisperService: mockWhisperService,
      hotkeyService: mockHotkeyService,
    );

    when(() => mockHotkeyService.init()).thenAnswer((_) async {});
    when(() => mockHotkeyService.register(any(), onKeyDown: any(named: 'onKeyDown'), onKeyUp: any(named: 'onKeyUp')))
        .thenAnswer((_) async {});
    when(() => mockAudioCaptureService.start(path: any(named: 'path'))).thenAnswer((_) async {});
    when(() => mockAudioCaptureService.stop()).thenAnswer((_) async => 'path/to/audio.m4a');
    when(() => mockWhisperService.transcribe(any())).thenAnswer((_) async => 'Transcribed Text');
  });

  test('init should initialize hotkey service and register hotkey', () async {
    await controller.init();
    verify(() => mockHotkeyService.init()).called(1);
    verify(() => mockHotkeyService.register(
      any(),
      onKeyDown: any(named: 'onKeyDown'),
      onKeyUp: any(named: 'onKeyUp'),
    )).called(1);
  });

  test('startRecording should call audio capture start', () async {
    // Trick to get the path_provider to work in tests if needed, 
    // or we can mock dependencies that use path_provider.
    // However, VoiceInputController calls getTemporaryDirectory().
    // We need to mock the channel for path_provider.
    
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });

    await controller.startRecording();
    verify(() => mockAudioCaptureService.start(path: any(named: 'path'))).called(1);
  });

  test('stopRecordingAndTranscribe should stop recording and transcribe', () async {
    // Need to start first to set _isRecording = true
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      return '.';
    });
    
    await controller.startRecording();
    await controller.stopRecordingAndTranscribe();
    
    verify(() => mockAudioCaptureService.stop()).called(1);
    verify(() => mockWhisperService.transcribe(any())).called(1);
  });
}
