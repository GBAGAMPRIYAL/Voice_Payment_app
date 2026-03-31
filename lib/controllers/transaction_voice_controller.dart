import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import '../utils/speech_parser.dart';

class TransactionVoiceController {
  final TtsService ttsService;
  final SttService sttService;
  final VoiceCommandService commandService;

  TransactionVoiceController({
    required this.ttsService,
    required this.sttService,
    required this.commandService,
  });

  Future<void> startTransactionFlow({
    required Future<void> Function(String value) onReceiverCaptured,
    required Future<void> Function(String value) onAmountCaptured,
    required Future<void> Function(String value) onPinCaptured,
    required Future<void> Function() onConfirmedSubmit,
    required Future<void> Function() onConfirmChecked,
  }) async {
    await ttsService.speak('Transaction page opened. Please say the receiver name.');
    final receiverText = await sttService.listenOnce();
    final receiverName = SpeechParser.cleanName(receiverText);
    if (receiverName.isNotEmpty) {
      await onReceiverCaptured(receiverName);
    }

    await ttsService.speak('Please say the amount.');
    final amountText = await sttService.listenOnce();
    final amount = SpeechParser.normalizeAmount(amountText);
    if (amount.isNotEmpty) {
      await onAmountCaptured(amount);
    }

    await ttsService.speak('Please say your pin number.');
    final pinText = await sttService.listenOnce();
    final pin = SpeechParser.normalizePin(pinText);
    if (pin.isNotEmpty) {
      await onPinCaptured(pin);
    }

    await ttsService.speak('Say confirm to proceed with the payment.');
    final confirmText = await sttService.listenOnce();
    final command = commandService.parse(confirmText);

    if (command == VoiceCommandType.confirm) {
      await onConfirmChecked();
      await onConfirmedSubmit();
    } else {
      await ttsService.speak('Transaction confirmation was not received.');
    }
  }
}
