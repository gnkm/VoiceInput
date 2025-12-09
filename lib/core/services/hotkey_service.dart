import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

abstract class HotkeyService {
  Future<void> init();
  Future<void> register(HotKey hotKey, {VoidCallback? onKeyDown, VoidCallback? onKeyUp});
}

class SystemHotkeyService implements HotkeyService {
  final HotKeyManager _manager;

  SystemHotkeyService({HotKeyManager? manager}) : _manager = manager ?? HotKeyManager.instance;

  @override
  Future<void> init() async {
    await _manager.unregisterAll();
  }

  @override
  Future<void> register(HotKey hotKey, {VoidCallback? onKeyDown, VoidCallback? onKeyUp}) async {
    await _manager.register(
      hotKey,
      keyDownHandler: onKeyDown != null ? (_) => onKeyDown() : null,
      keyUpHandler: onKeyUp != null ? (_) => onKeyUp() : null,
    );
  }
}
