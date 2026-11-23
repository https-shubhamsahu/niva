// Sakshi Beam: step-off detector and validity gate (finale build).
//
// The beam is a plank on load cells read through an HX711 (planned 80 SPS).
// It does not measure force for a score. It answers one timing question the
// Flamingo test asks: when did the standing foot leave the beam?
//
// STATUS: written for the bench, NOT yet run on real hardware. Every
// threshold below is a starting value, not a validated one; the agreement
// study (check F6) tunes and measures them. The off-target test in
// tests/sakshi_beam_test.cpp feeds synthetic shapes only.
//
// Pure C++ with no Arduino dependency, so it compiles on a PC.

#ifndef SAKSHI_BEAM_H
#define SAKSHI_BEAM_H

#include <stdint.h>

enum SakshiBeamState : uint8_t {
  SAKSHI_NOT_READY = 0,  // no tare yet: the beam reports nothing and scores nothing
  SAKSHI_EMPTY,          // zeroed, nobody on the beam
  SAKSHI_LOADED,         // standing foot on the beam
  SAKSHI_NOT_VALID       // a load cell fault: the trial must not be scored
};

class SakshiBeamDetector {
 public:
  static constexpr float    kLoadedFraction  = 0.60f;  // of the learned standing load
  static constexpr float    kStepOffFraction = 0.25f;  // load below this = foot left
  static constexpr float    kMinLoad         = 200.0f; // counts above zero to count as someone on the beam
  static constexpr uint8_t  kDebounce        = 4;      // samples: 50 ms at 80 SPS
  static constexpr uint32_t kTareSamples     = 80;     // 1 s at 80 SPS

  SakshiBeamState state() const { return _state; }
  bool valid() const { return _state != SAKSHI_NOT_READY && _state != SAKSHI_NOT_VALID; }

  // Start a tare with nobody on the beam. Zero is the mean of kTareSamples.
  void beginTare() {
    _state = SAKSHI_NOT_READY;
    _tareCount = 0;
    _tareSum = 0.0;
    _stepOffPending = false;
    _stepOffCount = 0;
    _standing = 0.0f;
    _hasStepOff = false;
  }

  // One raw reading per sample (sum of all load cells, ADC counts). sensorOk
  // is false when the HX711 times out or a cell reads out of range, for
  // example an unplugged cell. nowMs is the beam hub's clock.
  void update(float raw, bool sensorOk, uint64_t nowMs) {
    if (!sensorOk) {
      if (_state != SAKSHI_NOT_READY) _state = SAKSHI_NOT_VALID;
      return;
    }
    if (_state == SAKSHI_NOT_VALID) return;  // only beginTare() clears a fault

    if (_state == SAKSHI_NOT_READY) {
      _tareSum += raw;
      if (++_tareCount >= kTareSamples) {
        _zero = (float)(_tareSum / (double)_tareCount);
        _state = SAKSHI_EMPTY;
      }
      return;
    }

    const float load = raw - _zero;

    if (_state == SAKSHI_EMPTY) {
      if (load > kMinLoad) {
        _standing = load;
        _state = SAKSHI_LOADED;
      }
      return;
    }

    // LOADED: follow the standing load slowly, watch for the drop.
    if (load > kLoadedFraction * _standing) {
      _standing += 0.05f * (load - _standing);
      _stepOffPending = false;
      _stepOffCount = 0;
      return;
    }
    if (load < kStepOffFraction * _standing || load < kMinLoad) {
      if (!_stepOffPending) { _stepOffPending = true; _stepOffAt = nowMs; }
      if (++_stepOffCount >= kDebounce) {
        _hasStepOff = true;
        _stepOffEventMs = _stepOffAt;  // first crossing, not confirmation
        _state = SAKSHI_EMPTY;
        _stepOffPending = false;
        _stepOffCount = 0;
      }
    } else {
      _stepOffPending = false;
      _stepOffCount = 0;
    }
  }

  // True once after each confirmed step-off. atMs is the first crossing.
  bool takeStepOff(uint64_t *atMs) {
    if (!_hasStepOff) return false;
    _hasStepOff = false;
    *atMs = _stepOffEventMs;
    return true;
  }

 private:
  SakshiBeamState _state = SAKSHI_NOT_READY;
  uint32_t _tareCount = 0;
  double   _tareSum = 0.0;
  float    _zero = 0.0f;
  float    _standing = 0.0f;
  bool     _stepOffPending = false;
  uint8_t  _stepOffCount = 0;
  uint64_t _stepOffAt = 0;
  bool     _hasStepOff = false;
  uint64_t _stepOffEventMs = 0;
};

#endif  // SAKSHI_BEAM_H
