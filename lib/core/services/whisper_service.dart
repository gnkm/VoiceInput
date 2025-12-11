import 'dart:io' show Platform, HttpException;
import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';


abstract class WhisperService {
  Future<void> init({required WhisperModel model});
  Future<void> updateModel(WhisperModel model);
  Future<String> transcribe(String audioPath, {String? prompt});
}

typedef WhisperFactory = Whisper Function({required WhisperModel model});
typedef LibraryDirectoryProvider = Future<Directory> Function();

class DefaultWhisperService implements WhisperService {
  Whisper? _whisper;
  final WhisperFactory _whisperFactory;
  final FileSystem _fs;
  final LibraryDirectoryProvider _getLibraryDirectory;
  final bool Function() _isMacOSChecker;
  final http.Client _httpClient;

  DefaultWhisperService({
    WhisperFactory? factory,
    FileSystem? fileSystem,
    LibraryDirectoryProvider? libraryDirectoryProvider,
    bool Function()? isMacOSChecker,
    http.Client? httpClient,
  }) : _whisperFactory =
           factory ??
           (({required WhisperModel model}) => Whisper(model: model)),
       _fs = fileSystem ?? const LocalFileSystem(),
       _getLibraryDirectory =
           libraryDirectoryProvider ??
           (() async {
             final ioDir = await getLibraryDirectory();
             return const LocalFileSystem().directory(ioDir.path);
           }),
       _isMacOSChecker = isMacOSChecker ?? (() => Platform.isMacOS),
       _httpClient = httpClient ?? http.Client();

  static const Map<String, int> _minModelSizes = {
    'tiny': 70 * 1024 * 1024,
    'tiny_en': 70 * 1024 * 1024,
    'base': 130 * 1024 * 1024,
    'base_en': 130 * 1024 * 1024,
    'small': 400 * 1024 * 1024,
    'small_en': 400 * 1024 * 1024,
    'medium': 1400 * 1024 * 1024,
    'medium_en': 1400 * 1024 * 1024,
    'large': 2800 * 1024 * 1024,
    'large_v1': 2800 * 1024 * 1024,
    'large_v2': 2800 * 1024 * 1024,
    'large_v3': 2800 * 1024 * 1024,
  };

  @override
  Future<void> init({required WhisperModel model}) async {
    await _initializeModel(model);
  }

  @override
  Future<void> updateModel(WhisperModel model) async {
    await _initializeModel(model);
  }

  Future<void> _initializeModel(WhisperModel model) async {
    debugPrint('--- _initializeModel started for ${model.name} ---');
    try {
      final isMac = _isMacOSChecker();
      debugPrint('isMacOS: $isMac');

      if (isMac) {
        final libDir = await _getLibraryDirectory();

        String fileName = 'ggml-${model.name}.bin';
        if (model.name.endsWith('_en')) {
          fileName = 'ggml-${model.name.replaceAll('_en', '.en')}.bin';
        }

        final filePath = '${libDir.path}/$fileName';
        debugPrint('Checking model file at: $filePath');

        final modelFile = _fs.file(filePath);
        bool needsDownload = false;

        if (await modelFile.exists()) {
          final size = await modelFile.length();
          final minSize = _minModelSizes[model.name] ?? 10 * 1024 * 1024;
          debugPrint('File exists. Size: $size. MinSize: $minSize');

          if (size < minSize) {
            debugPrint('Detected corrupted model file. Deleting...');
            await modelFile.delete();
            needsDownload = true;
          } else {
            debugPrint('Model file integrity check passed.');
          }
        } else {
          debugPrint('Model file does not exist.');
          needsDownload = true;
        }

        if (needsDownload) {
          debugPrint('Starting download for ${model.name}...');
          await _downloadModel(model, modelFile);
          debugPrint('Download complete.');
        }
      } else {
        debugPrint('Not on macOS. Skipping manual download/check logic.');
      }
    } catch (e, stack) {
      debugPrint('Error initialized model: $e\n$stack');
      // If manual download fails, we might let the library try fallback?
      // But usually it's fatal. Re-throwing might be better to alert UI.
    }

    debugPrint('Initializing Whisper factory...');
    _whisper = _whisperFactory(model: model);
    debugPrint('Whisper initialized with model: ${model.name}');
  }

  Future<void> _downloadModel(WhisperModel model, File destinationFile) async {
    final modelNameForUrl = model.name.endsWith('_en')
        ? model.name.replaceAll('_en', '.en')
        : model.name;
    final url = Uri.parse(
      'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-$modelNameForUrl.bin',
    );

    debugPrint('Downloading from: $url');

    final request = http.Request('GET', url);
    final response = await _httpClient.send(request);

    if (response.statusCode != 200) {
      throw HttpException('Failed to download model: ${response.statusCode}');
    }

    final sink = destinationFile.openWrite();
    int received = 0;
    final total = response.contentLength ?? 0;

    await response.stream.forEach((chunk) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) {
        // Log progress every 10MB approx
        if (received % (10 * 1024 * 1024) < chunk.length) {
          final pct = (received / total * 100).toStringAsFixed(1);
          debugPrint('Download progress: $pct% ($received / $total)');
        }
      }
    });

    await sink.flush();
    await sink.close();
    debugPrint('Download finished. Total bytes: $received');
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
