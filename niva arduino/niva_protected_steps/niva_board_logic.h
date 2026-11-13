// niva_board_logic.h - pure helpers behind the Niva pod Rev C.2 drivers
// (MCP3208, LSM6DSO32, MAX17048), the insole tail check and the low-battery
// policy. No Arduino headers, so tests/board_logic_test.cpp runs them on a PC.
//
// Register facts were read on 9 November 2026 from the vendors' own code:
//   LSM6DSO32: STMicroelectronics lsm6dso32-pid, lsm6dso32_reg.h / .c
//   MAX17048:  SparkFun MAX1704x library (VRESET/ID 0x18, VCELL 78.125 uV/LSB)
//   MCP3208:   Microchip DS21298E, figure 6-1 (start, SGL/DIFF, D2..D0)
// Every threshold marked DESIGN CHOICE is not measured.

#ifndef NIVA_BOARD_LOGIC_H
#define NIVA_BOARD_LOGIC_H

#include <stdint.h>

// ------------------------------------------------------------- MCP3208 ---

// Three-byte SPI frame for a single-ended read of channel ch (0..7):
// 0000 0 1 SGL D2 | D1 D0 xxxxxx | xxxxxxxx. The 12-bit result is the low
// nibble of the second byte returned and all of the third.
inline void nivaMcp3208Command(uint8_t ch, uint8_t tx[3]) {
  tx[0] = (uint8_t)(0x06 | ((ch >> 2) & 0x01));
  tx[1] = (uint8_t)((ch & 0x03) << 6);
  tx[2] = 0;
}

inline uint16_t nivaMcp3208Result(const uint8_t rx[3]) {
  return (uint16_t)(((rx[1] & 0x0F) << 8) | rx[2]);
}

// ----------------------------------------------------------- LSM6DSO32 ---

static const uint8_t NIVA_LSM6_WHO_AM_I = 0x0F;
static const uint8_t NIVA_LSM6_ID = 0x6C;
static const uint8_t NIVA_LSM6_CTRL1_XL = 0x10;
static const uint8_t NIVA_LSM6_CTRL2_G = 0x11;
static const uint8_t NIVA_LSM6_CTRL3_C = 0x12;
static const uint8_t NIVA_LSM6_CTRL4_C = 0x13;
static const uint8_t NIVA_LSM6_OUTX_L_G = 0x22;   // gyro x, y, z, then accel x, y, z at 0x28
static const uint8_t NIVA_LSM6_SPI_READ = 0x80;   // address bit 7 set for a read
static const uint8_t NIVA_LSM6_CTRL3_BDU_IF_INC = 0x44;    // BDU bit 6, IF_INC bit 2
static const uint8_t NIVA_LSM6_CTRL4_I2C_DISABLE = 0x04;   // bit 2 (review A17)

// CTRL1_XL: ODR 104 Hz high-performance (0x4 in bits 7:4), +-16 g (0b11 in
// bits 3:2). 104 Hz with the default ODR/2 filter is the nearest match to the
// MPU6050's 44 Hz DLPF read at 100 Hz (DESIGN CHOICE).
inline uint8_t nivaLsm6Ctrl1Xl() { return (uint8_t)((0x4 << 4) | (0x3 << 2)); }

// CTRL2_G: ODR 104 Hz, full scale in bits 3:1 (500 dps = 2, 2000 dps = 6).
inline uint8_t nivaLsm6Ctrl2G(uint16_t dps) {
  return (uint8_t)((0x4 << 4) | ((dps >= 2000 ? 6 : 2) << 1));
}

// Sensitivities from ST's conversion functions: 0.488 mg/LSB at +-16 g,
// 17.5 mdps/LSB at 500 dps, 70 mdps/LSB at 2000 dps.
static const float NIVA_LSM6_ACCEL_LSB_PER_G = 1000.0f / 0.488f;
inline float nivaLsm6GyroLsbPerDps(uint16_t dps) { return dps >= 2000 ? 1000.0f / 70.0f : 1000.0f / 17.5f; }

