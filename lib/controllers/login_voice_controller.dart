import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../utils/speech_parser.dart';

class LoginVoiceController {
  final TtsService ttsService;
  final SttService sttService;

  LoginVoiceController({
    required this.ttsService,
    required this.sttService,
  });

  Future<void> startLoginFlow({
    required Future<void> Function(String value) onNameCaptured,
    required Future<void> Function(String value) onPinCaptured,
    required Future<void> Function() onAskVoiceSample,
  }) async {
    await ttsService.speak(
      'Welcome to Voice Pay. Please say your name after the beep.',
    );

    final nameText = await sttService.listenOnce();
    final cleanedName = SpeechParser.cleanName(nameText);
    if (cleanedName.isNotEmpty) {
      await onNameCaptured(cleanedName);
      await ttsService.speak('You said $cleanedName');
    }

    await ttsService.speak('Please say your pin number. Speak each digit clearly.');
    final pinText = await sttService.listenOnce();
    final cleanedPin = SpeechParser.normalizePin(pinText);
    if (cleanedPin.isNotEmpty) {
      await onPinCaptured(cleanedPin);
      await ttsService.speak('Pin captured.');
    }

    await onAskVoiceSample();
  }
}
