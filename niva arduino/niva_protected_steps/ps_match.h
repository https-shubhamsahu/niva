// ps_match.h - stride classification on the ankle hub (P / U / X).
// Pure C++; host-tested. Implements "Classification (on the hub)" of
// PROTOCOL.md:
//
//  - P: an insole contact (mapped to hub time) lies within t +- match_ms.
//    Each contact matches at most one stride, the nearest. If two strides
//    are equally near, the earlier one wins. A stride takes the nearest of
//    the contacts that are nearest to it.
//  - U: insole paired, its last heartbeat (before the stride) reported
//    battery >= 10% and VALID, the hub IMU is VALID, and no contact matched.
//  - X: no insole paired; or its last heartbeat reported battery < 10%, or
//    DEGRADED / INVALID; or no heartbeat has been received since pairing;
//    or the hub's own IMU validity is not VALID. X takes precedence over P,
//    because the validity gate says such steps are "unknown", never
//    protected or unprotected. A contact near an X stride is still consumed
//    by it, so it cannot match a different stride.
//
// A stride is held until settle_ms after its time t. A contact that arrives
// after the stride nearest to it was classified, or that no stride could
// still match, is reported as a raw contact (late = true) and changes
// nothing. A contact that expires unmatched is reported as raw (late =
// false): the hub saw no stride for it.
//
// Battery: on hardware without battery sensing the heartbeat reports null.
// With nullBatteryOk the battery condition is then skipped (otherwise no
// stride could ever be U on the current prototype). This is a deviation
// from the letter of PROTOCOL.md, recorded in the firmware README.

#ifndef PS_MATCH_H
#define PS_MATCH_H

#include "ps_types.h"

struct PsMatchParams {
  uint32_t matchMs = PS_DEFAULT_MATCH_MS;
  uint32_t settleMs = PS_DEFAULT_SETTLE_MS;
  uint8_t battLowPct = PS_BATT_LOW_PCT;
  bool nullBatteryOk = true;
};

// What the hub knows about its insole at a given moment.
struct PsInsoleView {
  bool paired = false;
  bool heard = false;          // a heartbeat has been received since pairing
  int8_t batt = PS_BATT_NONE;  // last heartbeat
  PsVal val = PsVal::INVALID;  // last heartbeat
};

struct PsStrideResult {
  uint32_t tMs;
  char cls;          // 'P', 'U' or 'X'
  bool hasDt;
  int32_t dt;        // contact - stride, ms (P only)
  int8_t home;
  uint16_t peakDps;
};

struct PsContactResult {
  uint32_t tMs;      // hub time
  bool late;
  PsVal val;
};

struct PsMatchEvent {
  bool isStride;
  PsStrideResult s;
  PsContactResult c;
};

struct PsMatchOut {
  static const uint8_t kCapacity = 16;
  PsMatchEvent ev[kCapacity];
  uint8_t n = 0;
  bool full() const { return n >= kCapacity; }
  void clear() { n = 0; }
};

class PsMatcher {
public:
  // Design choice: room for settle_ms (max 30 s) of strides 400 ms apart.
  static const uint8_t kMaxStrides = 80;
  static const uint8_t kMaxContacts = 80;
  static const uint8_t kRecent = 8;

  void begin(const PsMatchParams& p) { _p = p; reset(); }
  void setParams(const PsMatchParams& p) { _p = p; }
  const PsMatchParams& params() const { return _p; }
  void reset() { _ns = 0; _nc = 0; _nr = 0; }

  static bool unknownAt(const PsInsoleView& v, bool hubImuValid, const PsMatchParams& p) {
    if (!hubImuValid || !v.paired || !v.heard) return true;
    if (v.val != PsVal::VALID) return true;
    if (v.batt == PS_BATT_NONE) return !p.nullBatteryOk;
    return v.batt < (int8_t)p.battLowPct;
  }

  uint8_t pendingStrides() const { return _ns; }
  uint8_t pendingContacts() const { return _nc; }

  // Adds a detected stride. `unknown` is unknownAt() evaluated at the
  // stride's time. If the queue is full the oldest stride is classified
  // early, which `out` reports like any other.
  void addStride(uint32_t tMs, uint16_t peakDps, int8_t home, bool unknown, PsMatchOut& out) {
    if (_ns >= kMaxStrides) classifyOldest(out);
    if (_ns >= kMaxStrides) return;  // out was full; drop (cannot happen with a drained out)
    Stride& s = _s[_ns++];
    s.tMs = tMs;
    s.peakDps = peakDps;
    s.home = home;
    s.unknown = unknown;
  }

