// niva_frame.h - the insole telemetry frame (WebSocket, USB serial, BLE).
//
// Moved out of niva_hardware.ino on 3 November 2026 for Protected Steps, so
// that the Protected Steps insole role in lab mode sends byte-for-byte the
// same frame and the format can be unit-tested on a PC
// (tests/frame_test.cpp). The fields and their order are unchanged.
//
// This file is shared: niva_hardware/ holds the original and
// niva_protected_steps/ a copy. tests/run_host_tests.sh fails if they differ.

#ifndef NIVA_FRAME_H
#define NIVA_FRAME_H

#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "niva_signal.h"

struct NivaFrameData {
  unsigned long long timestampMs;
  bool valid;
  const char* validityText;  // used when !valid
  float fsr[4];
  float piezo;               // also sent as "impact"
  float pitch, roll, accZ;
  bool imuClipped;
  uint8_t contact;
  unsigned long eventsDropped;
};

// Appends printf-style text at buf[len]. Returns false and leaves len
// unchanged if the text would not fit.
static inline bool nivaAppendf(char* buf, size_t cap, size_t& len, const char* fmt, ...)
    __attribute__((format(printf, 4, 5)));
static inline bool nivaAppendf(char* buf, size_t cap, size_t& len, const char* fmt, ...) {
  if (len >= cap) return false;
  va_list args;
  va_start(args, fmt);
  const int n = vsnprintf(buf + len, cap - len, fmt, args);
  va_end(args);
  if (n < 0 || static_cast<size_t>(n) >= cap - len) {
    buf[len] = '\0';
    return false;
  }
  len += static_cast<size_t>(n);
  return true;
}

// Contact events ride inside the telemetry frame rather than as a separate
// message type, so clients that predate them simply ignore three new fields.
// Each entry of "events" is "<code>@<deviceMs>":
//   h+ h- i+ i- o+ o- t+ t-  one sensor (heel, inner, outer, toe) loads or unloads
//   F+x                      the foot loads; x is the sensor that loaded first,
//                            or * when two sensors crossed on the same sample
//   F-                       the last loaded sensor unloads
static const uint8_t kNivaMaxEventsPerFrame = 16;   // the rest wait for the next frame
static const size_t kNivaFrameTailReserve = 64;     // room for the closing fields

static inline void nivaEventCode(const NivaContactEvent& e, char code[4]) {
  static const char kChannelCode[4] = {'h', 'i', 'o', 't'};
  code[0] = code[1] = code[2] = code[3] = 0;
  const bool on = e.edge == NIVA_EDGE_ON;
  if (e.channel == NIVA_FOOT) {
    code[0] = 'F';
    code[1] = on ? '+' : '-';
    if (on) code[2] = (e.first == NIVA_TIE) ? '*' : kChannelCode[static_cast<uint8_t>(e.first)];
  } else {
    code[0] = kChannelCode[static_cast<uint8_t>(e.channel)];
    code[1] = on ? '+' : '-';
  }
}

// Builds one frame. Valid frames take up to 16 events from `events`.
// Returns the length written.
static inline size_t nivaBuildFrame(char* frame, size_t cap, const NivaFrameData& d,
                                    NivaContactQueue& events) {
  size_t len = 0;
  if (d.valid) {
    nivaAppendf(frame, cap, len,
      "{\"deviceTimestampMs\":%llu,\"heel\":%.2f,\"inner\":%.2f,\"outer\":%.2f,\"toe\":%.2f,\"piezo\":%.2f,\"impact\":%.2f,\"pitch\":%.2f,\"roll\":%.2f,\"accZ\":%.2f,\"validity\":\"valid\",\"sampleHz\":100,\"imuClipped\":%s,\"contact\":%u,\"events\":[",
      d.timestampMs, static_cast<double>(d.fsr[0]), static_cast<double>(d.fsr[1]),
      static_cast<double>(d.fsr[2]), static_cast<double>(d.fsr[3]),
      static_cast<double>(d.piezo), static_cast<double>(d.piezo),
      static_cast<double>(d.pitch), static_cast<double>(d.roll), static_cast<double>(d.accZ),
      d.imuClipped ? "true" : "false", static_cast<unsigned>(d.contact));

    uint8_t written = 0;
    NivaContactEvent e;
    while (written < kNivaMaxEventsPerFrame && cap - len > kNivaFrameTailReserve && events.pop(e)) {
      char code[4];
      nivaEventCode(e, code);
      if (nivaAppendf(frame, cap, len, "%s\"%s@%llu\"", written == 0 ? "" : ",",
                      code, static_cast<unsigned long long>(e.tMs))) {
        ++written;
      }
    }
    nivaAppendf(frame, cap, len, "],\"eventsDropped\":%lu}", d.eventsDropped);
  } else {
    nivaAppendf(frame, cap, len,
      "{\"deviceTimestampMs\":%llu,\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"piezo\":0,\"impact\":0,\"pitch\":0,\"roll\":0,\"accZ\":0,\"validity\":\"%s\",\"sampleHz\":100,\"imuClipped\":false,\"contact\":0,\"events\":[],\"eventsDropped\":0}",
      d.timestampMs, d.validityText);
  }
  return len;
}

#endif  // NIVA_FRAME_H
