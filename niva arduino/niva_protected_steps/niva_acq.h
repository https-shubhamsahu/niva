// niva_acq.h - insole acquisition in its own FreeRTOS task (FW-01, FW-02, FW-03).
//
// Added 3 November 2026 for Niva: Protected Steps. It also changes the
// active sketch used by Aavishkar and SIH26213; their telemetry fields are
// unchanged.
//
// Why a task. niva_signal.h set the rates (100 Hz FSR + IMU, 500 Hz piezo)
// but the sketch polled them from loop(), and loop() also blocks: a 330-byte
// Serial.println at 115200 baud waits for the UART for about 17 ms (the TX
// FIFO is 128 bytes; arithmetic from the baud rate, not measured), and an
// OLED refresh writes 1 KB over I2C. While loop() is blocked no sample is
// taken, so the piezo transient (FW-02) can be missed entirely and FSR
// samples are dropped. Here a task pinned to core 1 (core 0 on the
// single-core ESP32-C3) at a priority above
// loop() wakes every 2 ms (vTaskDelayUntil, 1 kHz FreeRTOS tick):
//   - every wake: one piezo read into the peak-hold (FW-02, never filtered);
//   - every 5th wake (10 ms, 100 Hz): an FSR burst of 16 rounds over the
//     four channels, interleaved so all four describe the same 1-2 ms, with
//     a piezo read every 4 rounds so the burst does not blind the piezo;
//     then one MPU6050 read at +-16 g (FW-03) and the signal path of
//     niva_signal.h (biquad, rolling zero, quiet detector, Mahony, contact
//     detector), exactly as the sketch did it before.
// The achieved rates are counted, so they can be measured on the bench
// ("status" on serial) instead of assumed.
//
// Shared state is guarded by a spinlock and copied out by snapshot().
// Wire is thread-safe in arduino-esp32 3.x (HAL locks), so the OLED drawn
// from loop() and the IMU read here interleave transaction by transaction.
//
// Board access (ADC, IMU, LED, task core) goes through niva_board.h since
// 9 November 2026, so the same acquisition runs on the DevKit prototypes
// and on the pod Rev C.2 (MCP3208 + LSM6DSO32 over SPI). The niva_hardware/
// copy in the startup tree predates that and no longer matches this file.

#ifndef NIVA_ACQ_H
#define NIVA_ACQ_H

#include <Arduino.h>
#include <Wire.h>

#include "esp_timer.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "niva_board.h"
#include "niva_signal.h"

// One clock for frames and contact events: milliseconds since boot from the
// 64-bit esp_timer. micros() is 32-bit and wraps after about 71.6 minutes.
static inline uint64_t nivaDeviceMs() {
  return static_cast<uint64_t>(esp_timer_get_time() / 1000);
}

enum class NivaAcqValidity : uint8_t { uncalibrated, calibrating, valid };

static inline const char* nivaAcqValidityText(NivaAcqValidity v) {
  switch (v) {
    case NivaAcqValidity::valid: return "valid";
    case NivaAcqValidity::calibrating: return "calibrating";
    default: return "uncalibrated";
  }
}

struct NivaAcqSnapshot {
  NivaAcqValidity validity;
  float fsr[4];
  float impact;          // piezo peak since the previous snapshot
  float pitch, roll, accZ;
  bool imuClipped;
  uint8_t contactMask;
  uint32_t eventsDropped;
  uint32_t tareGeneration;  // increments at every tare start
};

// Cumulative since boot. `overruns` counts 2 ms wake-ups whose deadline had
// already passed (normal right after an FSR burst longer than 2 ms; the
// piezo is still read four times inside the burst). burstUsMax is the
// longest FSR + IMU burst, in microseconds.
struct NivaAcqStats {
  uint32_t piezoSamples, fsrSamples, imuReads, imuFailures, overruns;
  uint32_t burstUsLast, burstUsMax;
};

struct NivaTareReport {
  float zero[4];
  float noise[4];   // contact detector noise floor per channel
};

