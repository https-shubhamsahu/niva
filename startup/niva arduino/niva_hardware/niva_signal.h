// =============================================================================
//  niva_signal.h  —  signal-path corrections for the Niva insole firmware
//  v1.0 · 5 September 2026
//
//  Header-only. Drop this file next to niva.ino and add:
//      #include "niva_signal.h"
//
//  Addresses defects FW-01 to FW-08 in the Niva Engineering & Regulatory
//  Work Package. Each block is tagged with the defect it fixes and the
//  published finding behind it, so the reasoning survives without the doc.
//
//  Nothing here talks to the network or the display. It is pure signal
//  path, so it can be unit-tested off-target and cited in the design file.
// =============================================================================

#ifndef NIVA_SIGNAL_H
#define NIVA_SIGNAL_H

#include <Arduino.h>
#include <math.h>

// -----------------------------------------------------------------------------
//  Rates.  FW-01: the shipped firmware ran the whole acquisition loop at 20 Hz
//  (STREAM_INTERVAL_MS = 50). The consensus minimum for IMU gait analysis in
//  walking is 100 Hz — the modal rate across 52 reviewed studies, with only 12
//  of 52 below it. Kinetic peak measurement (the piezo heel strike) needs
//  >= 500 Hz; at 100 Hz the measured peak is systematically wrong.
//
//  So: three clocks, not one. Acquisition is decoupled from telemetry.
// -----------------------------------------------------------------------------
static const uint32_t NIVA_FSR_PERIOD_US   = 10000;  // 100 Hz — FSR + IMU
static const uint32_t NIVA_PIEZO_PERIOD_US = 2000;   // 500 Hz — piezo only
static const uint32_t NIVA_STREAM_PERIOD_US= 50000;  // 20 Hz  — telemetry out

// =============================================================================
//  1.  Biquad low-pass  (FW-09)
//
//  The architecture documents specify an EMA at alpha = 0.15. Do not implement
//  it. At 100 Hz that filter has a -3 dB corner near 2.6 Hz and a DC group
//  delay of (1-a)/a = 5.67 samples = 57 ms — larger than the entire error
//  budget of a good pressure-based event detector (1.0 ms in the best
//  published algorithm), and the delay is frequency dependent, so it distorts
//  the intervals between events rather than merely shifting them.
//
//  Published practice is a Butterworth low-pass at 5-15 Hz. This is a
//  second-order direct-form-II transposed biquad, coefficients computed at
//  construction by the bilinear transform.
//
//  Causal, so it still has delay: about 1 sample per 0.1 of normalised
//  cutoff. If you later post-process a stored session rather than streaming,
//  run it forwards then backwards (filtfilt) for true zero phase.
// =============================================================================
class NivaBiquadLPF {
public:
  void begin(float sampleRateHz, float cutoffHz) {
    // Butterworth Q = 1/sqrt(2) for a maximally flat passband.
    const float q = 0.70710678f;
    const float w0 = 2.0f * (float)M_PI * cutoffHz / sampleRateHz;
    const float cw = cosf(w0), sw = sinf(w0);
    const float alpha = sw / (2.0f * q);

    const float b0 = (1.0f - cw) * 0.5f;
    const float b1 =  1.0f - cw;
    const float b2 = (1.0f - cw) * 0.5f;
    const float a0 =  1.0f + alpha;
    const float a1 = -2.0f * cw;
    const float a2 =  1.0f - alpha;

    _b0 = b0 / a0; _b1 = b1 / a0; _b2 = b2 / a0;
    _a1 = a1 / a0; _a2 = a2 / a0;
    _z1 = _z2 = 0.0f;
    _primed = false;
  }

  float step(float x) {
    // Prime the state on first sample so the filter does not spend the first
    // ~20 samples ramping up from zero and inventing a false loading edge.
    if (!_primed) {
      const float dcGain = (_b0 + _b1 + _b2) / (1.0f + _a1 + _a2);
      _z1 = x * (_b1 + _b2 - dcGain * (_a1 + _a2));
      _z2 = x * (_b2 - dcGain * _a2);
      _primed = true;
    }
    const float y = _b0 * x + _z1;
    _z1 = _b1 * x - _a1 * y + _z2;
    _z2 = _b2 * x - _a2 * y;
    return y;
  }

