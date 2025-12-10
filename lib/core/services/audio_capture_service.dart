import 'package:record/record.dart';

abstract class AudioCaptureService {
  Future<void> start({required String path});
  Future<Stream<List<int>>> startStream();
  Future<String?> stop();
  Future<bool> hasPermission();
}

class DefaultAudioCaptureService implements AudioCaptureService {
  final AudioRecorder _recorder;

  DefaultAudioCaptureService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  @override
  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  @override
  Future<void> start({required String path}) async {
    await _recorder.start(const RecordConfig(), path: path);
  }

  @override
  Future<Stream<List<int>>> startStream() async {
    if (!await hasPermission()) {
      throw Exception('Microphone permission not granted');
    }
    return await _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ),
    );
  }

  @override
  Future<String?> stop() async {
    return await _recorder.stop();
  }
}
