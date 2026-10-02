// Off-target tests for SakshiBeamDetector (sakshi_beam.h).
//
// Build and run from the "niva sakshi" folder:
//   g++ -std=gnu++17 -Wall -Wextra -Werror -I"firmware/niva_hardware"
//       "firmware/tests/sakshi_beam_test.cpp" -o sakshi_beam_test && ./sakshi_beam_test
//
// The signals are synthetic shapes chosen to exercise the logic. They say
// nothing about how well the detector matches a real foot on a real beam;
// check F6 in the agreement study measures that.

#include <stdio.h>

#include "sakshi_beam.h"

static int failures = 0;

#define CHECK(cond)                                                    \
  do {                                                                 \
    if (!(cond)) {                                                     \
      printf("FAIL line %d: %s\n", __LINE__, #cond);                   \
      ++failures;                                                      \
    }                                                                  \
  } while (0)

static const uint64_t kStep = 13;  // ms per sample, about 80 SPS

static uint64_t tare(SakshiBeamDetector &d, float zero = 1000.0f) {
  d.beginTare();
  uint64_t t = 0;
  for (uint32_t i = 0; i < SakshiBeamDetector::kTareSamples; ++i, t += kStep) {
    d.update(zero, true, t);
  }
  return t;
}

static uint64_t feed(SakshiBeamDetector &d, float raw, int n, uint64_t t) {
  for (int i = 0; i < n; ++i, t += kStep) d.update(raw, true, t);
  return t;
}

int main() {
  {  // Nothing is reported until the beam has been zeroed.
    SakshiBeamDetector d;
    CHECK(d.state() == SAKSHI_NOT_READY);
    CHECK(!d.valid());
    d.update(5000.0f, true, 0);
    CHECK(d.state() == SAKSHI_NOT_READY);
    uint64_t at;
    CHECK(!d.takeStepOff(&at));
  }
  {  // Tare completes, then standing on the beam is seen.
    SakshiBeamDetector d;
    uint64_t t = tare(d);
    CHECK(d.state() == SAKSHI_EMPTY);
    CHECK(d.valid());
    t = feed(d, 1000.0f + 4000.0f, 10, t);
    CHECK(d.state() == SAKSHI_LOADED);
  }
  {  // A step-off is stamped at its first crossing, once.
    SakshiBeamDetector d;
    uint64_t t = tare(d);
    t = feed(d, 5000.0f, 40, t);
    const uint64_t offStart = t;
    t = feed(d, 1000.0f, 10, t);  // load back to zero
    uint64_t at = 0;
    CHECK(d.takeStepOff(&at));
    CHECK(at == offStart);
    CHECK(!d.takeStepOff(&at));
    CHECK(d.state() == SAKSHI_EMPTY);
  }
  {  // A one-sample dip is debounced away.
    SakshiBeamDetector d;
    uint64_t t = tare(d);
    t = feed(d, 5000.0f, 40, t);
    t = feed(d, 1000.0f, 2, t);
    t = feed(d, 5000.0f, 20, t);
    uint64_t at;
    CHECK(!d.takeStepOff(&at));
    CHECK(d.state() == SAKSHI_LOADED);
  }
  {  // A small sway (load stays above the loaded fraction) is not a step-off.
    SakshiBeamDetector d;
    uint64_t t = tare(d);
    t = feed(d, 5000.0f, 40, t);
    t = feed(d, 1000.0f + 0.7f * 4000.0f, 40, t);
    uint64_t at;
    CHECK(!d.takeStepOff(&at));
  }
  {  // A load cell fault marks the trial not valid and stays that way.
    SakshiBeamDetector d;
    uint64_t t = tare(d);
    t = feed(d, 5000.0f, 20, t);
    d.update(0.0f, false, t);
    CHECK(d.state() == SAKSHI_NOT_VALID);
    CHECK(!d.valid());
    t = feed(d, 5000.0f, 20, t + kStep);
    CHECK(d.state() == SAKSHI_NOT_VALID);
    t = tare(d);
    CHECK(d.state() == SAKSHI_EMPTY);
  }

  if (failures == 0) printf("sakshi beam: all checks passed\n");
  return failures == 0 ? 0 : 1;
}
