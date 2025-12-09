import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:system_tray/system_tray.dart';
import 'package:voice_input/core/services/system_tray_service.dart';

class MockSystemTray extends Mock implements SystemTray {}
class MockAppWindow extends Mock implements AppWindow {}

void main() {
  late MockSystemTray mockSystemTray;
  late MockAppWindow mockAppWindow;
  late DefaultSystemTrayService trayService;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(Menu());
  });

  setUp(() {
    mockSystemTray = MockSystemTray();
    mockAppWindow = MockAppWindow();
    trayService = DefaultSystemTrayService(systemTray: mockSystemTray, appWindow: mockAppWindow);

    when(() => mockSystemTray.initSystemTray(title: any(named: 'title'), iconPath: any(named: 'iconPath')))
        .thenAnswer((_) async => true);
    when(() => mockSystemTray.setContextMenu(any())).thenAnswer((_) async {});
  });

  test('init should initialize system tray', () async {
    await trayService.init();
    verify(() => mockSystemTray.initSystemTray(title: any(named: 'title'), iconPath: any(named: 'iconPath'))).called(1);
  });

  test('setContextMenu should set menu', () async {
    final menu = Menu();
    // await menu.buildFrom([...]); // Skip actual build to avoid channel calls
    await trayService.setContextMenu(menu);
    verify(() => mockSystemTray.setContextMenu(menu)).called(1);
  });
}
