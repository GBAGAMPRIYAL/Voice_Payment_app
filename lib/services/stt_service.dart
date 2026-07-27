import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';

class SttService {
  SttService._();
  static final SttService instance = SttService._();

  final SpeechToText _speechToText = SpeechToText();
  bool _initialized = false;
  bool _cancelled = false;

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
    ListenMode listenMode = ListenMode.dictation,
  }) async {
    _cancelled = false;
    final available = await init();
    if (!available || _cancelled) return '';

    await stop();
    _cancelled = false; // reset again after stop()
    await Future.delayed(const Duration(milliseconds: 700));
    if (_cancelled) return '';

    final completer = Completer<String>();
    String finalWords = '';

    await _speechToText.listen(
      listenFor: listenFor,
      pauseFor: pauseFor,
      partialResults: false,
      cancelOnError: true,
      listenMode: listenMode,
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
    if (_cancelled) return '';
    await stop();
    return result.trim();
  }

  Future<void> stop() async {
    _cancelled = true;
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
    // Allow next listenOnce to start fresh
    await Future.delayed(const Duration(milliseconds: 100));
    _cancelled = false;
  }
}