  void reset() { _z1 = _z2 = 0.0f; _primed = false; }

private:
  float _b0 = 1, _b1 = 0, _b2 = 0, _a1 = 0, _a2 = 0;
  float _z1 = 0, _z2 = 0;
  bool  _primed = false;
};

// =============================================================================
//  2.  Piezo peak-hold  (FW-02)
//
//  The shipped firmware passed PIN_PIEZO through the same oversampleADC()
//  mean as the four FSR channels. The piezo produces a sharp transient with a
//  sub-0.5 s rise and near-zero output under static load; averaging a
//  transient across the window attenuates precisely the feature the sensor
//  exists to capture. The literature uses maximum-within-window for this
//  channel specifically.
//
//  Sample fast (500 Hz), keep the maximum, report once per telemetry frame.
//  Never filter this path.
// =============================================================================
class NivaPeakHold {
public:
  void reset(float baseline) { _peak = 0.0f; _base = baseline; _n = 0; }

  inline void sample(float raw) {
    const float v = raw - _base;
    if (v > _peak) _peak = v;
    _n++;
  }

  // Returns the peak since the last consume() and rearms.
  float consume() { const float p = _peak; _peak = 0.0f; _n = 0; return p; }

  uint16_t samplesInWindow() const { return _n; }  // sanity-check the rate

private:
  float _peak = 0.0f, _base = 0.0f;
  uint16_t _n = 0;
};

// =============================================================================
//  3.  Per-sensor calibration  (FW-05)
//
//  Part-to-part sensitivity across 64 FSR402 specimens varied with a
//  coefficient of variation of about 26%. A characterisation across
//  temperature, curvature and tissue compliance concluded directly that
//  multiple FSRs in one system must be calibrated independently.
//
//  Without this, inter-sensor manufacturing tolerance is indistinguishable
//  from left-right gait asymmetry — which is the signal the product looks for.
//
//  Coefficients come from SOP-01: a cubic fitted through >= 10 points using
//  BOTH the loading and unloading curves. Loading-only regression was 76%
//  worse in the source study. Single-point linear costs ~24% of full range;
//  ten-point cubic costs 0.6%.
//
//  NOTE ON UNITS. These coefficients map ADC counts to a relative load index,
//  not to newtons and not to kPa. The FSR402's nominal range is 0.2-20 N
//  against a heel load of 300-800 N in walking, so it saturates. Do not
//  publish a force or pressure figure from this hardware — see the claims
//  matrix in the work package.
// =============================================================================
struct NivaSensorCal {
  // load_index = c3*x^3 + c2*x^2 + c1*x + c0,  x = (adc - zero)
  float c3 = 0.0f, c2 = 0.0f, c1 = 1.0f, c0 = 0.0f;
  float zero = 0.0f;          // current working zero, updated by rolling re-zero
  float zeroAtCal = 0.0f;     // zero recorded at calibration time
  float rmsePct = -1.0f;      // fit quality from SOP-01, for the design file
  float hysteresisPct = -1.0f;
  char  serial[12] = {0};     // physical sensor identity — traceability

  inline float apply(float adc) const {
    const float x = adc - zero;
    return ((c3 * x + c2) * x + c1) * x + c0;
  }
  inline bool isCalibrated() const { return rmsePct >= 0.0f; }
};

// =============================================================================
//  4.  Rolling re-zero  (FW-04, FW-08)
//
//  The shipped firmware took a 60-sample tare once and persisted it to NVS
//  across boots. FSR null-force output drifts +-16.2%/-13.8% across 24-60 C,
//  non-deterministically between temperatures. A baseline captured at ambient
//  is wrong once the insole reaches foot temperature; one reloaded from NVS
//  days later is wrong before the device is worn.
//
//  Fix: keep the NVS value as a startup estimate only, then re-zero whenever
//  genuine quiet standing is detected. Quiet standing means low IMU variance
//  AND a stable total FSR sum AND both sustained for a dwell period.
//
//  FW-08: the shipped code clamped (raw - baseline) at zero, discarding the
//  sign. A persistently negative residual is the signature of upward baseline
//  drift — the very fault this class exists to catch. Keep the sign here;
//  clamp only at the display layer.
// =============================================================================
class NivaRollingZero {
public:
  void begin(float initialZero, uint32_t dwellMs = 2000) {
    _zero = initialZero; _dwellMs = dwellMs;
    _quietSince = 0; _accum = 0; _n = 0; _updates = 0;
  }