  // Adds an insole contact already mapped to hub time.
  void addContact(uint32_t tMs, PsVal val, uint32_t nowMs, PsMatchOut& out) {
    // Nearest classified and nearest pending stride within the window.
    int32_t dr = 0, dp = 0;
    const bool r = nearestRecent(tMs, dr);
    const bool p = nearestPending(tMs, dp);
    const bool tooOld = (int32_t)(nowMs - tMs) >= (int32_t)(_p.settleMs + _p.matchMs);
    if ((r && (!p || absI(dr) <= absI(dp))) || (!p && tooOld)) {
      emitContact(tMs, true, val, out);
      return;
    }
    if (_nc >= kMaxContacts) {  // full: the oldest goes out unmatched
      emitContact(_c[0].tMs, false, _c[0].val, out);
      removeContact(0);
    }
    // Insert sorted by time (retries can arrive out of order).
    uint8_t i = _nc;
    while (i > 0 && (int32_t)(_c[i - 1].tMs - tMs) > 0) {
      _c[i] = _c[i - 1];
      --i;
    }
    _c[i].tMs = tMs;
    _c[i].val = val;
    _nc++;
  }

  // Classifies every stride that has settled and expires old contacts.
  void poll(uint32_t nowMs, PsMatchOut& out) {
    while (_ns > 0 && !out.full() &&
           (int32_t)(nowMs - _s[0].tMs) >= (int32_t)_p.settleMs) {
      classifyOldest(out);
    }
    while (_nc > 0 && !out.full() &&
           (int32_t)(nowMs - _c[0].tMs) >= (int32_t)(_p.settleMs + _p.matchMs)) {
      int32_t d;
      if (nearestPending(_c[0].tMs, d)) break;  // a pending stride may still take it
      emitContact(_c[0].tMs, false, _c[0].val, out);
      removeContact(0);
    }
  }

private:
  struct Stride { uint32_t tMs; uint16_t peakDps; int8_t home; bool unknown; };
  struct Contact { uint32_t tMs; PsVal val; };

  static int32_t absI(int32_t v) { return v < 0 ? -v : v; }

  bool nearestRecent(uint32_t t, int32_t& d) const {
    bool found = false;
    for (uint8_t i = 0; i < _nr; ++i) {
      const int32_t x = (int32_t)(t - _recent[i]);
      if (absI(x) <= (int32_t)_p.matchMs && (!found || absI(x) < absI(d))) { d = x; found = true; }
    }
    return found;
  }

  bool nearestPending(uint32_t t, int32_t& d) const {
    bool found = false;
    for (uint8_t i = 0; i < _ns; ++i) {
      const int32_t x = (int32_t)(t - _s[i].tMs);
      if (absI(x) <= (int32_t)_p.matchMs && (!found || absI(x) < absI(d))) { d = x; found = true; }
    }
    return found;
  }

  void classifyOldest(PsMatchOut& out) {
    if (_ns == 0 || out.full()) return;
    const Stride s = _s[0];
    const bool hasPrev = _nr > 0;
    const uint32_t prevT = hasPrev ? _recent[_nr - 1] : 0;
    const bool hasNext = _ns > 1;
    const uint32_t nextT = hasNext ? _s[1].tMs : 0;

    int best = -1;
    int32_t bestD = 0;
    for (uint8_t i = 0; i < _nc; ++i) {
      const int32_t d = (int32_t)(_c[i].tMs - s.tMs);
      if (absI(d) > (int32_t)_p.matchMs) continue;
      // Nearer to (or as near as) the earlier stride: it belonged to that one.
      if (hasPrev && absI((int32_t)(_c[i].tMs - prevT)) <= absI(d)) continue;
      // Strictly nearer to the next stride: leave it for that one.
      if (hasNext && absI((int32_t)(_c[i].tMs - nextT)) < absI(d)) continue;
      if (best < 0 || absI(d) < absI(bestD)) { best = i; bestD = d; }
    }

    PsMatchEvent& e = out.ev[out.n++];
    e.isStride = true;
    e.s.tMs = s.tMs;
    e.s.home = s.home;
    e.s.peakDps = s.peakDps;
    e.s.hasDt = false;
    e.s.dt = 0;
    if (s.unknown) {
      e.s.cls = 'X';
    } else if (best >= 0) {
      e.s.cls = 'P';
      e.s.hasDt = true;
      e.s.dt = bestD;
    } else {
      e.s.cls = 'U';
    }
    if (best >= 0) removeContact((uint8_t)best);

    for (uint8_t i = 1; i < _ns; ++i) _s[i - 1] = _s[i];
    _ns--;
    if (_nr >= kRecent) {
      for (uint8_t i = 1; i < _nr; ++i) _recent[i - 1] = _recent[i];
      _nr--;
    }
    _recent[_nr++] = s.tMs;
  }

  void emitContact(uint32_t tMs, bool late, PsVal val, PsMatchOut& out) {
    if (out.full()) return;  // callers drain `out` after every call
    PsMatchEvent& e = out.ev[out.n++];
    e.isStride = false;
    e.c.tMs = tMs;
    e.c.late = late;
    e.c.val = val;
  }

  void removeContact(uint8_t i) {
    for (uint8_t k = (uint8_t)(i + 1); k < _nc; ++k) _c[k - 1] = _c[k];
    _nc--;
  }

  PsMatchParams _p;
  Stride _s[kMaxStrides];
  Contact _c[kMaxContacts];
  uint32_t _recent[kRecent] = {0};
  uint8_t _ns = 0, _nc = 0, _nr = 0;
};

#endif  // PS_MATCH_H
