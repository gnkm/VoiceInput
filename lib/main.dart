import 'package:flutter/material.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:system_tray/system_tray.dart';
import 'package:window_manager/window_manager.dart';

import 'core/services/audio_capture_service.dart';
import 'core/services/hotkey_service.dart';
import 'core/services/system_tray_service.dart';
import 'core/services/whisper_service.dart';
import 'core/services/window_service.dart';
import 'features/voice_input/controllers/voice_input_controller.dart';
import 'features/voice_input/views/transcription_overlay.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WindowManager
  await windowManager.ensureInitialized();
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600), // Adjusted later to full screen or large area
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
    alwaysOnTop: true,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    try {
      // Instead of maximizing, we position it at the bottom center
      Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
      double windowWidth = 800;
      double windowHeight = 120;

      // Calculate center bottom position
      // Note: detailed positioning might need adjustment for valid screen area (excluding dock),
      // but visible bounds usually accounts for that or generic bounds.
      // simpler to just put it near bottom.

      double xPos = (primaryDisplay.size.width - windowWidth) / 2;
      double yPos =
          primaryDisplay.size.height -
          windowHeight -
          50; // 50px padding from bottom

      await windowManager.setBounds(
        Rect.fromLTWH(xPos, yPos, windowWidth, windowHeight),
      );
    } catch (e) {
      debugPrint('Failed to get display info or set bounds: $e');
      // Fallback position if necessary
      await windowManager.setBounds(const Rect.fromLTWH(100, 100, 800, 120));
    }

    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setIgnoreMouseEvents(true);
    // Start hidden - the controller will show it when recording starts.
    await windowManager.hide();
  });

  // Compose services
  final systemTrayService = DefaultSystemTrayService();
  final hotkeyService = SystemHotkeyService();
  final audioCaptureService = DefaultAudioCaptureService();
  final whisperService = DefaultWhisperService();
  final windowService = DefaultWindowService();

  final controller = VoiceInputController(
    audioCaptureService: audioCaptureService,
    whisperService: whisperService,
    hotkeyService: hotkeyService,
    systemTrayService: systemTrayService,
    windowService: windowService,
  );

  // Initialize System Tray
  await systemTrayService.init();

  final menu = Menu();
  await menu.buildFrom([
    MenuItemLabel(label: 'Show', onClicked: (menuItem) => windowManager.show()),
    MenuItemLabel(label: 'Hide', onClicked: (menuItem) => windowManager.hide()),
    MenuItemLabel(
      label: 'Exit',
      onClicked: (menuItem) => windowManager.close(),
    ),
  ]);

  await systemTrayService.setContextMenu(menu);

  // Initialize Controller (registers hotkeys)
  await controller.init();
  // We need to initialize whisper service too
  await whisperService.init(
    modelPath: 'base',
  ); // Using 'base' model as default for now

  runApp(MyApp(controller: controller));
}

class MyApp extends StatelessWidget {
  final VoiceInputController controller;

  const MyApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceInput',
      color: Colors.transparent,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.transparent,
      ),
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            TranscriptionOverlay(controller: controller),
            // We can add other UI elements here if needed, e.g. a hidden settings button
          ],
        ),
      ),
    );
  }
}