  // Call at the FSR rate. Returns true on the sample where the zero updated.
  bool update(float adc, bool imuQuiet, bool loadStable, uint32_t nowMs) {
    if (!(imuQuiet && loadStable)) { _quietSince = 0; _accum = 0; _n = 0; return false; }
    if (_quietSince == 0) { _quietSince = nowMs; _accum = 0; _n = 0; }

    _accum += adc; _n++;

    if (nowMs - _quietSince >= _dwellMs && _n > 0) {
      const float fresh = _accum / (float)_n;
      _driftSinceStart += (fresh - _zero);
      // Ease toward the fresh estimate. A hard jump would put a step
      // discontinuity into the middle of a recording session.
      _zero += 0.25f * (fresh - _zero);
      _quietSince = nowMs; _accum = 0; _n = 0; _updates++;
      return true;
    }
    return false;
  }

  inline float zero() const { return _zero; }
  inline float driftSinceStart() const { return _driftSinceStart; }  // quality metric
  inline uint32_t updateCount() const { return _updates; }

private:
  float _zero = 0.0f, _accum = 0.0f, _driftSinceStart = 0.0f;
  uint32_t _quietSince = 0, _dwellMs = 2000, _updates = 0;
  uint16_t _n = 0;
};

// Quiet-standing detector. Feeds NivaRollingZero.
// Also gates SOP-01's requirement that a tare must never be taken under load:
// a calibration whose magnitude or variance indicates loading is rejected
// (hazard H8 in the risk file — tare-while-standing offsets every subsequent
// reading downward and contributes directly to false reassurance).
class NivaQuietDetector {
public:
  void begin(float accelVarThresh = 0.02f, float loadVarThresh = 25.0f) {
    _aThresh = accelVarThresh; _lThresh = loadVarThresh;
    _aMean = _aM2 = _lMean = _lM2 = 0.0f; _n = 0;
  }

  // Rolling variance over a short window (Welford, windowed by periodic reset).
  void push(float accelMag, float loadSum) {
    _n++;
    float d = accelMag - _aMean; _aMean += d / _n; _aM2 += d * (accelMag - _aMean);
    d = loadSum - _lMean; _lMean += d / _n; _lM2 += d * (loadSum - _lMean);
    if (_n >= 50) { // ~0.5 s at 100 Hz
      _aVar = _aM2 / (_n - 1); _lVar = _lM2 / (_n - 1);
      _lLast = _lMean;
      _n = 0; _aMean = _aM2 = _lMean = _lM2 = 0.0f;
      _valid = true;
    }
  }

  inline bool imuQuiet()   const { return _valid && _aVar < _aThresh; }
  inline bool loadStable() const { return _valid && _lVar < _lThresh; }
  // Unloaded means stable AND near zero — the condition a tare requires.
  inline bool unloaded(float zeroSum, float tol = 40.0f) const {
    return loadStable() && fabsf(_lLast - zeroSum) < tol;
  }

private:
  float _aThresh = 0.02f, _lThresh = 25.0f;
  float _aMean = 0, _aM2 = 0, _aVar = 0;
  float _lMean = 0, _lM2 = 0, _lVar = 0, _lLast = 0;
  uint16_t _n = 0;
  bool _valid = false;
};

// =============================================================================
//  5.  Mahony AHRS  (FW-07)
//
//  The shipped firmware used a fixed-coefficient complementary filter
//  (0.96 gyro / 0.04 accel) whose blend is independent of dt, so its effective
//  time constant changes whenever the loop period changes.
//
//  Measured against optical reference on foot-mounted data: basic
//  complementary AHRS 2.09-4.47 deg RMSE; Madgwick 0.31-0.59; Mahony
//  0.38-0.65 — and both ran FASTER than the basic filter. There is no
//  performance argument for keeping the old one on an ESP32.
//
//  No magnetometer on the MPU6050, so yaw is unobservable and will drift
//  without bound. Only pitch and roll are recoverable. Do not report yaw.
// =============================================================================
class NivaMahony {
public:
  void begin(float kp = 2.0f, float ki = 0.005f) {
    _kp = kp; _ki = ki;
    _q0 = 1; _q1 = _q2 = _q3 = 0;
    _ix = _iy = _iz = 0;
  }

