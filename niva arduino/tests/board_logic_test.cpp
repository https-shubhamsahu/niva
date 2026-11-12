// Off-target tests for niva_protected_steps/niva_board_logic.h: MCP3208
// frames, LSM6DSO32 settings and byte order, MAX17048 conversions, the
// insole tail check and the low-battery policy.
//
// Expected values come from the vendor sources named in that header. These
// tests check the arithmetic and bit layout; they say nothing about whether
// a real board answers that way (that is bring-up).

#include <math.h>
#include <stdio.h>

#include "niva_board_logic.h"

static int failures = 0;
static int checks = 0;
#define CHECK(cond)                                                    \
  do {                                                                 \
    checks++;                                                          \
    if (!(cond)) {                                                     \
      printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);           \
      failures++;                                                      \
    }                                                                  \
  } while (0)

static bool near(float a, float b, float tol) { return fabsf(a - b) <= tol; }

static void testMcp3208() {
  uint8_t tx[3];
  nivaMcp3208Command(0, tx);
  CHECK(tx[0] == 0x06 && tx[1] == 0x00 && tx[2] == 0x00);   // start, single-ended, D2..D0 = 000
  nivaMcp3208Command(4, tx);
  CHECK(tx[0] == 0x07 && tx[1] == 0x00);                    // D2 = 1
  nivaMcp3208Command(5, tx);
  CHECK(tx[0] == 0x07 && tx[1] == 0x40);
  nivaMcp3208Command(7, tx);
  CHECK(tx[0] == 0x07 && tx[1] == 0xC0);
  const uint8_t rx[3] = {0xFF, 0xFA, 0xBC};                 // high nibble of byte 2 is not data
  CHECK(nivaMcp3208Result(rx) == 0xABC);
  const uint8_t full[3] = {0x00, 0x0F, 0xFF};
  CHECK(nivaMcp3208Result(full) == 4095);
}

static void testLsm6() {
  CHECK(nivaLsm6Ctrl1Xl() == 0x4C);        // ODR 104 Hz, +-16 g
  CHECK(nivaLsm6Ctrl2G(500) == 0x44);      // ODR 104 Hz, 500 dps
  CHECK(nivaLsm6Ctrl2G(2000) == 0x4C);     // ODR 104 Hz, 2000 dps
  CHECK(near(NIVA_LSM6_ACCEL_LSB_PER_G, 2049.18f, 0.01f));
  CHECK(near(nivaLsm6GyroLsbPerDps(500), 57.143f, 0.001f));
  CHECK(near(nivaLsm6GyroLsbPerDps(2000), 14.286f, 0.001f));
  // gx = 0x0102, gy = -2, gz = 0x7FFF, ax = 0x1000, ay = -32768, az = 2049
  const uint8_t b[12] = {0x02, 0x01, 0xFE, 0xFF, 0xFF, 0x7F, 0x00, 0x10, 0x00, 0x80, 0x01, 0x08};
  int16_t raw[6];
  nivaLsm6Unpack(b, raw);
  CHECK(raw[0] == 0x1000 && raw[1] == -32768 && raw[2] == 2049);   // accel first, as the MPU6050 order
  CHECK(raw[3] == 0x0102 && raw[4] == -2 && raw[5] == 0x7FFF);
}

static void testGauge() {
  CHECK(nivaGaugeVcellMv(0) == 0);
  CHECK(nivaGaugeVcellMv(38400) == 3000);    // 38400 x 78.125 uV
  CHECK(nivaGaugeVcellMv(53760) == 4200);
  CHECK(nivaGaugeVcellMv(65535) == 5119);
  // Default register 0x96__ is 3.0 V; 2.68 V is code 67. Bits 8:0 survive.
  CHECK(nivaGaugeVresetWord(0x9600, 3000) == 0x9600);
  CHECK(nivaGaugeVresetWord(0x9600, NIVA_GAUGE_VRESET_MV) == (67 << 9));
  CHECK(nivaGaugeVresetWord(0x9701, NIVA_GAUGE_VRESET_MV) == ((67 << 9) | 0x0101));
  CHECK(nivaGaugeVresetWord(0x0000, 9000) == (127 << 9));   // clamped to 7 bits
}

