// Off-target tests for NivaContactDetector (niva_signal.h, section 9).
//
// Build and run from the repository root (one line):
//   g++ -std=gnu++17 -Wall -Wextra -Werror -I"startup/niva arduino/tests/stub"
//       -I"startup/niva arduino/niva_hardware" "startup/niva arduino/tests/contact_detector_test.cpp"
//       -o contact_detector_test && ./contact_detector_test
//
// The signals here are synthetic shapes chosen to exercise the logic. They
// say nothing about how well the detector matches a real foot; that is what
// checks F1-F4 measure.

#include <Arduino.h>
#include <stdio.h>

#include "niva_signal.h"

static int failures = 0;

#define CHECK(cond)                                                    \
  do {                                                                 \
    if (!(cond)) {                                                     \
      printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);           \
      failures++;                                                      \
    }                                                                  \
  } while (0)

static const uint64_t kStartMs = 1000;
static const uint64_t kPeriodMs = 10;   // 100 Hz

static void begin(NivaContactDetector &d) {
  const float sigma[4] = {2.0f, 2.0f, 2.0f, 2.0f};   // floor = max(8 x 2, 40) = 40
  d.begin(sigma);
}

static void feed(NivaContactDetector &d, int k, float h, float i, float o, float t) {
  const float v[4] = {h, i, o, t};
  d.update(v, kStartMs + (uint64_t)k * kPeriodMs);
}

static int drain(NivaContactDetector &d, NivaContactEvent *out, int max) {
  int n = 0;
  NivaContactEvent e;
  while (n < max && d.queue().pop(e)) out[n++] = e;
  return n;
}

static void noiseMakesNoEvents() {
  NivaContactDetector d;
  begin(d);
  for (int k = 0; k < 300; ++k) {
    const float n = (k % 2) ? 10.0f : -10.0f;
    feed(d, k, n, n, n, n);
  }
  CHECK(d.queue().size() == 0);
  CHECK(d.mask() == 0);
}

static void heelFirstStep() {
  NivaContactDetector d;
  begin(d);
  for (int k = 0; k < 60; ++k) {
    const float heel = (k >= 10 && k < 30) ? 500.0f : 0.0f;
    const float toe  = (k >= 15 && k < 40) ? 500.0f : 0.0f;
    feed(d, k, heel, 0.0f, 0.0f, toe);
    if (k == 20) CHECK(d.mask() == 0x09);   // heel and toe in contact
  }
  NivaContactEvent ev[16];
  const int n = drain(d, ev, 16);
  CHECK(n == 6);
  if (n != 6) return;
  // Stamped at the first crossing sample, not at confirmation.
  CHECK(ev[0].channel == 0 && ev[0].edge == NIVA_EDGE_ON && ev[0].tMs == 1100);
  CHECK(ev[1].channel == NIVA_FOOT && ev[1].edge == NIVA_EDGE_ON && ev[1].tMs == 1100);
  CHECK(ev[1].first == 0);                                 // heel loaded first
  CHECK(ev[2].channel == 3 && ev[2].edge == NIVA_EDGE_ON && ev[2].tMs == 1150);
  CHECK(ev[3].channel == 0 && ev[3].edge == NIVA_EDGE_OFF && ev[3].tMs == 1300);
  CHECK(ev[4].channel == 3 && ev[4].edge == NIVA_EDGE_OFF && ev[4].tMs == 1400);
  CHECK(ev[5].channel == NIVA_FOOT && ev[5].edge == NIVA_EDGE_OFF && ev[5].tMs == 1400);
  CHECK(d.level(0) == 500.0f);                             // learned from the contact
}

static void sameSampleIsATie() {
  NivaContactDetector d;
  begin(d);
  for (int k = 0; k < 20; ++k) {
    const float v = (k >= 5) ? 500.0f : 0.0f;
    feed(d, k, v, 0.0f, 0.0f, v);
  }
  NivaContactEvent ev[8];
  const int n = drain(d, ev, 8);
  CHECK(n == 3);   // h+, t+, F+
  if (n != 3) return;
  CHECK(ev[2].channel == NIVA_FOOT && ev[2].edge == NIVA_EDGE_ON);
  CHECK(ev[2].first == NIVA_TIE);
}

static void shortSpikeIsDebounced() {
  NivaContactDetector d;
  begin(d);
  for (int k = 0; k < 20; ++k) {
    const float heel = (k == 10 || k == 11) ? 500.0f : 0.0f;   // two samples only
    feed(d, k, heel, 0.0f, 0.0f, 0.0f);
  }
  CHECK(d.queue().size() == 0);
}

static void thresholdFollowsLearnedLevel() {
  NivaContactDetector d;
  begin(d);
  int k = 0;
  for (; k < 20; ++k) feed(d, k, 1000.0f, 0.0f, 0.0f, 0.0f);   // learn level 1000
  for (; k < 30; ++k) feed(d, k, 0.0f, 0.0f, 0.0f, 0.0f);
  NivaContactEvent ev[8];
  drain(d, ev, 8);
  // On threshold is now max(40, 0.15 x 1000) = 150.
  for (; k < 40; ++k) feed(d, k, 100.0f, 0.0f, 0.0f, 0.0f);
  CHECK(d.queue().size() == 0);
  for (; k < 50; ++k) feed(d, k, 200.0f, 0.0f, 0.0f, 0.0f);
  CHECK(d.mask() == 0x01);
}

// A sensor twice as sensitive must give the same edge times once each
// channel has learned its own level, provided neither saturates.
static void gainDoesNotMoveEdges() {
  NivaContactDetector a, b;
  begin(a);
  begin(b);
  int k = 0;
  for (int cycle = 0; cycle < 2; ++cycle) {
    for (int s = 0; s < 140; ++s, ++k) {
      float shape;
      if (s < 50)       shape = 20.0f * (float)s;              // rise to 1000
      else if (s < 70)  shape = 1000.0f;                       // hold
      else if (s < 120) shape = 1000.0f - 20.0f * (float)(s - 70);
      else              shape = 0.0f;
      feed(a, k, shape, 0.0f, 0.0f, 0.0f);
      feed(b, k, 2.0f * shape, 0.0f, 0.0f, 0.0f);
    }
    if (cycle == 0) {
      NivaContactEvent tmp[8];
      drain(a, tmp, 8);
      drain(b, tmp, 8);
    }
  }
  NivaContactEvent ea[8], eb[8];
  const int na = drain(a, ea, 8);
  const int nb = drain(b, eb, 8);
  CHECK(na == nb && na == 4);   // h+, F+, h-, F-
  for (int i = 0; i < na && i < nb; ++i) CHECK(ea[i].tMs == eb[i].tMs);
}

static void fullQueueCountsDrops() {
  NivaContactQueue q;
  q.clear();
  NivaContactEvent e;
  e.tMs = 0; e.channel = 0; e.edge = NIVA_EDGE_ON; e.first = NIVA_TIE;
  for (int i = 0; i < 40; ++i) q.push(e);
  CHECK(q.size() == NivaContactQueue::kCapacity);
  CHECK(q.dropped() == 40 - NivaContactQueue::kCapacity);
}

int main() {
  noiseMakesNoEvents();
  heelFirstStep();
  sameSampleIsATie();
  shortSpikeIsDebounced();
  thresholdFollowsLearnedLevel();
  gainDoesNotMoveEdges();
  fullQueueCountsDrops();
  if (failures == 0) printf("contact detector: all checks passed\n");
  return failures == 0 ? 0 : 1;
}