  // ax,ay,az in g (any consistent scale — normalised internally)
  // gx,gy,gz in rad/s.  dt in seconds.
  void update(float ax, float ay, float az, float gx, float gy, float gz, float dt) {
    const float n = sqrtf(ax * ax + ay * ay + az * az);
    if (n > 1e-6f) {
      ax /= n; ay /= n; az /= n;

      // Estimated gravity direction from the current quaternion.
      const float vx = 2.0f * (_q1 * _q3 - _q0 * _q2);
      const float vy = 2.0f * (_q0 * _q1 + _q2 * _q3);
      const float vz = _q0 * _q0 - _q1 * _q1 - _q2 * _q2 + _q3 * _q3;

      // Error is the cross product between measured and estimated gravity.
      const float ex = ay * vz - az * vy;
      const float ey = az * vx - ax * vz;
      const float ez = ax * vy - ay * vx;

      if (_ki > 0.0f) { _ix += ex * _ki * dt; _iy += ey * _ki * dt; _iz += ez * _ki * dt; }
      gx += _kp * ex + _ix;
      gy += _kp * ey + _iy;
      gz += _kp * ez + _iz;
    }

    const float hdt = 0.5f * dt;
    const float q0 = _q0, q1 = _q1, q2 = _q2, q3 = _q3;
    _q0 += (-q1 * gx - q2 * gy - q3 * gz) * hdt;
    _q1 += ( q0 * gx + q2 * gz - q3 * gy) * hdt;
    _q2 += ( q0 * gy - q1 * gz + q3 * gx) * hdt;
    _q3 += ( q0 * gz + q1 * gy - q2 * gx) * hdt;

    const float qn = sqrtf(_q0 * _q0 + _q1 * _q1 + _q2 * _q2 + _q3 * _q3);
    if (qn > 1e-9f) { _q0 /= qn; _q1 /= qn; _q2 /= qn; _q3 /= qn; }
  }

  float pitchDeg() const {
    float s = 2.0f * (_q0 * _q2 - _q3 * _q1);
    if (s >  1.0f) s =  1.0f;
    if (s < -1.0f) s = -1.0f;
    return asinf(s) * 57.29577951f;
  }
  float rollDeg() const {
    return atan2f(2.0f * (_q0 * _q1 + _q2 * _q3),
                  1.0f - 2.0f * (_q1 * _q1 + _q2 * _q2)) * 57.29577951f;
  }

private:
  float _kp = 2.0f, _ki = 0.005f;
  float _q0 = 1, _q1 = 0, _q2 = 0, _q3 = 0;
  float _ix = 0, _iy = 0, _iz = 0;
};

// =============================================================================
//  6.  MPU6050 range  (FW-03)
//
//  The shipped firmware divided by 16384.0f, which is AFS_SEL = 0 (+-2 g).
//  Foot-mounted heel-strike accelerations have been measured at 24.62 +- 4.1 g.
//  At +-2 g the accelerometer clips by an order of magnitude on every step,
//  and clipping biases everything downstream of integration.
//
//  +-16 g is the best the MPU6050 offers. The literature recommends a minimum
//  of +-32 g and reports that even +-16 g underestimates peak tibial
//  acceleration by 28%. So: set +-16 g, and take impact magnitude from the
//  piezo, never from the accelerometer. Record this as a known limitation and
//  a reason to replace the part in the next revision.
// =============================================================================
static const uint8_t  NIVA_MPU_ADDR       = 0x68;
static const uint8_t  NIVA_REG_ACCEL_CFG  = 0x1C;
static const uint8_t  NIVA_REG_GYRO_CFG   = 0x1B;
static const uint8_t  NIVA_AFS_16G        = 0x18;  // AFS_SEL = 3
static const uint8_t  NIVA_FS_500DPS      = 0x08;  // FS_SEL  = 1
static const float    NIVA_ACCEL_LSB_16G  = 2048.0f;   // LSB per g
static const float    NIVA_GYRO_LSB_500   = 65.5f;     // LSB per deg/s
static const float    NIVA_CLIP_G         = 15.6f;     // flag near full scale

