import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

enum TiltDirection { left, right, up, down }

class HeadTiltService {
  final List<TiltDirection> _sequence = [];
  StreamSubscription? _sub;
  TiltDirection? _lastDetected;

  List<TiltDirection> get sequence => List.unmodifiable(_sequence);

  void reset() {
    _sequence.clear();
    _lastDetected = null;
  }

  // Start listening for tilts — each distinct tilt direction is recorded once
  void startListening() {
    _sub = accelerometerEventStream().listen((event) {
      TiltDirection? dir;

      if (event.x < -4) dir = TiltDirection.left;
      else if (event.x > 4) dir = TiltDirection.right;
      else if (event.y > 6) dir = TiltDirection.up;
      else if (event.y < 2) dir = TiltDirection.down;

      if (dir != null && dir != _lastDetected) {
        _sequence.add(dir);
        _lastDetected = dir;
      } else if (dir == null) {
        _lastDetected = null; // phone returned to neutral — allow re-detection
      }
    });
  }

  void stopListening() {
    _sub?.cancel();
    _sub = null;
  }

  // Compare two sequences — must match exactly
  static bool compare(List<TiltDirection> saved, List<TiltDirection> live) {
    if (saved.isEmpty || live.isEmpty) return false;
    if (saved.length != live.length) return false;
    for (int i = 0; i < saved.length; i++) {
      if (saved[i] != live[i]) return false;
    }
    return true;
  }
}
