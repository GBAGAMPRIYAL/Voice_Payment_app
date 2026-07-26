class TapPatternService {
  final List<int> _tapTimestamps = [];

  void recordTap() {
    _tapTimestamps.add(DateTime.now().millisecondsSinceEpoch);
  }

  void reset() => _tapTimestamps.clear();

  int get tapCount => _tapTimestamps.length;

  // Returns intervals between taps in ms (needs at least 2 taps)
  List<int> getIntervals() {
    if (_tapTimestamps.length < 2) return [];
    final intervals = <int>[];
    for (int i = 1; i < _tapTimestamps.length; i++) {
      intervals.add(_tapTimestamps[i] - _tapTimestamps[i - 1]);
    }
    return intervals;
  }

  // Compare two interval lists — returns true if rhythm is similar
  static bool compare(List<int> saved, List<int> live, {int toleranceMs = 300}) {
    if (saved.isEmpty || live.isEmpty) return false;
    if ((saved.length - live.length).abs() > 1) return false; // allow 1 tap difference

    final len = saved.length < live.length ? saved.length : live.length;
    int mismatches = 0;
    for (int i = 0; i < len; i++) {
      if ((saved[i] - live[i]).abs() > toleranceMs) mismatches++;
    }
    // Allow at most 1 mismatch
    return mismatches <= 1;
  }
}
