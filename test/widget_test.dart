// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:voice_input/features/voice_input/controllers/voice_input_controller.dart';
import 'package:voice_input/features/voice_input/views/transcription_overlay.dart';
import 'package:voice_input/main.dart';

class MockVoiceInputController extends Mock implements VoiceInputController {}

void main() {
  testWidgets('App renders transcription overlay', (WidgetTester tester) async {
    final mockController = MockVoiceInputController();
    when(() => mockController.textStream).thenAnswer((_) => Stream.value(''));

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(controller: mockController));

    // Verify that the overlay widget is present (it might be empty but the widget is in the tree)
    expect(find.byType(TranscriptionOverlay), findsOneWidget);
  });
}
