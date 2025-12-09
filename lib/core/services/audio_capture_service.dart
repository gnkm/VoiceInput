import 'package:record/record.dart';

abstract class AudioCaptureService {
  Future<void> start({required String path});
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
  Future<String?> stop() async {
    return await _recorder.stop();
  }
}
