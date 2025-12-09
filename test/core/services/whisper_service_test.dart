import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/core/services/whisper_service.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class MockWhisper extends Mock implements Whisper {}

void main() {
  late MockWhisper mockWhisper;
  late DefaultWhisperService whisperService;

  setUpAll(() {
    registerFallbackValue(TranscribeRequest(audio: 'dummy'));
  });

  setUp(() {
    mockWhisper = MockWhisper();
    when(() => mockWhisper.transcribe(transcribeRequest: any(named: 'transcribeRequest')))
        .thenAnswer((_) async => WhisperTranscribeResponse(type: 'success', text: 'Transcribed Text', segments: []));

    whisperService = DefaultWhisperService(factory: ({required WhisperModel model}) {
      return mockWhisper;
    });
  });

  test('transcribe should throw if not initialized', () async {
    // Re-create service to ensure it's fresh (not initialized)
    expect(() => whisperService.transcribe('audio.wav'), throwsException);
  });

  test('transcribe should use whisper instance after init', () async {
    await whisperService.init(modelPath: 'base');
    final result = await whisperService.transcribe('audio.wav');
    expect(result, 'Transcribed Text');
    verify(() => mockWhisper.transcribe(
          transcribeRequest: any(named: 'transcribeRequest'),
        )).called(1);
  });
}
