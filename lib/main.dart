import 'package:flutter/material.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/audio_capture_service.dart';
import 'core/services/hotkey_service.dart';
import 'core/services/system_tray_service.dart';
import 'core/services/whisper_service.dart';
import 'features/voice_input/controllers/voice_input_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize WindowManager
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.hide();
  });

  // Compose services
  final systemTrayService = DefaultSystemTrayService();
  final hotkeyService = SystemHotkeyService();
  final audioCaptureService = DefaultAudioCaptureService();
  final whisperService = DefaultWhisperService();
  
  final controller = VoiceInputController(
    audioCaptureService: audioCaptureService,
    whisperService: whisperService,
    hotkeyService: hotkeyService,
  );

  // Initialize System Tray
  await systemTrayService.init();
  
  final menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show', onClicked: (menuItem) => windowManager.show()),
    MenuItemLabel(label: 'Hide', onClicked: (menuItem) => windowManager.hide()),
    MenuItemLabel(label: 'Exit', onClicked: (menuItem) => windowManager.close()),
  ]);
  
  await systemTrayService.setContextMenu(menu);

  // Initialize Controller (registers hotkeys)
  await controller.init();
  // We need to initialize whisper service too
  await whisperService.init(modelPath: 'base'); // Using 'base' model as default for now

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceInput',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('VoiceInput is running in the background.'),
        ),
      ),
    );
  }
}