// Call once after Wire.begin(), in place of the old +-2 g setup.
// Returns false if the device does not acknowledge — do not silently continue
// with an unconfigured IMU (that is how corrupted data enters the pipeline).
inline bool nivaConfigureIMU(TwoWire &bus) {
  bus.beginTransmission(NIVA_MPU_ADDR);
  bus.write(NIVA_REG_ACCEL_CFG); bus.write(NIVA_AFS_16G);
  if (bus.endTransmission() != 0) return false;

  bus.beginTransmission(NIVA_MPU_ADDR);
  bus.write(NIVA_REG_GYRO_CFG); bus.write(NIVA_FS_500DPS);
  if (bus.endTransmission() != 0) return false;

  // DLPF to 44 Hz (CONFIG reg 0x1A = 3). Analog anti-aliasing is still needed
  // on the FSR channels (FW-06) — this only helps the IMU path.
  bus.beginTransmission(NIVA_MPU_ADDR);
  bus.write(0x1A); bus.write(0x03);
  return bus.endTransmission() == 0;
}

// =============================================================================
//  7.  Step gate  (persistence rule)
//
//  Twelve steps per foot is the canonical minimum for valid and reliable
//  in-shoe plantar pressure data in neuropathic diabetic patients. Nothing
//  pressure-derived should be reported below it.
//
//  Variability metrics are a different animal. Mean gait metrics reach
//  ICC > 0.90 at about 10 strides, but variability metrics need 10-80, and
//  stride velocity variability has been reported at ICC 0.226 under dual
//  task. Ankle sway variance is a variability metric and must not share a
//  window with the pressure means — hence two counters, not one.
// =============================================================================
static const uint16_t NIVA_MIN_STEPS_PRESSURE  = 12;
static const uint16_t NIVA_MIN_STRIDES_VARIANCE = 80;

class NivaStepGate {
public:
  void reset() { _steps = 0; _strides = 0; }
  void onStep()   { _steps++; }
  void onStride() { _strides++; }
  inline bool pressureMetricsValid() const { return _steps   >= NIVA_MIN_STEPS_PRESSURE; }
  inline bool varianceMetricsValid() const { return _strides >= NIVA_MIN_STRIDES_VARIANCE; }
  inline uint16_t steps()   const { return _steps; }
  inline uint16_t strides() const { return _strides; }
private:
  uint16_t _steps = 0, _strides = 0;
};

// =============================================================================
//  8.  Adaptive threshold  (CFAR-style)
//
//  Fixed thresholds lose roughly 2x accuracy on pathological gait (threshold
//  error rose from < 2% to 4.4% of the gait cycle in stroke patients) — and
//  pathological gait is the target population. The published two-FSR-per-foot
//  equivalent of this design used an adaptive constant-false-alarm-rate
//  threshold and reached 88.9-90.2% reliability with < 1 ms latency, so
//  adaptivity is not a compute problem.
//
//  Threshold = running mean + k * running standard deviation, over a window
//  long enough to span several strides. Raise k to trade sensitivity for
//  false-alarm rate; k is the knob to report in the pilot, since false-alarm
//  rate is a pre-registered endpoint (hazard H5, alarm fatigue).
// =============================================================================
class NivaAdaptiveThreshold {
public:
  void begin(float k = 2.5f, float tau = 0.995f) { _k = k; _tau = tau; _mean = 0; _var = 0; _ready = false; _n = 0; }

  void observe(float x) {
    if (!_ready) { _mean = x; _var = 1.0f; _ready = true; }
    const float d = x - _mean;
    _mean += (1.0f - _tau) * d;
    _var   = _tau * _var + (1.0f - _tau) * d * d;
    if (_n < 65535) _n++;
  }

