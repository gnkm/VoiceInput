import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

abstract class WhisperService {
  Future<void> init({required String modelPath});
  Future<String> transcribe(String audioPath, {String? prompt});
}

typedef WhisperFactory = Whisper Function({required WhisperModel model});

class DefaultWhisperService implements WhisperService {
  Whisper? _whisper;
  final WhisperFactory _whisperFactory;

  DefaultWhisperService({WhisperFactory? factory})
    : _whisperFactory =
          factory ?? (({required WhisperModel model}) => Whisper(model: model));

  @override
  Future<void> init({required String modelPath}) async {
    // Programmatic check for corrupted model file
    try {
      if (Platform.isMacOS) {
        final libDir = await getLibraryDirectory();
        final modelFile = File('${libDir.path}/ggml-tiny.bin');

        if (await modelFile.exists()) {
          final size = await modelFile.length();
          // ggml-tiny.bin should be around 75MB. If < 74MB, it's corrupted.
          if (size < 74 * 1024 * 1024) {
            debugPrint(
              'Detected corrupted model file ($size bytes). Deleting...',
            );
            await modelFile.delete();
            debugPrint('Corrupted model file deleted.');
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking/deleting model file: $e');
    }

    // Use tiny model for faster download and inference
    _whisper = _whisperFactory(model: WhisperModel.tiny);
  }

  @override
  Future<String> transcribe(String audioPath, {String? prompt}) async {
    if (_whisper == null) {
      throw Exception('Whisper not initialized. Call init() first.');
    }
    final response = await _whisper!.transcribe(
      transcribeRequest: TranscribeRequest(
        audio: audioPath,
        language: 'ja', // Force Japanese for now
        // prompt: prompt, // Not supported by library yet
      ),
    );
    debugPrint('Whisper Raw Response: "${response.text}"');
    return response.text;
  }
}
