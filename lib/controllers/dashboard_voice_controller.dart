import '../services/stt_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';

class DashboardVoiceController {
  final TtsService ttsService;
  final SttService sttService;
  final VoiceCommandService commandService;
  bool _isDisposed = false;

  DashboardVoiceController({
    required this.ttsService,
    required this.sttService,
    required this.commandService,
  });

  Future<void> start({
    required String userName,
    required Future<void> Function() onTransaction,
    required Future<void> Function() onBalance,
    required Future<void> Function() onContact,
    required Future<void> Function() onHelp,
    required Future<void> Function() onScan,
    required Future<void> Function() onClose,
  }) async {
    if (_isDisposed) return;

    await ttsService.speak(
      'Welcome to the home page $userName. '
      'Say transaction, balance, contact, scan, help, or close.',
    );

    await _listenForCommand(
      onTransaction: onTransaction,
      onBalance: onBalance,
      onContact: onContact,
      onHelp: onHelp,
      onScan: onScan,
      onClose: onClose,
    );
  }

  Future<void> _listenForCommand({
    required Future<void> Function() onTransaction,
    required Future<void> Function() onBalance,
    required Future<void> Function() onContact,
    required Future<void> Function() onHelp,
    required Future<void> Function() onScan,
    required Future<void> Function() onClose,
  }) async {
    if (_isDisposed) return;

    while (!_isDisposed) {
      final commandText = await sttService.listenOnce();
      if (_isDisposed) return;

      final command = commandService.parse(commandText);

      switch (command) {
        case VoiceCommandType.scan:
          await onScan();
          return;
        case VoiceCommandType.transaction:
          await onTransaction();
          return;
        case VoiceCommandType.balance:
          if (_isDisposed) return;
          await onBalance();
          break;
        case VoiceCommandType.contact:
          if (_isDisposed) return;
          await onContact();
          break;
        case VoiceCommandType.help:
          if (_isDisposed) return;
          await onHelp();
          break;
        case VoiceCommandType.close:
          await onClose();
          return;
        default:
          if (_isDisposed) return;
          await ttsService.speak(
            'Sorry, I did not understand. '
            'Please say transaction, balance, contact, scan, help, or close.',
          );
      }
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}