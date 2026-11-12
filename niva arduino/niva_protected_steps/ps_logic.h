// ps_logic.h - small pieces of pure logic: home flag, hub IMU validity,
// the insole's outbox (retry until acknowledged) and the hub's per-insole
// receive state (dedup, lost, battery_low). Pure C++; host-tested.

#ifndef PS_LOGIC_H
#define PS_LOGIC_H

#include "ps_offset.h"
#include "ps_packet.h"
#include "ps_types.h"

// ---------------------------------------------------------------------------
// Home flag (PROTOCOL.md): 1 if the configured SSID or BSSID was seen at
// RSSI > -85 dBm in the latest scan, 0 if not, null if not configured.
// ---------------------------------------------------------------------------
struct PsHomeConfig {
  char ssid[33] = {0};
  uint8_t bssid[6] = {0};
  bool hasBssid() const {
    for (int i = 0; i < 6; ++i) if (bssid[i]) return true;
    return false;
  }
  bool configured() const { return ssid[0] != '\0' || hasBssid(); }
};

struct PsScanEntry {
  char ssid[33];
  uint8_t bssid[6];
  int32_t rssi;
};

inline int8_t psHomeFlag(const PsHomeConfig& cfg, const PsScanEntry* e, int n) {
  if (!cfg.configured()) return PS_HOME_NULL;
  if (n < 0) return PS_HOME_NULL;  // the scan failed: unknown, not "away"
  for (int i = 0; i < n; ++i) {
    if (e[i].rssi <= PS_HOME_RSSI_MIN_DBM) continue;
    if (cfg.ssid[0] != '\0' && strcmp(cfg.ssid, e[i].ssid) == 0) return 1;
    if (cfg.hasBssid() && memcmp(cfg.bssid, e[i].bssid, 6) == 0) return 1;
  }
  return 0;
}

// ---------------------------------------------------------------------------
// Hub IMU validity. Fed once per 10 ms IMU slot. Design choices:
//  INVALID  IMU absent, or >= kFailInvalid consecutive failed reads, or
//           all six raw values identical for >= kFrozenInvalid reads
//           (a live MEMS sensor always shows some noise).
//  DEGRADED any failed read, any saturated sample, or fewer than
//           kMinGoodPerSec good reads, within the last second.
//  VALID    otherwise, after kRecoverMs of clean reads.
// ---------------------------------------------------------------------------
class PsImuValidity {
public:
  static const uint8_t kFailInvalid = 10;      // 100 ms at 100 Hz
  static const uint16_t kFrozenInvalid = 100;  // 1 s
  static const uint16_t kMinGoodPerSec = 90;   // of 100 expected
  static const uint32_t kRecoverMs = 2000;

  void begin(bool present, uint32_t nowMs) {
    _present = present;
    _state = present ? PsVal::DEGRADED : PsVal::INVALID;  // VALID only after a clean second
    _consecFail = 0;
    _frozen = 0;
    _winStart = nowMs;
    _winGood = 0;
    _winBad = false;
    _cleanSince = nowMs;
    _haveLast = false;
  }

  // Returns true on the update where the state became INVALID.
  bool update(bool readOk, bool saturated, const int16_t raw[6], uint32_t nowMs) {
    const PsVal before = _state;
    if (!_present) { _state = PsVal::INVALID; return false; }
    if (!readOk) {
      if (_consecFail < 255) _consecFail++;
      _winBad = true;
      _cleanSince = nowMs;
    } else {
      _consecFail = 0;
      bool same = _haveLast;
      for (int i = 0; i < 6 && same; ++i) same = raw[i] == _last[i];
      for (int i = 0; i < 6; ++i) _last[i] = raw[i];
      _haveLast = true;
      _frozen = same ? (uint16_t)(_frozen < 65535 ? _frozen + 1 : _frozen) : 0;
      if (saturated) { _winBad = true; _cleanSince = nowMs; }
      _winGood++;
    }
    if ((uint32_t)(nowMs - _winStart) >= 1000) {
      _lastWinBad = _winBad || _winGood < kMinGoodPerSec;
      if (_lastWinBad) _cleanSince = nowMs;
      _winStart = nowMs;
      _winGood = 0;
      _winBad = false;
    }
    if (_consecFail >= kFailInvalid || _frozen >= kFrozenInvalid) {
      _state = PsVal::INVALID;
    } else if (_winBad || _lastWinBad || (uint32_t)(nowMs - _cleanSince) < kRecoverMs) {
      _state = PsVal::DEGRADED;
    } else {
      _state = PsVal::VALID;
    }
    return before != PsVal::INVALID && _state == PsVal::INVALID;
  }

  PsVal state() const { return _state; }

private:
  bool _present = false;
  PsVal _state = PsVal::INVALID;
  uint8_t _consecFail = 0;
  uint16_t _frozen = 0;
  int16_t _last[6] = {0};
  bool _haveLast = false;
  uint32_t _winStart = 0, _cleanSince = 0;
  uint16_t _winGood = 0;
  bool _winBad = false, _lastWinBad = true;
};

