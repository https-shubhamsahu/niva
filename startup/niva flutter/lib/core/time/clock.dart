import 'dart:collection';
import 'dart:math' as math;

/// Milliseconds from a monotonic stopwatch. Test timing uses this rather
/// than the wall clock, which can jump when the phone syncs its time.
class MonotonicClock {
  final Stopwatch _watch = Stopwatch()..start();

  int get nowMs => _watch.elapsedMilliseconds;
}

/// Maps the insole's clock (ms since it booted) onto the phone's monotonic
/// clock.
///
/// Every frame gives `phone - device = offset + radio delay`. The delay is
/// never negative, so the smallest recent value is the best estimate of the
/// offset. Events are mapped with it, which places each one at the earliest
/// phone time consistent with the recent frames.
class ClockSync {
  /// Frames in the window: 2 s at 20 Hz.
  static const window = 40;

  final ListQueue<int> _offsets = ListQueue<int>();
  int? _lastDeviceMs;

  void observe({required int deviceMs, required int phoneMs}) {
    final last = _lastDeviceMs;
    if (last != null && deviceMs < last) {
      // The insole restarted, so its old offset no longer applies.
      _offsets.clear();
    }
    _lastDeviceMs = deviceMs;
    _offsets.addLast(phoneMs - deviceMs);
    if (_offsets.length > window) _offsets.removeFirst();
  }

  /// Null until at least one frame has been observed.
  int? toPhone(int deviceMs) {
    if (_offsets.isEmpty) return null;
    return deviceMs + _offsets.reduce(math.min);
  }

  void reset() {
    _offsets.clear();
    _lastDeviceMs = null;
  }
}
