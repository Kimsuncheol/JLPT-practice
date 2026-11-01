import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final dailyLessonClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Foreground scheduling uses the device's calendar, including DST boundaries.
/// Suspended apps catch up on resume rather than relying on background timers.
class DailyLessonRefresh {
  DailyLessonRefresh({
    required this.onRefresh,
    DateTime Function()? now,
    this.retryInterval = const Duration(minutes: 15),
  }) : _now = now ?? DateTime.now {
    _lastAttempt = _now();
    _scheduleMidnight();
    _scheduleRetry();
  }

  final void Function() onRefresh;
  final DateTime Function() _now;
  final Duration retryInterval;
  late DateTime _lastAttempt;
  Timer? _midnight, _retry;
  String? _readyDay;
  bool _active = true;
  bool _disposed = false;

  static String day(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  void _scheduleMidnight() {
    _midnight?.cancel();
    if (!_active || _disposed) return;
    final now = _now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _midnight = Timer(next.difference(now), () {
      _refresh();
      _scheduleMidnight();
    });
  }

  void _scheduleRetry() {
    _retry?.cancel();
    if (!_active || _disposed || _readyDay == day(_now())) return;
    _retry = Timer(retryInterval, _refresh);
  }

  void _refresh() {
    if (!_active || _disposed) return;
    _lastAttempt = _now();
    _scheduleRetry();
    onRefresh();
  }

  void received({String? publicationDate, bool offline = false}) {
    _retry?.cancel();
    _readyDay = !offline && publicationDate == day(_now())
        ? publicationDate
        : null;
    _scheduleRetry();
  }

  void setActive(bool active) {
    if (_disposed) return;
    _active = active;
    if (!active) {
      _midnight?.cancel();
      _retry?.cancel();
      return;
    }
    _scheduleMidnight();
    final now = _now();
    if (day(now) != day(_lastAttempt) ||
        now.difference(_lastAttempt) >= retryInterval ||
        now.isBefore(_lastAttempt)) {
      _refresh();
    } else {
      // A short suspension may interrupt an outstanding or failed request.
      _scheduleRetry();
    }
  }

  void dispose() {
    _disposed = true;
    _midnight?.cancel();
    _retry?.cancel();
  }
}