// 12 bytes read from OUTX_L_G (little endian) into the order the firmware
// has always used for the MPU6050: ax, ay, az, gx, gy, gz.
inline void nivaLsm6Unpack(const uint8_t b[12], int16_t raw[6]) {
  for (int i = 0; i < 3; ++i) {
    raw[3 + i] = (int16_t)(b[2 * i] | (b[2 * i + 1] << 8));
    raw[i] = (int16_t)(b[6 + 2 * i] | (b[6 + 2 * i + 1] << 8));
  }
}

// ------------------------------------------------------------ MAX17048 ---

static const uint8_t NIVA_GAUGE_ADDR = 0x36;
static const uint8_t NIVA_GAUGE_VCELL = 0x02;
static const uint8_t NIVA_GAUGE_SOC = 0x04;
static const uint8_t NIVA_GAUGE_VERSION = 0x08;
static const uint8_t NIVA_GAUGE_VRESET_ID = 0x18;
// Review A12: the gauge sees the cell through the PCM, F1 and the J2
// contacts, so radio bursts can dip its input below the default 3.0 V reset
// threshold. 2.68 V is the nearest 40 mV step below 2.7 V.
static const uint16_t NIVA_GAUGE_VRESET_MV = 2680;

inline uint16_t nivaGaugeVcellMv(uint16_t raw) {
  return (uint16_t)(((uint64_t)raw * 78125u) / 1000000u);   // 78.125 uV per LSB; 64-bit: 65535 x 78125 > 2^32
}

// VRESET is bits 15:9 at 40 mV per LSB; bits 8:0 (comparator disable, ID) are kept.
inline uint16_t nivaGaugeVresetWord(uint16_t current, uint16_t mv) {
  uint16_t code = (uint16_t)(mv / 40);
  if (code > 127) code = 127;
  return (uint16_t)((current & 0x01FF) | (code << 9));
}

// --------------------------------------------------- insole tail check ---

// The pod reads two monitor channels on the MCP3208, both against VREF =
// VEXC (ELECTRICAL-REVIEW section 4, review A15):
//   CH6 = +3V3 / 2. 2048 with no load, about 2329-2353 with every FSR
//         saturated. A short on the tail pulls VEXC down and drives it up.
//   CH7 = the insert ID resistor against R30 = 10 k from VEXC, so
//         code = 4096 R / (10 k + R): right medium 4.7 k -> 1310, left
//         medium 47 k -> 3378. An open tail reads 4095.
enum class NivaTail : uint8_t { NOT_SENSED = 0, NO_INSERT, OK, FAULT, UNKNOWN_ID };

struct NivaTailResult {
  NivaTail state;
  char side;   // 'R', 'L', or '?' when there is no known insert
};

static const uint16_t NIVA_TAIL_CH6_MIN = 1950;      // DESIGN CHOICE: below the 2048 floor
static const uint16_t NIVA_TAIL_CH6_MAX = 2450;      // DESIGN CHOICE, review A15
static const uint16_t NIVA_TAIL_OPEN_MIN = 4000;     // DESIGN CHOICE: open tail reads 4095
static const uint16_t NIVA_TAIL_ID_TOL = 80;         // DESIGN CHOICE: +-80 counts per ID

struct NivaInsertId { uint16_t code; char side; };
static const NivaInsertId NIVA_INSERT_IDS[] = {{1310, 'R'}, {3378, 'L'}};   // medium inserts

inline const char* nivaTailText(NivaTail t) {
  switch (t) {
    case NivaTail::NO_INSERT: return "no_insert";
    case NivaTail::OK: return "ok";
    case NivaTail::FAULT: return "fault";
    case NivaTail::UNKNOWN_ID: return "unknown_id";
    default: return "not_sensed";
  }
}

inline NivaTailResult nivaClassifyTail(uint16_t ch6, uint16_t ch7) {
  if (ch6 < NIVA_TAIL_CH6_MIN || ch6 > NIVA_TAIL_CH6_MAX) return {NivaTail::FAULT, '?'};
  if (ch7 >= NIVA_TAIL_OPEN_MIN) return {NivaTail::NO_INSERT, '?'};
  for (const NivaInsertId& id : NIVA_INSERT_IDS) {
    const int d = (int)ch7 - (int)id.code;
    if (d <= (int)NIVA_TAIL_ID_TOL && d >= -(int)NIVA_TAIL_ID_TOL) return {NivaTail::OK, id.side};
  }
  return {NivaTail::UNKNOWN_ID, '?'};
}

