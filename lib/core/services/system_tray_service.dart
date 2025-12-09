import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

abstract class SystemTrayService {
  Future<void> init();
  Future<void> setContextMenu(Menu menu);
}

class DefaultSystemTrayService implements SystemTrayService {
  final SystemTray _systemTray;
  final AppWindow? _appWindow;

  DefaultSystemTrayService({SystemTray? systemTray, AppWindow? appWindow})
      : _systemTray = systemTray ?? SystemTray(),
        _appWindow = appWindow ?? AppWindow();

  @override
  Future<void> init() async {
    await _systemTray.initSystemTray(
      title: 'VoiceInput',
      iconPath: 'assets/app_icon.png', // Default path
    );
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    await _systemTray.setContextMenu(menu);
  }
}
