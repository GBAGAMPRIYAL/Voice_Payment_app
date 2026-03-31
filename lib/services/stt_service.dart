import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _initialized = false;

  Future<bool> init() async {
    if (_initialized) return true;
    _initialized = await _speechToText.initialize();
    return _initialized;
  }

  Future<String> listenOnce({
    Duration listenFor = const Duration(seconds: 6),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    final available = await init();
    if (!available) return '';

    final completer = Completer<String>();
    String finalWords = '';

    await _speechToText.listen(
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: true,
      onResult: (result) {
        finalWords = result.recognizedWords.trim();
        if (result.finalResult && !completer.isCompleted) {
          completer.complete(finalWords);
        }
      },
      onSoundLevelChange: (_) {},
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );

    Future.delayed(listenFor + const Duration(seconds: 2), () {
      if (!completer.isCompleted) {
        completer.complete(finalWords);
      }
    });

    final result = await completer.future;
    await stop();
    return result.trim();
  }

  Future<void> stop() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }
}
