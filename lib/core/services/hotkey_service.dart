import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:flutter/foundation.dart';

abstract class HotkeyService {
  Future<void> init();
  Future<void> register(HotKey hotKey, {VoidCallback? onKeyDown});
}

class SystemHotkeyService implements HotkeyService {
  final HotKeyManager _manager;

  SystemHotkeyService({HotKeyManager? manager}) : _manager = manager ?? HotKeyManager.instance;

  @override
  Future<void> init() async {
    await _manager.unregisterAll();
  }

  @override
  Future<void> register(HotKey hotKey, {VoidCallback? onKeyDown}) async {
    await _manager.register(
      hotKey,
      keyDownHandler: onKeyDown != null ? (_) => onKeyDown() : null,
    );
  }
}
