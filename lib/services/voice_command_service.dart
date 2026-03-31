import '../utils/voice_keywords.dart';

enum VoiceCommandType {
  transaction,
  balance,
  contact,
  help,
  confirm,
  ok,
  submit,
  reset,
  exit,
  close,
  record,
  stop,
  play,
  unknown,
}

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
    if (_containsAny(text, VoiceKeywords.ok)) {
      return VoiceCommandType.ok;
    }
    if (_containsAny(text, VoiceKeywords.submit)) {
      return VoiceCommandType.submit;
    }
    if (_containsAny(text, VoiceKeywords.reset)) {
      return VoiceCommandType.reset;
    }
    if (_containsAny(text, VoiceKeywords.exit)) {
      return VoiceCommandType.exit;
    }
    if (_containsAny(text, VoiceKeywords.close)) {
      return VoiceCommandType.close;
    }
    if (_containsAny(text, VoiceKeywords.record)) {
      return VoiceCommandType.record;
    }
    if (_containsAny(text, VoiceKeywords.stop)) {
      return VoiceCommandType.stop;
    }
    if (_containsAny(text, VoiceKeywords.play)) {
      return VoiceCommandType.play;
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