  inline float threshold() const { return _mean + _k * sqrtf(_var > 0 ? _var : 0); }
  // Warm-up guard: do not emit detections until the estimator has seen enough.
  inline bool warmedUp() const { return _n > 300; }   // ~3 s at 100 Hz
  inline bool exceeds(float x) const { return warmedUp() && x > threshold(); }

private:
  float _k = 2.5f, _tau = 0.995f, _mean = 0, _var = 0;
  uint16_t _n = 0;
  bool _ready = false;
};

// =============================================================================
//  9.  Contact edges  (fitness timing)
//
//  The FSR402 saturates under walking load (section 3), so the size of a
//  reading says little once a region is loaded. The edges still carry
//  information: when a region starts and stops carrying load. Heel before
//  toe, cadence, contact time and a single-leg hold are all questions about
//  edges, not about force.
//
//  Each channel is a Schmitt trigger. Its thresholds are fractions of that
//  channel's own typical loaded level, learned from completed contacts, so
//  the detector needs no per-device tuning for the divider or ADC range. A
//  floor taken from the noise seen during the unloaded tare stops it firing
//  on ADC noise before any contact has been seen.
//
//  An edge must persist for kDebounce samples to count, but it is stamped
//  with the first sample that crossed, so debouncing adds no timing bias.
//  Every channel passes through the same low-pass filter (FW-09), which
//  delays all edges by a similar amount: edge order and durations are more
//  trustworthy than absolute edge times.
//
//  Every constant below is a starting value, not a validated one. Checks
//  F1-F4 of the SIH26213 plan compare these edges with a trained tester and
//  slow-motion video; revise the constants from those results.
// =============================================================================
static const uint8_t NIVA_EDGE_ON  = 0;
static const uint8_t NIVA_EDGE_OFF = 1;
static const int8_t  NIVA_FOOT     = -1;   // channel value of a whole-foot event
static const int8_t  NIVA_TIE      = -1;   // 'first' value when channels tied

struct NivaContactEvent {
  uint64_t tMs;     // first crossing, device clock (ms since boot)
  int8_t   channel; // 0..3 for one sensor, NIVA_FOOT for the whole foot
  uint8_t  edge;    // NIVA_EDGE_ON or NIVA_EDGE_OFF
  int8_t   first;   // foot ON only: channel that loaded first, or NIVA_TIE
};

// Fixed-size FIFO between the 100 Hz detector and the 20 Hz telemetry frame.
// When full it refuses new events and counts them, so a loss is visible in
// the telemetry instead of silently shortening a step.
class NivaContactQueue {
public:
  static const uint8_t kCapacity = 32;

  void clear() { _head = 0; _count = 0; _dropped = 0; }

  void push(const NivaContactEvent &e) {
    if (_count >= kCapacity) { _dropped++; return; }
    _buf[(_head + _count) % kCapacity] = e;
    _count++;
  }

  bool pop(NivaContactEvent &out) {
    if (_count == 0) return false;
    out = _buf[_head];
    _head = (_head + 1) % kCapacity;
    _count--;
    return true;
  }

  uint8_t size() const { return _count; }
  uint32_t dropped() const { return _dropped; }   // since the last clear()

private:
  NivaContactEvent _buf[kCapacity];
  uint8_t _head = 0, _count = 0;
  uint32_t _dropped = 0;
};

class NivaContactDetector {
public:
  static const uint8_t kChannels = 4;

  static constexpr float   kOnFraction  = 0.15f;  // of the channel's loaded level
  static constexpr float   kOffFraction = 0.08f;
  static constexpr float   kNoiseSigmas = 8.0f;   // floor, in tare-noise sigmas
  static constexpr float   kMinFloor    = 40.0f;  // load-index units (ADC counts
                                                  // with the identity calibration)
  static constexpr float   kLevelWeight = 0.25f;  // per completed contact
  static const     uint8_t kDebounce    = 3;      // samples: 30 ms at 100 Hz

  // Call when a tare completes. noiseSigma is each channel's standard
  // deviation while unloaded, already in load-index units.
  void begin(const float noiseSigma[kChannels]) {
    for (uint8_t i = 0; i < kChannels; ++i) {
      _ch[i] = Channel();
      const float sigmaFloor = kNoiseSigmas * (noiseSigma[i] > 0.0f ? noiseSigma[i] : 0.0f);
      _ch[i].noiseFloor = sigmaFloor > kMinFloor ? sigmaFloor : kMinFloor;
    }
    _queue.clear();
  }

