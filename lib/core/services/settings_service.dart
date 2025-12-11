import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

class SettingsService {
  static const String _modelKey = 'whisper_model';

  Future<void> setWhisperModel(WhisperModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_modelKey, model.name);
  }

  Future<WhisperModel> getWhisperModel() async {
    final prefs = await SharedPreferences.getInstance();
    final modelName = prefs.getString(_modelKey);
    if (modelName == null) {
      return WhisperModel.tiny; // Default to tiny
    }
    return WhisperModel.values.firstWhere(
      (e) => e.name == modelName,
      orElse: () => WhisperModel.tiny,
    );
  }
}
