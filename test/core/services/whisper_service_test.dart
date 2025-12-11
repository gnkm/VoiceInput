import 'dart:convert';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/core/services/whisper_service.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';


class MockWhisper extends Mock implements Whisper {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late MockWhisper mockWhisper;
  late MockHttpClient mockHttpClient;
  late DefaultWhisperService whisperService;
  late FileSystem fs;

  setUpAll(() {
    registerFallbackValue(TranscribeRequest(audio: 'dummy'));
    registerFallbackValue(http.Request('GET', Uri.parse('http://dummy')));
  });

  setUp(() {
    fs = MemoryFileSystem();
    mockWhisper = MockWhisper();
    mockHttpClient = MockHttpClient();

    when(
      () => mockWhisper.transcribe(
        transcribeRequest: any(named: 'transcribeRequest'),
      ),
    ).thenAnswer(
      (_) async => WhisperTranscribeResponse(
        type: 'success',
        text: 'Transcribed Text',
        segments: [],
      ),
    );

    // Mock successful download
    when(() => mockHttpClient.send(any())).thenAnswer((invocation) async {
      return http.StreamedResponse(
        Stream.value(utf8.encode('dummy model data')),
        200,
        contentLength: 16, // dummy length
      );
    });

    whisperService = DefaultWhisperService(
      libraryDirectoryProvider: () async => fs.directory('/lib'),
      isMacOSChecker: () => true,
      factory: ({required WhisperModel model}) {
        return mockWhisper;
      },
      fileSystem: fs,
      httpClient: mockHttpClient,
    );
  });

  test('transcribe should throw if not initialized', () async {
    // Re-create service to ensure it's fresh (not initialized)
    expect(() => whisperService.transcribe('audio.wav'), throwsException);
  });

  test('transcribe should use whisper instance after init', () async {
    // We need to make sure the file exists or mocking download works so init passes
    // Create dummy file so no download needed
    final libDir = fs.directory('/lib');
    await libDir.create(recursive: true);
    final file = libDir.childFile('ggml-base.bin');
    // make it large enough to skip corruption check
    await file.writeAsBytes(List.filled(130 * 1024 * 1024 + 1, 0));

    await whisperService.init(model: WhisperModel.base);
    final result = await whisperService.transcribe('audio.wav');
    expect(result, 'Transcribed Text');
    verify(
      () => mockWhisper.transcribe(
        transcribeRequest: any(named: 'transcribeRequest'),
      ),
    ).called(1);
  });

  test('init should download model if missing', () async {
    final libDir = fs.directory('/lib');
    await libDir.create(recursive: true);

    // File missing initially

    await whisperService.init(model: WhisperModel.tiny);

    // Should have checked existence
    final file = libDir.childFile('ggml-tiny.bin');
    expect(await file.exists(), isTrue);

    // verify download was triggered
    verify(() => mockHttpClient.send(any())).called(1);
  });

  test('init should delete corrupted model file and re-download', () async {
    // Setup corrupted file (size < min size)
    final libDir = fs.directory('/lib');
    await libDir.create(recursive: true);

    final modelFile = libDir.childFile('ggml-medium.bin');
    await modelFile.writeAsBytes(List.filled(100, 0));

    expect(await modelFile.exists(), isTrue);

    await whisperService.init(model: WhisperModel.medium);

    // File should be deleted and re-downloaded (which creates it again from mock stream)
    expect(await modelFile.exists(), isTrue);
    // verify download was triggered
    verify(() => mockHttpClient.send(any())).called(1);

    // Verify file content is what mock downloaded (dummy model data)
    // Note: mock writes 'dummy model data' which is 16 bytes.
    // Ideally we should check if logic handles the newly downloaded small file?
    // Current logic downloads and then calls factory. It does NOT check size AGAIN after download.
    // This is fine for now, assuming download source is correct.
    expect(await modelFile.length(), 16);
  });
}
