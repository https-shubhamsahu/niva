// Off-target test for niva_frame.h: the telemetry frame must be byte-for-byte
// what niva_hardware.ino produced before the frame code was moved out of it
// (commit 7d98c8c). The reference below is that code, copied verbatim
// except that it takes its inputs as arguments instead of globals.
//
// Software test with synthetic values only; it says nothing about sensors.

#include <Arduino.h>
#include <stdio.h>
#include <stdlib.h>

#include "niva_frame.h"

static int failures = 0;
#define CHECK(cond)                                                    \
  do {                                                                 \
    if (!(cond)) {                                                     \
      printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);           \
      failures++;                                                      \
    }                                                                  \
  } while (0)

// ---- reference: niva_hardware.ino publishFrame() as of commit 7d98c8c ----
static bool appendf(char* buf, size_t cap, size_t& len, const char* fmt, ...)
    __attribute__((format(printf, 4, 5)));
static bool appendf(char* buf, size_t cap, size_t& len, const char* fmt, ...) {
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
static const char kChannelCode[4] = {'h', 'i', 'o', 't'};
static const uint8_t kMaxEventsPerFrame = 16;
static const size_t kFrameTailReserve = 64;

static void referenceFrame(char* frame, size_t cap, bool valid, const char* validityTextValue,
                           unsigned long long timestampMs, const float lastFsr[4], float lastPiezo,
                           float pitchDeg, float rollDeg, float accZ, bool imuClipped,
                           unsigned contactMask, NivaContactQueue& queue, unsigned long dropped) {
  size_t len = 0;
  if (valid) {
    appendf(frame, cap, len,
      "{\"deviceTimestampMs\":%llu,\"heel\":%.2f,\"inner\":%.2f,\"outer\":%.2f,\"toe\":%.2f,\"piezo\":%.2f,\"impact\":%.2f,\"pitch\":%.2f,\"roll\":%.2f,\"accZ\":%.2f,\"validity\":\"valid\",\"sampleHz\":100,\"imuClipped\":%s,\"contact\":%u,\"events\":[",
      timestampMs, lastFsr[0], lastFsr[1], lastFsr[2], lastFsr[3], lastPiezo, lastPiezo,
      pitchDeg, rollDeg, accZ, imuClipped ? "true" : "false",
      contactMask);
    uint8_t written = 0;
    NivaContactEvent e;
    while (written < kMaxEventsPerFrame && cap - len > kFrameTailReserve && queue.pop(e)) {
      char code[4] = {0, 0, 0, 0};
      const bool on = e.edge == NIVA_EDGE_ON;
      if (e.channel == NIVA_FOOT) {
        code[0] = 'F';
        code[1] = on ? '+' : '-';
        if (on) code[2] = (e.first == NIVA_TIE) ? '*' : kChannelCode[static_cast<uint8_t>(e.first)];
      } else {
        code[0] = kChannelCode[static_cast<uint8_t>(e.channel)];
        code[1] = on ? '+' : '-';
      }
      if (appendf(frame, cap, len, "%s\"%s@%llu\"", written == 0 ? "" : ",",
                  code, static_cast<unsigned long long>(e.tMs))) {
        ++written;
      }
    }
    appendf(frame, cap, len, "],\"eventsDropped\":%lu}", dropped);
  } else {
    appendf(frame, cap, len,
      "{\"deviceTimestampMs\":%llu,\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"piezo\":0,\"impact\":0,\"pitch\":0,\"roll\":0,\"accZ\":0,\"validity\":\"%s\",\"sampleHz\":100,\"imuClipped\":false,\"contact\":0,\"events\":[],\"eventsDropped\":0}",
      timestampMs, validityTextValue);
  }
}
// --------------------------------------------------------------------------

static NivaContactEvent ev(uint64_t t, int8_t ch, uint8_t edge, int8_t first) {
  NivaContactEvent e;
  e.tMs = t; e.channel = ch; e.edge = edge; e.first = first;
  return e;
}

static void readmeExample() {
  NivaContactQueue q;
  q.push(ev(12290, 0, NIVA_EDGE_ON, NIVA_TIE));
  q.push(ev(12290, NIVA_FOOT, NIVA_EDGE_ON, 0));
  q.push(ev(12330, 3, NIVA_EDGE_ON, NIVA_TIE));
  NivaFrameData d;
  d.timestampMs = 12345;
  d.valid = true;
  d.validityText = "valid";
  d.fsr[0] = 42; d.fsr[1] = 68; d.fsr[2] = 31; d.fsr[3] = 27;
  d.piezo = 176;
  d.pitch = -2.40f; d.roll = 1.30f; d.accZ = 9.72f;
  d.imuClipped = false;
  d.contact = 9;
  d.eventsDropped = 0;
  char frame[1024];
  nivaBuildFrame(frame, sizeof(frame), d, q);
  // The example in the firmware README.
  CHECK(strcmp(frame, "{\"deviceTimestampMs\":12345,\"heel\":42.00,\"inner\":68.00,\"outer\":31.00,\"toe\":27.00,\"piezo\":176.00,\"impact\":176.00,\"pitch\":-2.40,\"roll\":1.30,\"accZ\":9.72,\"validity\":\"valid\",\"sampleHz\":100,\"imuClipped\":false,\"contact\":9,\"events\":[\"h+@12290\",\"F+h@12290\",\"t+@12330\"],\"eventsDropped\":0}") == 0);
}

static float rnd(float lo, float hi) { return lo + (hi - lo) * (float)rand() / (float)RAND_MAX; }

static void matchesReferenceOnRandomInput() {
  srand(12345);
  for (int iter = 0; iter < 2000; ++iter) {
    NivaContactQueue q1, q2;
    const int nev = rand() % 40;  // above 16 per frame and above the queue's 32
    for (int k = 0; k < nev; ++k) {
      const int8_t ch = (int8_t)(rand() % 5) - 1;
      const uint8_t edge = (uint8_t)(rand() % 2);
      const int8_t first = (int8_t)(rand() % 5) - 1;
      const NivaContactEvent e = ev((uint64_t)rand() * 1000ULL, ch, edge, first);
      q1.push(e);
      q2.push(e);
    }
    NivaFrameData d;
    d.timestampMs = (unsigned long long)rand() * 977ULL;
    d.valid = (rand() % 4) != 0;
    static const char* texts[3] = {"valid", "calibrating", "uncalibrated"};
    d.validityText = texts[rand() % 3];
    for (int i = 0; i < 4; ++i) d.fsr[i] = rnd(-500, 4000);
    d.piezo = rnd(0, 4095);
    d.pitch = rnd(-90, 90); d.roll = rnd(-180, 180); d.accZ = rnd(-160, 160);
    d.imuClipped = rand() % 2;
    d.contact = (uint8_t)(rand() % 16);
    d.eventsDropped = (unsigned long)(rand() % 100);
    char a[1024], b[1024];
    nivaBuildFrame(a, sizeof(a), d, q1);
    referenceFrame(b, sizeof(b), d.valid, d.validityText, d.timestampMs, d.fsr, d.piezo, d.pitch,
                   d.roll, d.accZ, d.imuClipped, d.contact, q2, d.eventsDropped);
    if (strcmp(a, b) != 0) {
      printf("mismatch:\n  new %s\n  ref %s\n", a, b);
      failures++;
      return;
    }
    CHECK(q1.size() == q2.size());  // same number of events left for the next frame
  }
}

int main() {
  readmeExample();
  matchesReferenceOnRandomInput();
  if (failures == 0) printf("frame_test: all checks passed\n");
  return failures == 0 ? 0 : 1;
}
