import '../utils/voice_keywords.dart';

enum VoiceCommandType { transaction, balance, contact, help, confirm, unknown }

class VoiceCommandService {
  VoiceCommandType parse(String rawText) {
    final text = rawText.toLowerCase().trim();

    if (_containsAny(text, VoiceKeywords.transaction)) {
      return VoiceCommandType.transaction;
    }
    if (_containsAny(text, VoiceKeywords.balance)) {
      return VoiceCommandType.balance;
    }
    if (_containsAny(text, VoiceKeywords.contact)) {
      return VoiceCommandType.contact;
    }
    if (_containsAny(text, VoiceKeywords.help)) {
      return VoiceCommandType.help;
    }
    if (_containsAny(text, VoiceKeywords.confirm)) {
      return VoiceCommandType.confirm;
    }

    return VoiceCommandType.unknown;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }
}
