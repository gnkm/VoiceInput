import 'package:window_manager/window_manager.dart';

abstract class WindowService {
  Future<void> show();
  Future<void> hide();
  Future<void> setIgnoringMouseEvents(bool ignore);
}

class DefaultWindowService implements WindowService {
  @override
  Future<void> hide() async {
    await windowManager.hide();
  }

  @override
  Future<void> show() async {
    await windowManager.show();
    // Ensure we maintain transparency and click-through when showing
    await windowManager.setIgnoreMouseEvents(true);
  }

  @override
  Future<void> setIgnoringMouseEvents(bool ignore) async {
    await windowManager.setIgnoreMouseEvents(ignore);
  }
}
