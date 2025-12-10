import 'package:flutter/foundation.dart';
import 'package:system_tray/system_tray.dart';

abstract class SystemTrayService {
  Future<void> init();
  Future<void> setContextMenu(Menu menu);
  Future<void> setIcon(String iconPath);
}

class DefaultSystemTrayService implements SystemTrayService {
  final SystemTray _systemTray;

  DefaultSystemTrayService({SystemTray? systemTray})
    : _systemTray = systemTray ?? SystemTray();

  @override
  Future<void> init() async {
    await _systemTray.initSystemTray(
      title: 'VoiceInput',
      iconPath: 'assets/app_icon.png',
    );

    // handle system tray event
    _systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("eventName: $eventName");
      if (eventName == kSystemTrayEventClick) {
        _systemTray.popUpContextMenu();
      } else if (eventName == kSystemTrayEventRightClick) {
        _systemTray.popUpContextMenu();
      }
    });
  }

  @override
  Future<void> setContextMenu(Menu menu) async {
    await _systemTray.setContextMenu(menu);
  }

  @override
  Future<void> setIcon(String iconPath) async {
    await _systemTray.setImage(iconPath);
  }
}
