import 'dart:async';
// import 'package:fake_async/fake_async.dart'; // We are using synchronous fakeAsync, checking import
import 'package:fake_async/fake_async.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/core/services/audio_capture_service.dart';
import 'package:voice_input/core/services/hotkey_service.dart';
import 'package:voice_input/core/services/system_tray_service.dart';
import 'package:voice_input/core/services/whisper_service.dart';
import 'package:voice_input/core/services/window_service.dart';
import 'package:voice_input/features/voice_input/controllers/voice_input_controller.dart';

class MockAudioCaptureService extends Mock implements AudioCaptureService {}

class MockWhisperService extends Mock implements WhisperService {}

class MockHotkeyService extends Mock implements HotkeyService {}

class MockSystemTrayService extends Mock implements SystemTrayService {}

class MockWindowService extends Mock implements WindowService {}

void main() {
  late MockAudioCaptureService mockAudioCaptureService;
  late MockWhisperService mockWhisperService;
  late MockHotkeyService mockHotkeyService;
  late MockSystemTrayService mockSystemTrayService;
  late MockWindowService mockWindowService;
  late VoiceInputController controller;
  late FileSystem fs;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(
      HotKey(key: LogicalKeyboardKey.space, modifiers: const []),
    );
  });

  setUp(() {
    mockAudioCaptureService = MockAudioCaptureService();
    mockWhisperService = MockWhisperService();
    mockHotkeyService = MockHotkeyService();
    mockSystemTrayService = MockSystemTrayService();
    mockWindowService = MockWindowService();
    fs = MemoryFileSystem();

    // The controller uses getTemporaryDirectory() which we mock via channel.
    // The controller joins tempDir with filename, then uses _fs.file(path).
    // If tempDir is '.', _fs.file('./temp.wav') works in memory FS.

    controller = VoiceInputController(
      audioCaptureService: mockAudioCaptureService,
      whisperService: mockWhisperService,
      hotkeyService: mockHotkeyService,
      systemTrayService: mockSystemTrayService,
      windowService: mockWindowService,
      fileSystem: fs,
    );

    // ... mocks setup ...
    when(() => mockHotkeyService.init()).thenAnswer((_) async {});
    when(
      () =>
          mockHotkeyService.register(any(), onKeyDown: any(named: 'onKeyDown')),
    ).thenAnswer((_) async {});

    when(() => mockSystemTrayService.setIcon(any())).thenAnswer((_) async {});
    when(() => mockWindowService.show()).thenAnswer((_) async {});
    when(() => mockWindowService.hide()).thenAnswer((_) async {});
    when(() => mockAudioCaptureService.stop()).thenAnswer((_) async => null);
  });

  tearDown(() {
    controller.dispose();
  });

  test(
    'Should skip subsequent transcription if previous is still processing',
    () {
      fakeAsync((async) {
        // Mock path_provider
        const channel = MethodChannel('plugins.flutter.io/path_provider');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
              return '/tmp'; // Use absolute path equivalent in memory fs
            });

        // Ensure temp dir exists in memory FS
        fs.directory('/tmp').createSync(recursive: true);

        // Mock Audio Stream
        final streamController = StreamController<List<int>>();
        when(
          () => mockAudioCaptureService.startStream(),
        ).thenAnswer((_) async => streamController.stream);

        // Mock Whisper to stay busy
        final completer = Completer<String>();
        when(
          () => mockWhisperService.transcribe(
            any(),
            prompt: any(named: 'prompt'),
          ),
        ).thenAnswer((_) => completer.future);

        controller.startRecording();
        async.flushMicrotasks();

        // Feed data
        streamController.add(List.filled(32000 * 2, 0)); // 2 seconds
        async.flushMicrotasks();

        // Advance time to trigger first timer tick (at 2000ms)
        async.elapse(const Duration(milliseconds: 2100));

        // At this point, _processCurrentBuffer should have been called.
        verify(() => mockWhisperService.transcribe(any())).called(1);

        // Advance time again (at 4000ms) - second tick
        async.elapse(const Duration(milliseconds: 2000));

        // Should NOT have called transcribe again because first one is still pending
        verifyNever(() => mockWhisperService.transcribe(any()));

        // Complete the first task
        completer.complete('Done');
        async.flushMicrotasks();

        // Since it's done, subsequent Timer ticks should call transcribe again.
        // But we need to feed more data if buffer was fully consumed?
        // Does _processCurrentBuffer consume/clear buffer?
        // Code:
        // bytes = [...header, ..._audioBuffer];
        // It uses _audioBuffer. NO, it does NOT clear it.
        // It sends the whole buffer again as it grows.
        // If we don't clear it, it keeps growing.
        // And since we didn't add more data, buffer is same size.
        // But it's > 32000. So it will transcribe again.

        async.elapse(const Duration(milliseconds: 2000));
        verify(
          () => mockWhisperService.transcribe(any()),
        ).called(1); // Call count increases by 1
      });
    },
  );
}