class NivaAcquisition {
public:
  static const uint16_t kTareSamples = 100;   // 1 s at 100 Hz (unchanged)
  static const uint8_t kOversample = 16;      // FSR mean of 16 (unchanged)
  static const uint32_t kTickMs = 2;          // 500 Hz piezo
  static const uint8_t kFsrEvery = 5;         // 100 Hz FSR + IMU

  bool begin(bool imuAvailable, UBaseType_t priority = 5, BaseType_t core = NIVA_TASK_CORE) {
    _imu = imuAvailable;
    _quiet.begin();
    if (_imu) _ahrs.begin();
    return xTaskCreatePinnedToCore(taskEntry, "niva_acq", 4096, this, priority, &_task, core) == pdPASS;
  }

  void requestTare() {
    portENTER_CRITICAL(&_mux);
    _tareRequested = true;
    portEXIT_CRITICAL(&_mux);
  }

  void invalidate() {
    portENTER_CRITICAL(&_mux);
    _validity = NivaAcqValidity::uncalibrated;
    _contacts.reset();
    _tareGen++;
    portEXIT_CRITICAL(&_mux);
    nivaBoardStatusLed(false);
  }

  // Copies the latest values and consumes the piezo peak.
  void snapshot(NivaAcqSnapshot& s) {
    portENTER_CRITICAL(&_mux);
    s.validity = _validity;
    for (uint8_t i = 0; i < 4; ++i) s.fsr[i] = _fsr[i];
    s.impact = _piezo.consume();
    s.pitch = _pitch;
    s.roll = _roll;
    s.accZ = _accZ;
    s.imuClipped = _imuClipped;
    s.contactMask = _contacts.mask();
    s.eventsDropped = _contacts.queue().dropped();
    s.tareGeneration = _tareGen;
    portEXIT_CRITICAL(&_mux);
  }

  uint8_t popEvents(NivaContactEvent* out, uint8_t max) {
    uint8_t n = 0;
    portENTER_CRITICAL(&_mux);
    while (n < max && _contacts.queue().pop(out[n])) ++n;
    portEXIT_CRITICAL(&_mux);
    return n;
  }

  NivaAcqValidity validity() {
    portENTER_CRITICAL(&_mux);
    const NivaAcqValidity v = _validity;
    portEXIT_CRITICAL(&_mux);
    return v;
  }

  bool loadStable() {
    portENTER_CRITICAL(&_mux);
    const bool s = _quiet.loadStable();
    portEXIT_CRITICAL(&_mux);
    return s;
  }

  // Raw ADC means of the latest 100 Hz sample (for bench checks).
  void lastRaw(float raw[4]) {
    portENTER_CRITICAL(&_mux);
    for (uint8_t i = 0; i < 4; ++i) raw[i] = _raw[i];
    portEXIT_CRITICAL(&_mux);
  }

  // True once after each completed tare.
  bool takeTareReport(NivaTareReport& r) {
    portENTER_CRITICAL(&_mux);
    const bool has = _tareReportReady;
    if (has) r = _tareReport;
    _tareReportReady = false;
    portEXIT_CRITICAL(&_mux);
    return has;
  }

  NivaAcqStats stats() {
    portENTER_CRITICAL(&_mux);
    const NivaAcqStats s = _stats;
    portEXIT_CRITICAL(&_mux);
    return s;
  }

private:
  static void taskEntry(void* self) { static_cast<NivaAcquisition*>(self)->run(); }

  void run() {
    TickType_t last = xTaskGetTickCount();
    uint8_t phase = 0;
    for (;;) {
      if (xTaskDelayUntil(&last, pdMS_TO_TICKS(kTickMs)) == pdFALSE) {
        portENTER_CRITICAL(&_mux);
        _stats.overruns++;
        portEXIT_CRITICAL(&_mux);
      }
      samplePiezo();
      if (++phase >= kFsrEvery) {
        phase = 0;
        sampleFsrAndImu();
      }
    }
  }

  void samplePiezo() {
    const float v = static_cast<float>(nivaBoardPiezoRaw());
    portENTER_CRITICAL(&_mux);
    _piezo.sample(v);
    _stats.piezoSamples++;
    portEXIT_CRITICAL(&_mux);
  }

