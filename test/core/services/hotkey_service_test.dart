import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/core/services/hotkey_service.dart';

class MockHotKeyManager extends Mock implements HotKeyManager {}

void main() {
  late MockHotKeyManager mockHotKeyManager;
  late SystemHotkeyService hotkeyService;

  setUpAll(() {
    registerFallbackValue(
      HotKey(key: LogicalKeyboardKey.keyA, modifiers: [HotKeyModifier.meta]),
    );
  });

  setUp(() {
    mockHotKeyManager = MockHotKeyManager();
    hotkeyService = SystemHotkeyService(manager: mockHotKeyManager);

    when(() => mockHotKeyManager.unregisterAll()).thenAnswer((_) async {});
    when(
      () => mockHotKeyManager.register(
        any(),
        keyDownHandler: any(named: 'keyDownHandler'),
        keyUpHandler: any(named: 'keyUpHandler'),
      ),
    ).thenAnswer((_) async {});
  });

  test('init should unregister all hotkeys', () async {
    await hotkeyService.init();
    verify(() => mockHotKeyManager.unregisterAll()).called(1);
  });

  test('register should register hotkey with manager', () async {
    final hotKey = HotKey(
      key: LogicalKeyboardKey.keyA,
      modifiers: [HotKeyModifier.meta],
    );
    await hotkeyService.register(hotKey);
    verify(
      () => mockHotKeyManager.register(
        hotKey,
        keyDownHandler: any(named: 'keyDownHandler'),
        keyUpHandler: any(named: 'keyUpHandler'),
      ),
    ).called(1);
  });
}
