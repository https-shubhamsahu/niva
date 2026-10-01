// Minimal stand-in for the Arduino core so niva_signal.h can be compiled and
// tested on a PC. Only what the header touches is declared here.
#ifndef NIVA_TEST_ARDUINO_STUB_H
#define NIVA_TEST_ARDUINO_STUB_H

#include <stdint.h>
#include <stddef.h>
#include <math.h>

class TwoWire {
public:
  void beginTransmission(uint8_t) {}
  size_t write(uint8_t) { return 1; }
  uint8_t endTransmission(bool = true) { return 0; }
};

#endif
