class SpeechParser {
  static String cleanName(String input) {
    final text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return '';

    return text
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String normalizePin(String input) {
    final lower = input.toLowerCase().trim();
    if (lower.isEmpty) return '';

    final digitMap = {
      'zero': '0',
      'oh': '0',
      'one': '1',
      'two': '2',
      'to': '2',
      'too': '2',
      'three': '3',
      'four': '4',
      'for': '4',
      'five': '5',
      'six': '6',
      'seven': '7',
      'eight': '8',
      'ate': '8',
      'nine': '9',
    };

    final buffer = StringBuffer();
    for (final token in lower.split(RegExp(r'\s+'))) {
      if (RegExp(r'^\d+$').hasMatch(token)) {
        buffer.write(token);
      } else if (digitMap.containsKey(token)) {
        buffer.write(digitMap[token]);
      }
    }
    return buffer.toString();
  }

  static String normalizeAmount(String input) {
    final digits = normalizePin(input);
    if (digits.isNotEmpty) return digits;

    final cleaned = input.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned;
  }
}
