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
    required Future<void> Function() onReset,
    required Future<void> Function() onExit,
    required Future<void> Function() onClose,
  }) async {
    final receiverName = await _askReceiver();
    if (receiverName == null) return;
    await onReceiverCaptured(receiverName);

    final amount = await _askAmount();
    if (amount == null) return;
    await onAmountCaptured(amount);

    final pin = await _askPin();
    if (pin == null) return;
    await onPinCaptured(pin);

    await _confirmAndSubmit(
      receiverName: receiverName,
      amount: amount,
      onConfirmedSubmit: onConfirmedSubmit,
      onConfirmChecked: onConfirmChecked,
      onReset: onReset,
      onExit: onExit,
      onClose: onClose,
    );
  }

  Future<String?> _askReceiver() async {
    while (true) {
      await ttsService.speak(
        'Transaction page opened. Please say the receiver name. '
        'You can also say exit to go back or close to close the app.',
      );
      final receiverText = await sttService.listenOnce();
      final command = commandService.parse(receiverText);

      if (command == VoiceCommandType.exit) return null;
      if (command == VoiceCommandType.close) return null;

      final receiverName = SpeechParser.cleanName(receiverText);
      if (receiverName.isNotEmpty) {
        return receiverName;
      }

      await ttsService.speak('I did not get the receiver name. Let me ask again.');
    }
  }

  Future<String?> _askAmount() async {
    while (true) {
      await ttsService.speak('Please say the amount.');
      final amountText = await sttService.listenOnce();
      final command = commandService.parse(amountText);

      if (command == VoiceCommandType.exit) return null;
      if (command == VoiceCommandType.close) return null;

      final amount = SpeechParser.normalizeAmount(amountText);
      if (amount.isNotEmpty) {
        return amount;
      }

      await ttsService.speak('I did not get a valid amount. Let me ask again.');
    }
  }

  Future<String?> _askPin() async {
    while (true) {
      await ttsService.speak('Please say your pin number.');
      final pinText = await sttService.listenOnce();
      final command = commandService.parse(pinText);

      if (command == VoiceCommandType.exit) return null;
      if (command == VoiceCommandType.close) return null;

      final pin = SpeechParser.normalizePin(pinText);
      if (pin.length == 4) {
        return pin;
      }

      await ttsService.speak('Pin should contain four digits. Let me ask again.');
    }
  }

  Future<void> _confirmAndSubmit({
    required String receiverName,
    required String amount,
    required Future<void> Function() onConfirmedSubmit,
    required Future<void> Function() onConfirmChecked,
    required Future<void> Function() onReset,
    required Future<void> Function() onExit,
    required Future<void> Function() onClose,
  }) async {
    while (true) {
      await ttsService.speak(
        'Say confirm to send rupees $amount to $receiverName. '
        'You can also say reset to edit the given details, exit to go back, or close to close the app.',
      );

      final confirmText = await sttService.listenOnce();
      final command = commandService.parse(confirmText);

      if (command == VoiceCommandType.confirm ||
          command == VoiceCommandType.submit) {
        await onConfirmChecked();
        await onConfirmedSubmit();
        return;
      }

      if (command == VoiceCommandType.reset) {
        await onReset();
        return;
      }

      if (command == VoiceCommandType.exit) {
        await onExit();
        return;
      }

      if (command == VoiceCommandType.close) {
        await onClose();
        return;
      }

      await ttsService.speak('Confirmation was not received. Let me ask again.');
    }
  }
}