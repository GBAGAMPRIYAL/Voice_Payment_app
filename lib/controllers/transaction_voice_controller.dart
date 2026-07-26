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
    required Future<void> Function(String) onReceiverCaptured,
    required Future<void> Function(String) onAmountCaptured,
    required Future<void> Function(String) onPinCaptured,
    required Future<void> Function() onConfirmedSubmit,
    required Future<void> Function() onConfirmChecked,
    required Future<void> Function() onReset,
    required Future<void> Function() onExit,
    required Future<void> Function() onClose,
  }) async {
    // Step 1: receiver name via STT
    final receiver = await _askReceiver();
    if (receiver == null) { await onExit(); return; }
    await onReceiverCaptured(receiver);

    // Step 2: amount via STT
    final amount = await _askAmount();
    if (amount == null) { await onExit(); return; }
    await onAmountCaptured(amount);

    // Step 3: PIN via STT only (recorder OFF — no conflict)
    final pin = await _askPin();
    if (pin == null) { await onExit(); return; }
    await onPinCaptured(pin);

    // Step 4: confirm and submit
    await _confirmAndSubmit(
      receiver: receiver,
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
      await ttsService.speak('Please say the receiver name. Say exit to go back.');
      final text = await sttService.listenOnce();
      final cmd = commandService.parse(text);
      if (cmd == VoiceCommandType.exit || cmd == VoiceCommandType.close) return null;
      final name = SpeechParser.cleanName(text);
      if (name.isNotEmpty) return name;
      await ttsService.speak('Did not catch the name. Please try again.');
    }
  }

  Future<String?> _askAmount() async {
    while (true) {
      await ttsService.speak('Please say the amount.');
      final text = await sttService.listenOnce();
      final cmd = commandService.parse(text);
      if (cmd == VoiceCommandType.exit || cmd == VoiceCommandType.close) return null;
      final amount = SpeechParser.normalizeAmount(text);
      if (amount.isNotEmpty) return amount;
      await ttsService.speak('Did not catch the amount. Please try again.');
    }
  }

  // STT only — recorder is completely OFF here
  Future<String?> _askPin() async {
    while (true) {
      await ttsService.speak('Please say your four digit pin.');
      final text = await sttService.listenOnce();
      final cmd = commandService.parse(text);
      if (cmd == VoiceCommandType.exit || cmd == VoiceCommandType.close) return null;
      final pin = SpeechParser.normalizePin(text);
      if (pin.length == 4) return pin;
      await ttsService.speak('Pin must be four digits. Please try again.');
    }
  }

  Future<void> _confirmAndSubmit({
    required String receiver,
    required String amount,
    required Future<void> Function() onConfirmedSubmit,
    required Future<void> Function() onConfirmChecked,
    required Future<void> Function() onReset,
    required Future<void> Function() onExit,
    required Future<void> Function() onClose,
  }) async {
    while (true) {
      await ttsService.speak(
        'Say confirm to send rupees $amount to $receiver. Say reset to edit or exit to go back.',
      );
      final text = await sttService.listenOnce();
      final cmd = commandService.parse(text);

      if (cmd == VoiceCommandType.confirm || cmd == VoiceCommandType.submit) {
        await onConfirmChecked();
        await onConfirmedSubmit();
        return;
      }
      if (cmd == VoiceCommandType.reset) { await onReset(); return; }
      if (cmd == VoiceCommandType.exit) { await onExit(); return; }
      if (cmd == VoiceCommandType.close) { await onClose(); return; }
      await ttsService.speak('Please say confirm, reset, or exit.');
    }
  }
}