// --------------------------------------------------- low-battery policy ---

// Two checks decide when the pod stops and goes to deep sleep (the button
// wakes it). Both take the gauge's cell voltage in mV; 0 means no reading.
//
// Facts (review A7, A9, C7; EEMB spec ZJQM-RD-SPC-A03249 for the 2-lead
// cell, the NTC variant's spec is not in hand):
//   - the cell's PCM cuts off at 3.0 V (no tolerance given) and releases at
//     3.5 +- 0.05 V;
//   - during a 0.35 A radio burst the 3.3 V rail falls below the ESP32-C3's
//     3.0 V minimum when the cell is under about 3.3-3.8 V, depending on the
//     polyfuse (0.25-1.2 ohm), so a low cell can brown out while the radios
//     start, before the running check has any readings;
//   - the MAX17048 stays powered through ESP32 resets and deep sleep, so a
//     reading at boot is valid; after a cartridge is inserted it may read 0
//     until its first conversion;
//   - asleep, the analog front end still draws about 0.3-0.5 mA (review A9),
//     so sleep only delays the PCM cut-off by about a day. Rev C.3 copper.
//
// DESIGN CHOICES, to check against the brown-out point measured on the bench:
//   - Boot check, once, before any radio starts, so the cell is near rest:
//       * normally sleep below 3.50 V;
//       * after a brown-out reset, below 3.80 V (the top of the band above):
//         a cell that low browns out under load. A contact bounce on a
//         healthy cell between 3.76 and 3.80 V also lands here; it costs one
//         button press, because the wake rule below lets it run again;
//       * after waking from a low-battery sleep, below 3.60 V: 100 mV of
//         hysteresis, so pressing the button on a flat cell does not start
//         the radios for another half minute;
//   - Running check, about every 10 s with the radios on: 3 readings in a
//     row below 3.50 V (about 30 s), so a reading taken during a burst does
//     not trip it, and a good reading starts the count again;
//   - 3.50 V: a Li-ion cell resting at 3.5 V has about 5 % left. With F1 near
//     its fresh 0.25 ohm the rail rides through a burst down to 3.3 V; with a
//     tripped-and-recovered F1 it may not (review A7: "may have to sit near
//     3.7 V"). The bench measurement sets this;
//   - SOC is not used. After a cartridge swap the gauge's quick-start
//     estimate can be well off, and brown-out depends on voltage, not charge.
static const uint16_t NIVA_POWER_LOW_MV = 3500;
static const uint16_t NIVA_POWER_LOW_MV_AFTER_BROWNOUT = 3800;
static const uint16_t NIVA_POWER_RESUME_MV = 3600;
static const uint8_t NIVA_POWER_LOW_READINGS = 3;

// Boot check. True when the pod should go straight back to sleep.
inline bool nivaPowerSleepAtBoot(uint16_t restMv, bool afterBrownout, bool afterLowBatterySleep) {
  if (restMv == 0) return false;   // no reading is no evidence; the running check still watches
  if (afterLowBatterySleep) return restMv < NIVA_POWER_RESUME_MV;
  if (afterBrownout) return restMv < NIVA_POWER_LOW_MV_AFTER_BROWNOUT;
  return restMv < NIVA_POWER_LOW_MV;
}

// Running check.
struct NivaPowerPolicy {
  uint8_t lowCount = 0;   // consecutive readings that looked low

  bool shouldShutDown(uint16_t vcellMv) {
    if (vcellMv == 0) return false;   // no reading is no evidence: keep the count
    if (vcellMv >= NIVA_POWER_LOW_MV) {
      lowCount = 0;
      return false;
    }
    if (lowCount < NIVA_POWER_LOW_READINGS) ++lowCount;
    return lowCount >= NIVA_POWER_LOW_READINGS;
  }
};

#endif  // NIVA_BOARD_LOGIC_H
