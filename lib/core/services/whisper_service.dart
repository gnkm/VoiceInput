import 'package:whisper_flutter_new/whisper_flutter_new.dart';

abstract class WhisperService {
  Future<void> init({required String modelPath});
  Future<String> transcribe(String audioPath);
}

typedef WhisperFactory = Whisper Function({required WhisperModel model});

class DefaultWhisperService implements WhisperService {
  Whisper? _whisper;
  final WhisperFactory _whisperFactory;

  DefaultWhisperService({WhisperFactory? factory})
      : _whisperFactory = factory ?? (({required WhisperModel model}) => Whisper(model: model));

  @override
  Future<void> init({required String modelPath}) async {
    // Basic mapping for now, or assume modelPath is ignored if we use a default
    // Ideally we map modelPath to WhisperModel
    // For test, we use base.
    _whisper = _whisperFactory(model: WhisperModel.base);
  }

  @override
  Future<String> transcribe(String audioPath) async {
    if (_whisper == null) {
      throw Exception('Whisper not initialized. Call init() first.');
    }
    final response = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(audio: audioPath),
    );
    return response.text;
  }
}
