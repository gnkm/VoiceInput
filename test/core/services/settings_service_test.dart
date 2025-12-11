import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:voice_input/core/services/settings_service.dart';
import 'package:whisper_flutter_new/whisper_flutter_new.dart';

void main() {
  late SettingsService settingsService;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settingsService = SettingsService();
  });

  test('getWhisperModel returns tiny by default', () async {
    final model = await settingsService.getWhisperModel();
    expect(model, WhisperModel.tiny);
  });

  test('setWhisperModel saves the model', () async {
    await settingsService.setWhisperModel(WhisperModel.medium);

    // verify direct retrieval
    final model = await settingsService.getWhisperModel();
    expect(model, WhisperModel.medium);

    // verify underlying storage
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('whisper_model'), 'medium');
  });
}
