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
    required Future<bool> Function() onVoiceAuth,
    required Future<bool> Function(String pin) onPinVerify,
    required Future<void> Function() onConfirmedSubmit,
    required Future<void> Function() onConfirmChecked,
    required Future<void> Function() onReset,
    required Future<void> Function() onExit,
    required Future<void> Function() onClose,
    required Future<void> Function() onVerificationFailed,
  }) async {
    final receiverName = await _askReceiver();
    if (receiverName == null) return;
    await onReceiverCaptured(receiverName);

    final amount = await _askAmount();
    if (amount == null) return;
    await onAmountCaptured(amount);

    // Step 1: Voice auth with fixed phrase, one retry
    await ttsService.speak(
      'Voice authorization required. Please say: authorize transaction.',
    );
    bool voiceVerified = await onVoiceAuth();

    if (!voiceVerified) {
      await ttsService.speak(
        'Voice verification failed. Please try once more. Say: authorize transaction.',
      );
      voiceVerified = await onVoiceAuth();
    }

    if (!voiceVerified) {
      await ttsService.speak(
        'Voice verification failed twice. Returning to home page.',
      );
      await onVerificationFailed();
      return;
    }

    // Step 2: PIN verify, one retry
    final pin1 = await _askPin();
    if (pin1 == null) return;

    bool pinVerified = await onPinVerify(pin1);

    if (!pinVerified) {
      await ttsService.speak(
        'PIN verification failed. Please say your pin once more.',
      );
      final pin2 = await _askPin();
      if (pin2 == null) return;
      pinVerified = await onPinVerify(pin2);
    }

    if (!pinVerified) {
      await ttsService.speak(
        'PIN verification failed twice. Returning to home page.',
      );
      await onVerificationFailed();
      return;
    }

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
      if (receiverName.isNotEmpty) return receiverName;

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
      if (amount.isNotEmpty) return amount;

      await ttsService.speak('I did not get a valid amount. Let me ask again.');
    }
  }

  Future<String?> _askPin() async {
    while (true) {
      await ttsService.speak('Please say your four digit pin number.');
      final pinText = await sttService.listenOnce();
      final command = commandService.parse(pinText);

      if (command == VoiceCommandType.exit) return null;
      if (command == VoiceCommandType.close) return null;

      final pin = SpeechParser.normalizePin(pinText);
      if (pin.length == 4) return pin;

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