  // Forget all contact state, e.g. when a new tare starts.
  void reset() {
    for (uint8_t i = 0; i < kChannels; ++i) _ch[i] = Channel();
    _queue.clear();
  }

  // Feed one filtered sample per channel at the FSR rate. Confirmed edges go
  // into queue(), stamped with the time of their first crossing.
  void update(const float value[kChannels], uint64_t nowMs) {
    const uint8_t before = mask();
    uint8_t turnedOn = 0;
    uint64_t onAt = 0, offAt = 0;

    for (uint8_t i = 0; i < kChannels; ++i) {
      Channel &c = _ch[i];
      const float v = value[i];
      if (c.on && v > c.peak) c.peak = v;

      const bool crossing = c.on ? (v < offThreshold(c)) : (v > onThreshold(c));
      if (!crossing) { c.pending = 0; continue; }
      if (c.pending == 0) c.since = nowMs;
      if (++c.pending < kDebounce) continue;

      c.pending = 0;
      c.on = !c.on;
      if (c.on) {
        c.peak = v;
        turnedOn |= (uint8_t)(1u << i);
        onAt = c.since;
      } else {
        c.level = (c.level <= 0.0f) ? c.peak : c.level + kLevelWeight * (c.peak - c.level);
        offAt = c.since;
      }
      _queue.push(event(c.since, (int8_t)i, c.on ? NIVA_EDGE_ON : NIVA_EDGE_OFF, NIVA_TIE));
    }

    // Channels that confirm on the same call started crossing on the same
    // sample (equal debounce), so they share one first-crossing time and
    // cannot be ordered at this sample rate: that is reported as a tie.
    const uint8_t after = mask();
    if (before == 0 && after != 0) {
      int8_t first = NIVA_TIE;
      if ((turnedOn & (uint8_t)(turnedOn - 1)) == 0) {
        for (uint8_t i = 0; i < kChannels; ++i) {
          if (turnedOn & (1u << i)) first = (int8_t)i;
        }
      }
      _queue.push(event(onAt, NIVA_FOOT, NIVA_EDGE_ON, first));
    } else if (before != 0 && after == 0) {
      _queue.push(event(offAt, NIVA_FOOT, NIVA_EDGE_OFF, NIVA_TIE));
    }
  }

  // Bit i set while channel i is in contact (0 heel, 1 inner, 2 outer, 3 toe).
  uint8_t mask() const {
    uint8_t m = 0;
    for (uint8_t i = 0; i < kChannels; ++i) if (_ch[i].on) m |= (uint8_t)(1u << i);
    return m;
  }

  NivaContactQueue &queue() { return _queue; }
  float level(uint8_t i) const { return _ch[i].level; }   // for bench logging
  float noiseFloor(uint8_t i) const { return _ch[i].noiseFloor; }

private:
  struct Channel {
    float noiseFloor = kMinFloor;
    float level = 0.0f;     // typical loaded level, learned per contact
    float peak = 0.0f;      // highest value in the current contact
    uint64_t since = 0;     // first crossing of the pending edge
    uint8_t pending = 0;    // consecutive samples past the threshold
    bool on = false;
  };

  static float onThreshold(const Channel &c) {
    const float rel = kOnFraction * c.level;
    return rel > c.noiseFloor ? rel : c.noiseFloor;
  }
  // Always below onThreshold, so the trigger has hysteresis at every level.
  static float offThreshold(const Channel &c) {
    const float rel = kOffFraction * c.level;
    const float half = 0.5f * c.noiseFloor;
    return rel > half ? rel : half;
  }

  static NivaContactEvent event(uint64_t t, int8_t ch, uint8_t edge, int8_t first) {
    NivaContactEvent e;
    e.tMs = t; e.channel = ch; e.edge = edge; e.first = first;
    return e;
  }

  Channel _ch[kChannels];
  NivaContactQueue _queue;
};

#endif // NIVA_SIGNAL_H
