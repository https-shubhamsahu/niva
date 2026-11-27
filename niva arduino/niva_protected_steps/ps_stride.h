// ps_stride.h - stride detector for the ankle hub. Pure C++; host-tested.
//
// Input: shank angular velocity in the sagittal plane (deg/s), one sample
// per IMU read at 100 Hz, from the gyro axis chosen with `axis`.
//
// Method. In walking, shank sagittal angular velocity shows one large
// positive peak per stride, in mid-swing, followed by a negative local
// minimum near initial contact. Using these two features is the approach of
// Aminian et al. (J Biomech 2002) and Salarian et al. (IEEE TBME 2004).
// Their thresholds are not copied here; every constant below is a design
// choice, to be tuned in RQ1 against video.
//
//  1. Adaptive threshold: thr = max(floorDps, peakFraction * level), where
//     level is a running average of accepted peak heights (weight
//     levelWeight per stride). After idleResetMs without a stride the level
//     is forgotten, so the first stride after a pause only has to beat the
//     floor.
//  2. A candidate starts when w rises above thr, no sooner than
//     refractoryMs after the previous accepted peak. Its peak is the
//     maximum while w stays above thr. A candidate shorter than
//     minAboveSamples is discarded as a spike.
//  3. After the peak, the detector looks for the first local minimum of w
//     that is below zero: the minimum is confirmed once w climbs icRiseDps
//     above it. If none is confirmed within icSearchMs of the peak, the
//     lowest sample in that window is used.
//  4. The stride is reported at the time of that minimum (an estimate of
//     initial contact, which is when the insole should see foot load), with
//     the peak time and height kept for the log.
//
// The stride is therefore reported up to icSearchMs after mid-swing. The
// hub's settle_ms (2,000 ms by default) is much longer, so this delay does
// not affect matching.

#ifndef PS_STRIDE_H
#define PS_STRIDE_H

#include <stdint.h>

struct PsStrideParams {
  float floorDps = 50.0f;        // design choice
  float peakFraction = 0.4f;     // design choice
  float levelWeight = 0.25f;     // design choice
  uint32_t refractoryMs = 400;   // design choice: shorter than any stride
                                 // period we expect, including running
  uint32_t idleResetMs = 3000;   // design choice
  uint32_t icSearchMs = 300;     // design choice
  float icRiseDps = 20.0f;       // design choice
  uint8_t minAboveSamples = 2;   // design choice: 20 ms at 100 Hz
};

struct PsStride {
  uint32_t tMs;      // estimated initial contact (local minimum after the peak)
  uint32_t peakMs;   // mid-swing peak
  float peakDps;
};

class PsStrideDetector {
public:
  void begin(const PsStrideParams& p = PsStrideParams()) {
    _p = p;
    reset();
  }

  void reset() {
    _state = IDLE;
    _level = 0.0f;
    _havePeak = false;
    _lastPeakMs = 0;
    _count = 0;
  }

  float threshold() const {
    const float rel = _p.peakFraction * _level;
    return rel > _p.floorDps ? rel : _p.floorDps;
  }

  uint32_t count() const { return _count; }

  // Feed one sample. Returns true and fills `out` when a stride is complete.
  bool update(float w, uint32_t nowMs, PsStride& out) {
    if (_havePeak && _state == IDLE && (uint32_t)(nowMs - _lastPeakMs) > _p.idleResetMs) {
      _level = 0.0f;  // walking paused: forget the old peak level
    }
    switch (_state) {
      case IDLE:
        if (w > threshold() &&
            (!_havePeak || (uint32_t)(nowMs - _lastPeakMs) >= _p.refractoryMs)) {
          _state = ABOVE;
          _peak = w;
          _peakMs = nowMs;
          _above = 1;
        }
        return false;

      case ABOVE:
        if (w > threshold()) {
          if (w > _peak) { _peak = w; _peakMs = nowMs; }
          if (_above < 255) _above++;
          return false;
        }
        if (_above < _p.minAboveSamples) {  // a spike, not a swing
          _state = IDLE;
          return false;
        }
        _state = SEARCH;
        _min = w;
        _minMs = nowMs;
        return false;

      case SEARCH: {
        if (w < _min) { _min = w; _minMs = nowMs; }
        const bool confirmed = _min < 0.0f && w > _min + _p.icRiseDps;
        const bool timedOut = (uint32_t)(nowMs - _peakMs) >= _p.icSearchMs;
        if (!confirmed && !timedOut) return false;
        out.tMs = _minMs;
        out.peakMs = _peakMs;
        out.peakDps = _peak;
        _level = (_level <= 0.0f) ? _peak : _level + _p.levelWeight * (_peak - _level);
        _lastPeakMs = _peakMs;
        _havePeak = true;
        _count++;
        _state = IDLE;
        return true;
      }
    }
    return false;
  }

private:
  enum State : uint8_t { IDLE, ABOVE, SEARCH };
  PsStrideParams _p;
  State _state = IDLE;
  float _level = 0.0f, _peak = 0.0f, _min = 0.0f;
  uint32_t _peakMs = 0, _minMs = 0, _lastPeakMs = 0, _count = 0;
  uint8_t _above = 0;
  bool _havePeak = false;
};

// Gyro zero-rate offset. An MPU6050 at rest reads a few to tens of deg/s
// on each axis (about -13.5 deg/s on the z axis of our first board, read
// once at rest on 3 November 2026). That offset shifts every threshold, so
// it is estimated while the leg is still and subtracted. Design choices: a
// block of kBlock samples (1 s at 100 Hz) counts as still if its standard
// deviation is below kStillStdDps; the estimate then moves halfway to the
// block mean. Before the first still block the offset is taken as zero.
class PsGyroBias {
public:
  static const uint16_t kBlock = 100;
  static constexpr float kStillStdDps = 3.0f;

  void reset() { _n = 0; _sum = 0; _sq = 0; _bias = 0; _have = false; }

  // Feeds one raw sample; returns the sample with the offset removed.
  float update(float w) {
    _sum += w;
    _sq += (double)w * w;
    if (++_n >= kBlock) {
      const double mean = _sum / _n;
      const double var = _sq / _n - mean * mean;
      if (var < (double)kStillStdDps * kStillStdDps) {
        _bias = _have ? _bias + 0.5f * ((float)mean - _bias) : (float)mean;
        _have = true;
      }
      _n = 0;
      _sum = 0;
      _sq = 0;
    }
    return w - _bias;
  }

  float bias() const { return _bias; }
  bool known() const { return _have; }

private:
  uint16_t _n = 0;
  double _sum = 0, _sq = 0;
  float _bias = 0;
  bool _have = false;
};

#endif  // PS_STRIDE_H