  bool readImu(float& ax, float& ay, float& az, float& gx, float& gy, float& gz) {
    int16_t r[6];
    if (!nivaBoardImuRead(r)) return false;
    const float aLsb = nivaBoardAccelLsbPerG(), gLsb = nivaBoardGyroLsbPerDps();
    ax = r[0] / aLsb;
    ay = r[1] / aLsb;
    az = r[2] / aLsb;
    gx = r[3] / gLsb * DEG_TO_RAD;
    gy = r[4] / gLsb * DEG_TO_RAD;
    gz = r[5] / gLsb * DEG_TO_RAD;
    return true;
  }

  void sampleFsrAndImu() {
    const uint32_t burstStartUs = micros();
    // FSR burst, channels interleaved, piezo kept alive.
    uint32_t sum[4] = {0, 0, 0, 0};
    for (uint8_t s = 0; s < kOversample; ++s) {
      for (uint8_t ch = 0; ch < 4; ++ch) sum[ch] += nivaBoardFsrRaw(ch);
      if ((s & 3) == 3) samplePiezo();
    }
    float raw[4];
    for (uint8_t ch = 0; ch < 4; ++ch) raw[ch] = static_cast<float>(sum[ch]) / kOversample;

    // IMU.
    const uint32_t nowUs = micros();
    float ax = 0, ay = 0, az = 0, gx = 0, gy = 0, gz = 0;
    const bool imuOk = _imu && readImu(ax, ay, az, gx, gy, gz);
    float pitch = 0, roll = 0, accZ = 0, accelMag = _lastAccelMag;
    bool clipped = false;
    if (imuOk) {
      float dt = (_lastImuUs == 0) ? 0.01f : (nowUs - _lastImuUs) / 1000000.0f;
      _lastImuUs = nowUs;
      if (dt <= 0.0f || dt > 0.1f) dt = 0.01f;
      _ahrs.update(ax, ay, az, gx, gy, gz, dt);
      pitch = _ahrs.pitchDeg();
      roll = _ahrs.rollDeg();
      accZ = az * 9.80665f;
      accelMag = sqrtf(ax * ax + ay * ay + az * az);
      _lastAccelMag = accelMag;
      clipped = fabsf(ax) >= NIVA_CLIP_G || fabsf(ay) >= NIVA_CLIP_G || fabsf(az) >= NIVA_CLIP_G;
    }
    const uint64_t nowMs = nivaDeviceMs();
    const uint32_t nowMillis = millis();
    float rawSum = 0.0f;
    for (uint8_t i = 0; i < 4; ++i) rawSum += raw[i];

    // Signal path, unchanged from the sketch, under the lock.
    int8_t led = -1;
    bool tareStart = false;
    portENTER_CRITICAL(&_mux);
    _stats.fsrSamples++;
    if (_imu) { if (imuOk) _stats.imuReads++; else _stats.imuFailures++; }
    for (uint8_t i = 0; i < 4; ++i) _raw[i] = raw[i];
    if (imuOk) {
      _pitch = pitch;
      _roll = roll;
      _accZ = accZ;
      _imuClipped = clipped;
    }
    _quiet.push(accelMag, rawSum);
    if (_tareRequested) {
      _tareRequested = false;
      _tareCount = 0;
      _tareZeroSum = 0.0f;
      for (uint8_t i = 0; i < 4; ++i) { _tareAccum[i] = 0.0; _tareSqAccum[i] = 0.0; }
      _contacts.reset();
      _validity = NivaAcqValidity::calibrating;
      _tareGen++;
      tareStart = true;
    }
    if (_validity == NivaAcqValidity::calibrating) {
      for (uint8_t i = 0; i < 4; ++i) {
        _tareAccum[i] += raw[i];
        _tareSqAccum[i] += static_cast<double>(raw[i]) * raw[i];
      }
      ++_tareCount;
      if (_tareCount >= kTareSamples) {
        completeTareLocked();
        led = 1;
      }
    } else if (_validity == NivaAcqValidity::valid) {
      // A stored zero is intentionally never reused at boot. Only update a
      // zero after the detector observes a stable, unloaded device, never
      // while a foot is bearing weight.
      const bool safelyUnloaded = _quiet.imuQuiet() && _quiet.unloaded(_tareZeroSum);
      for (uint8_t i = 0; i < 4; ++i) {
        if (_rollingZero[i].update(raw[i], safelyUnloaded, true, nowMillis)) {
          _cal[i].zero = _rollingZero[i].zero();
        }
        _fsr[i] = _filter[i].step(_cal[i].apply(raw[i]));
      }
      // Edges at the acquisition rate (100 Hz), stamped with this sample.
      _contacts.update(_fsr, nowMs);
    }
    portEXIT_CRITICAL(&_mux);

    if (tareStart) nivaBoardStatusLed(false);
    const uint32_t burstUs = micros() - burstStartUs;
    portENTER_CRITICAL(&_mux);
    _stats.burstUsLast = burstUs;
    if (burstUs > _stats.burstUsMax) _stats.burstUsMax = burstUs;
    portEXIT_CRITICAL(&_mux);
    if (led == 1) {
      // The piezo baseline is re-read after the tare, as before.
      const float base = static_cast<float>(nivaBoardPiezoRaw());
      portENTER_CRITICAL(&_mux);
      _piezo.reset(base);
      portEXIT_CRITICAL(&_mux);
      nivaBoardStatusLed(true);
    }
  }

