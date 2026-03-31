import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _initialized = false;

  Future<bool> init() async {
    if (_initialized) return true;

    _initialized = await _speechToText.initialize(
      onStatus: (status) {},
      onError: (errorNotification) {},
    );

    return _initialized;
  }

  Future<String> listenOnce({
    Duration listenFor = const Duration(seconds: 12),
    Duration pauseFor = const Duration(seconds: 6),
  }) async {
    final available = await init();
    if (!available) return '';

    await stop();
    await Future.delayed(const Duration(milliseconds: 700));

    final completer = Completer<String>();
    String finalWords = '';

    await _speechToText.listen(
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: false,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
      onResult: (result) {
        finalWords = result.recognizedWords.trim();

        if (result.finalResult && !completer.isCompleted) {
          completer.complete(finalWords);
        }
      },
    );

    Future.delayed(listenFor + const Duration(seconds: 1), () async {
      if (!completer.isCompleted) {
        await stop();
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