import 'package:flutter/material.dart';
import '../controllers/voice_input_controller.dart';

class TranscriptionOverlay extends StatelessWidget {
  final VoiceInputController controller;

  const TranscriptionOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: controller.textStream,
      builder: (context, snapshot) {
        final text = snapshot.data ?? '';

        if (text.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 800),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