  // Called with the lock held.
  void completeTareLocked() {
    _tareZeroSum = 0.0f;
    float noise[4];
    for (uint8_t i = 0; i < 4; ++i) {
      const double mean = _tareAccum[i] / _tareCount;
      const double variance = _tareSqAccum[i] / _tareCount - mean * mean;
      _cal[i].zero = static_cast<float>(mean);
      _cal[i].zeroAtCal = _cal[i].zero;
      _rollingZero[i].begin(_cal[i].zero);
      _filter[i].begin(100.0f, 10.0f);
      _tareZeroSum += _cal[i].zero;
      // Unloaded noise in load-index units: the calibration's slope at zero
      // load is c1, so a raw-count sigma scales by |c1|.
      noise[i] = (variance > 0.0 ? static_cast<float>(sqrt(variance)) : 0.0f) * fabsf(_cal[i].c1);
    }
    _contacts.begin(noise);
    _validity = NivaAcqValidity::valid;
    for (uint8_t i = 0; i < 4; ++i) {
      _tareReport.zero[i] = _cal[i].zero;
      _tareReport.noise[i] = _contacts.noiseFloor(i);
    }
    _tareReportReady = true;
  }

  bool _imu = false;
  TaskHandle_t _task = nullptr;
  portMUX_TYPE _mux = portMUX_INITIALIZER_UNLOCKED;

  // Signal path (niva_signal.h).
  NivaSensorCal _cal[4];
  NivaRollingZero _rollingZero[4];
  NivaBiquadLPF _filter[4];
  NivaPeakHold _piezo;
  NivaQuietDetector _quiet;
  NivaMahony _ahrs;
  NivaContactDetector _contacts;

  NivaAcqValidity _validity = NivaAcqValidity::uncalibrated;
  bool _tareRequested = false;
  // Double precision because the noise estimate is a small difference of
  // two large sums (E[x^2] - mean^2), which float cannot resolve.
  double _tareAccum[4] = {0, 0, 0, 0};
  double _tareSqAccum[4] = {0, 0, 0, 0};
  uint16_t _tareCount = 0;
  float _tareZeroSum = 0.0f;
  NivaTareReport _tareReport = {{0, 0, 0, 0}, {0, 0, 0, 0}};
  bool _tareReportReady = false;
  uint32_t _tareGen = 0;

  float _raw[4] = {0, 0, 0, 0};
  float _fsr[4] = {0, 0, 0, 0};
  float _pitch = 0, _roll = 0, _accZ = 0, _lastAccelMag = 0;
  bool _imuClipped = false;
  uint32_t _lastImuUs = 0;
  NivaAcqStats _stats = {0, 0, 0, 0, 0, 0, 0};
};

#endif  // NIVA_ACQ_H
