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
  }) async {
    if (_isDisposed) return;

    await ttsService.speak(
      'Welcome $userName. Available options are transaction, balance, contact, and help.',
    );
    await _listenForCommand(
      onTransaction: onTransaction,
      onBalance: onBalance,
      onContact: onContact,
      onHelp: onHelp,
    );
  }

  Future<void> _listenForCommand({
    required Future<void> Function() onTransaction,
    required Future<void> Function() onBalance,
    required Future<void> Function() onContact,
    required Future<void> Function() onHelp,
  }) async {
    if (_isDisposed) return;

    await ttsService.speak('Please say a command now.');
    final commandText = await sttService.listenOnce();
    final command = commandService.parse(commandText);

    switch (command) {
      case VoiceCommandType.transaction:
        await onTransaction();
        break;
      case VoiceCommandType.balance:
        await onBalance();
        if (!_isDisposed) {
          await _listenForCommand(
            onTransaction: onTransaction,
            onBalance: onBalance,
            onContact: onContact,
            onHelp: onHelp,
          );
        }
        break;
      case VoiceCommandType.contact:
        await onContact();
        if (!_isDisposed) {
          await _listenForCommand(
            onTransaction: onTransaction,
            onBalance: onBalance,
            onContact: onContact,
            onHelp: onHelp,
          );
        }
        break;
      case VoiceCommandType.help:
        await onHelp();
        if (!_isDisposed) {
          await _listenForCommand(
            onTransaction: onTransaction,
            onBalance: onBalance,
            onContact: onContact,
            onHelp: onHelp,
          );
        }
        break;
      case VoiceCommandType.confirm:
      case VoiceCommandType.unknown:
        await ttsService.speak('Sorry, I did not understand that command.');
        if (!_isDisposed) {
          await _listenForCommand(
            onTransaction: onTransaction,
            onBalance: onBalance,
            onContact: onContact,
            onHelp: onHelp,
          );
        }
        break;
    }
  }

  void dispose() {
    _isDisposed = true;
  }
}
