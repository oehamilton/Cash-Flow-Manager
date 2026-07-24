import 'dart:async';

import 'package:flutter/foundation.dart';

/// Tracks user activity and fires [onIdle] after [timeoutMinutes].
///
/// `timeoutMinutes <= 0` disables the timer (never auto-lock).
class IdleLockController {
  IdleLockController({
    required this.onIdle,
    this.unit = const Duration(minutes: 1),
  });

  final VoidCallback onIdle;

  /// Duration represented by one "minute" unit (override in tests).
  final Duration unit;

  int _timeoutMinutes = 0;
  Timer? _timer;
  bool _armed = false;

  int get timeoutMinutes => _timeoutMinutes;

  void updateTimeout(int minutes) {
    _timeoutMinutes = minutes < 0 ? 0 : minutes;
    if (_armed) {
      _restart();
    }
  }

  void arm() {
    _armed = true;
    _restart();
  }

  void disarm() {
    _armed = false;
    _timer?.cancel();
    _timer = null;
  }

  void noteActivity() {
    if (!_armed || _timeoutMinutes <= 0) {
      return;
    }
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = null;
    if (!_armed || _timeoutMinutes <= 0) {
      return;
    }
    _timer = Timer(unit * _timeoutMinutes, () {
      if (_armed && _timeoutMinutes > 0) {
        onIdle();
      }
    });
  }

  void dispose() {
    disarm();
  }
}
