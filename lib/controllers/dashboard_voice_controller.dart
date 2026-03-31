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
    required Future<void> Function() onClose,
  }) async {
    if (_isDisposed) return;

    await ttsService.speak(
      'Welcome to the home page $userName. '
      'The available options are transaction to send money, '
      'balance to check balance, '
      'contact your contact list, '
      'help, and close to close the app.',
    );

    await _listenForCommand(
      onTransaction: onTransaction,
      onBalance: onBalance,
      onContact: onContact,
      onHelp: onHelp,
      onClose: onClose,
    );
  }

  Future<void> _listenForCommand({
    required Future<void> Function() onTransaction,
    required Future<void> Function() onBalance,
    required Future<void> Function() onContact,
    required Future<void> Function() onHelp,
    required Future<void> Function() onClose,
  }) async {
    if (_isDisposed) return;

    while (!_isDisposed) {
      final commandText = await sttService.listenOnce();
      final command = commandService.parse(commandText);

      switch (command) {
        case VoiceCommandType.transaction:
          await onTransaction();
          return;
        case VoiceCommandType.balance:
          await onBalance();
          break;
        case VoiceCommandType.contact:
          await onContact();
          break;
        case VoiceCommandType.help:
          await onHelp();
          break;
        case VoiceCommandType.close:
          await onClose();
          return;
        default:
          await ttsService.speak(
            'Sorry, I did not understand that command. '
            'Please say transaction, balance, contact, help, or close.',
          );
      }
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}