// ---------------------------------------------------------------------------
// Insole outbox: contacts wait here until a send carrying them is
// acknowledged (ESP-NOW MAC ack). One packet in flight at a time; retries
// back off. Design choices: retry 20 ms doubling to 1 s; capacity 64.
// ---------------------------------------------------------------------------
class PsOutbox {
public:
  static const uint8_t kCapacity = 64;
  static const uint32_t kRetryMinMs = 20;
  static const uint32_t kRetryMaxMs = 1000;

  void reset() {
    _n = 0;
    _head = 0;
    _inFlight = 0;
    _busy = false;
    _retryMs = kRetryMinMs;
    _nextTryMs = 0;
    _failStreak = 0;
  }

  // Queues a contact; when full the oldest is dropped and counted.
  void push(uint32_t seq, uint32_t ms) {
    if (_n >= kCapacity) {
      _head = (uint8_t)((_head + 1) % kCapacity);
      _n--;
      _dropped++;
      if (_inFlight > 0) _inFlight--;
    }
    _q[(_head + _n) % kCapacity] = {seq, ms};
    _n++;
  }

  uint8_t size() const { return _n; }
  uint32_t dropped() const { return _dropped; }
  bool busy() const { return _busy; }
  uint8_t failStreak() const { return _failStreak; }

  // True if a contacts packet should be sent now; fills `p` (contacts only).
  bool due(uint32_t nowMs, PsPacket& p) {
    if (_busy || _n == 0 || (int32_t)(nowMs - _nextTryMs) < 0) return false;
    p.type = PsPktType::CONTACTS;
    p.n = _n < PS_PKT_MAX_CONTACTS ? _n : PS_PKT_MAX_CONTACTS;
    for (uint8_t i = 0; i < p.n; ++i) {
      const PsPktContact& c = _q[(_head + i) % kCapacity];
      p.c[i] = c;
    }
    _inFlight = p.n;
    _busy = true;
    return true;
  }

  // Result of the send started by due(). Returns true on success.
  bool sent(bool acked, uint32_t nowMs) {
    if (!_busy) return false;
    _busy = false;
    if (acked) {
      const uint8_t k = _inFlight <= _n ? _inFlight : _n;
      _head = (uint8_t)((_head + k) % kCapacity);
      _n = (uint8_t)(_n - k);
      _retryMs = kRetryMinMs;
      _nextTryMs = nowMs;
      _failStreak = 0;
    } else {
      _nextTryMs = nowMs + _retryMs;
      _retryMs = _retryMs * 2 > kRetryMaxMs ? kRetryMaxMs : _retryMs * 2;
      if (_failStreak < 255) _failStreak++;
    }
    _inFlight = 0;
    return acked;
  }

  // A send that could not even be queued (esp_now_send error).
  void abort(uint32_t nowMs) { sent(false, nowMs); }

private:
  PsPktContact _q[kCapacity];
  uint8_t _n = 0, _head = 0, _inFlight = 0;
  bool _busy = false;
  uint32_t _retryMs = kRetryMinMs, _nextTryMs = 0, _dropped = 0;
  uint8_t _failStreak = 0;
};

// ---------------------------------------------------------------------------
// Hub side: what has been heard from the paired insole.
// ---------------------------------------------------------------------------
struct PsInsoleRx {
  bool seen = false;          // any packet this boot
  uint32_t lastRxMs = 0;
  uint32_t boot = 0;          // insole boot id of the last packet
  bool haveBoot = false;
  uint32_t lastContactSeq = 0;
  bool haveContactSeq = false;
  bool heard = false;         // heartbeat received (persisted across hub reboots)
  int8_t batt = PS_BATT_NONE;
  PsVal val = PsVal::INVALID;
  bool lost = false;
  PsClockOffset clock;

  void resetLink() {
    seen = false;
    haveBoot = false;
    haveContactSeq = false;
    lost = false;
    clock.reset();
  }

  // Call for every packet from the paired insole. Returns true if the
  // insole rebooted (new boot id), which resets dedup and the clock.
  bool onPacket(const PsPacket& p, uint32_t rxMs) {
    bool rebooted = false;
    if (!haveBoot || p.boot != boot) {
      rebooted = haveBoot;
      boot = p.boot;
      haveBoot = true;
      haveContactSeq = false;
      clock.reset();
    }
    clock.addSample(rxMs, p.txMs);
    seen = true;
    lastRxMs = rxMs;
    lost = false;
    return rebooted;
  }

  // True if this contact seq is new (not a retry of one already taken).
  bool acceptContact(uint32_t seq) {
    if (haveContactSeq && (int32_t)(seq - lastContactSeq) <= 0) return false;
    lastContactSeq = seq;
    haveContactSeq = true;
    return true;
  }

  // True once, when the link goes quiet for PS_INSOLE_LOST_MS.
  bool checkLost(uint32_t nowMs, uint32_t sinceMs) {
    const uint32_t ref = seen ? lastRxMs : sinceMs;
    // Signed: `ref` can be a little after `nowMs` when the caller read the
    // clock before a packet or a pairing updated it.
    if (!lost && (int32_t)(nowMs - ref) >= (int32_t)PS_INSOLE_LOST_MS) {
      lost = true;
      return true;
    }
    return false;
  }
};

#endif  // PS_LOGIC_H