static void testTail() {
  NivaTailResult r = nivaClassifyTail(2048, 4095);
  CHECK(r.state == NivaTail::NO_INSERT);
  r = nivaClassifyTail(2048, 1310);
  CHECK(r.state == NivaTail::OK && r.side == 'R');
  r = nivaClassifyTail(2340, 3378);
  CHECK(r.state == NivaTail::OK && r.side == 'L');
  r = nivaClassifyTail(2200, 1310 + 80);
  CHECK(r.state == NivaTail::OK && r.side == 'R');
  r = nivaClassifyTail(2200, 1310 + 81);
  CHECK(r.state == NivaTail::UNKNOWN_ID);
  r = nivaClassifyTail(2048, 2200);
  CHECK(r.state == NivaTail::UNKNOWN_ID && r.side == '?');
  r = nivaClassifyTail(2451, 1310);
  CHECK(r.state == NivaTail::FAULT);           // a shorted tail drives CH6 up, even with a good ID
  r = nivaClassifyTail(1949, 4095);
  CHECK(r.state == NivaTail::FAULT);
  r = nivaClassifyTail(4095, 4095);
  CHECK(r.state == NivaTail::FAULT);           // fault wins over "no insert"
  CHECK(nivaTailText(NivaTail::OK)[0] == 'o');
}

// The thresholds are DESIGN CHOICES in niva_board_logic.h. The first four
// checks pin behaviour any sensible policy needs; the rest pin this one.
static void testPowerPolicy() {
  NivaPowerPolicy p;
  bool any = false;
  for (int i = 0; i < 100; ++i) any = any || p.shouldShutDown(0);
  CHECK(!any);                                  // no gauge reading: never shut down

  NivaPowerPolicy full;
  any = false;
  for (int i = 0; i < 100; ++i) any = any || full.shouldShutDown(4150);
  CHECK(!any);                                  // full cell: never

  NivaPowerPolicy dip;
  const uint16_t mv[] = {3900, 3000, 3900, 3900, 3000, 3000, 3900, 3900};
  any = false;
  for (int i = 0; i < 8; ++i) any = any || dip.shouldShutDown(mv[i]);
  CHECK(!any);                                  // dips between good readings: not a flat cell

  NivaPowerPolicy flat;
  int callsToTrip = -1;
  for (int i = 0; i < 10 && callsToTrip < 0; ++i) {
    if (flat.shouldShutDown(3150)) callsToTrip = i + 1;
  }
  CHECK(callsToTrip >= 2 && callsToTrip <= 10);  // a flat cell trips within 100 s, but not on one reading
  CHECK(callsToTrip == NIVA_POWER_LOW_READINGS);

  NivaPowerPolicy edge;
  any = false;
  for (int i = 0; i < 10; ++i) any = any || edge.shouldShutDown(NIVA_POWER_LOW_MV);
  CHECK(!any);                                  // at the threshold is not below it
  NivaPowerPolicy gap;
  const uint16_t gapMv[] = {3400, 3400, 0, 3400};
  callsToTrip = -1;
  for (int i = 0; i < 4 && callsToTrip < 0; ++i) {
    if (gap.shouldShutDown(gapMv[i])) callsToTrip = i + 1;
  }
  CHECK(callsToTrip == 4);                      // a missed reading neither trips nor clears the count

  // After a brown-out reset: one low reading, at the higher threshold.
  NivaPowerPolicy bo;
  bo.afterBrownout = true;
  CHECK(bo.shouldShutDown(3700));
  NivaPowerPolicy boNoReading;
  boNoReading.afterBrownout = true;
  CHECK(!boNoReading.shouldShutDown(0) && boNoReading.afterBrownout);
  // A brown-out with a good cell (contact bounce, say): the first good
  // reading clears it, and 3.7 V is then fine again.
  NivaPowerPolicy boGood;
  boGood.afterBrownout = true;
  CHECK(!boGood.shouldShutDown(3900) && !boGood.afterBrownout);
  any = false;
  for (int i = 0; i < 10; ++i) any = any || boGood.shouldShutDown(3700);
  CHECK(!any);
}

int main() {
  testMcp3208();
  testLsm6();
  testGauge();
  testTail();
  testPowerPolicy();
  printf("board_logic_test: %d checks, %d failed\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
