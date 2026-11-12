// ps_offset.h - insole-to-hub clock mapping. Pure C++; host-tested.
//
// PROTOCOL.md: "The hub maps insole time to hub time from the receive time
// of each packet, using the minimum observed offset over a sliding window."
//
// Every ESP-NOW packet carries the insole's clock at the moment it was
// handed to the radio (txMs; retries are re-stamped). The hub notes its own
// clock when the packet arrives (rxMs). rxMs - txMs = true offset + radio
// and queueing delay, and the delay is never negative, so the smallest
// value in a window is the best estimate of the offset.
//
// The window is bounded in time so that drift between the two crystals is
// tracked, and in size so that memory is fixed. Both bounds are design
// choices; the drift between our two boards is to be measured.

#ifndef PS_OFFSET_H
#define PS_OFFSET_H

#include <stdint.h>

class PsClockOffset {
public:
  static const uint8_t kCapacity = 32;              // design choice
  static const uint32_t kDefaultWindowMs = 600000;  // design choice: 10 min

  void begin(uint32_t windowMs = kDefaultWindowMs) {
    _windowMs = windowMs;
    reset();
  }

  void reset() { _n = 0; _head = 0; }

  void addSample(uint32_t hubRxMs, uint32_t insoleTxMs) {
    // Drop samples older than the window, measured from this receive time.
    while (_n > 0 && (uint32_t)(hubRxMs - _rx[_head]) > _windowMs) {
      _head = (uint8_t)((_head + 1) % kCapacity);
      _n--;
    }
    if (_n == kCapacity) {  // full: drop the oldest
      _head = (uint8_t)((_head + 1) % kCapacity);
      _n--;
    }
    const uint8_t i = (uint8_t)((_head + _n) % kCapacity);
    _rx[i] = hubRxMs;
    _off[i] = (int64_t)hubRxMs - (int64_t)insoleTxMs;
    _n++;
  }

  bool valid() const { return _n > 0; }
  uint8_t samples() const { return _n; }

  int64_t offset() const {
    int64_t best = 0;
    for (uint8_t k = 0; k < _n; ++k) {
      const int64_t o = _off[(_head + k) % kCapacity];
      if (k == 0 || o < best) best = o;
    }
    return best;
  }

  // Maps an insole time to hub time. Returns false if there is no estimate
  // or the result would lie before the hub booted.
  bool toHub(uint32_t insoleMs, uint32_t& hubMs) const {
    if (!valid()) return false;
    const int64_t h = (int64_t)insoleMs + offset();
    if (h < 0 || h > 0xFFFFFFFFLL) return false;
    hubMs = (uint32_t)h;
    return true;
  }

private:
  uint32_t _windowMs = kDefaultWindowMs;
  uint32_t _rx[kCapacity] = {0};
  int64_t _off[kCapacity] = {0};
  uint8_t _n = 0, _head = 0;
};

#endif  // PS_OFFSET_H
