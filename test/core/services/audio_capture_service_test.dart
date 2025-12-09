import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:record/record.dart';
import 'package:voice_input/core/services/audio_capture_service.dart';

class MockAudioRecorder extends Mock implements AudioRecorder {}

void main() {
  late MockAudioRecorder mockRecorder;
  late DefaultAudioCaptureService captureService;

  setUpAll(() {
    registerFallbackValue(const RecordConfig());
  });

  setUp(() {
    mockRecorder = MockAudioRecorder();
    captureService = DefaultAudioCaptureService(recorder: mockRecorder);

    when(() => mockRecorder.hasPermission()).thenAnswer((_) async => true);
    when(() => mockRecorder.start(any(), path: any(named: 'path'))).thenAnswer((_) async {});
    when(() => mockRecorder.stop()).thenAnswer((_) async => 'path/to/file');
  });

  test('hasPermission should check permission', () async {
    final result = await captureService.hasPermission();
    expect(result, true);
    verify(() => mockRecorder.hasPermission()).called(1);
  });

  test('start should start recording using recorder', () async {
    const path = 'test_path.m4a';
    await captureService.start(path: path);
    verify(() => mockRecorder.start(any(), path: path)).called(1);
  });

  test('stop should stop recording and return path', () async {
    final result = await captureService.stop();
    expect(result, 'path/to/file');
    verify(() => mockRecorder.stop()).called(1);
  });
}
