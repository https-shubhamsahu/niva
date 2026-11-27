// ps_types.h - shared types and design-choice constants for Niva: Protected Steps.
//
// Pure C++ (no Arduino headers) so every module that includes it can be
// compiled and unit-tested on a PC.
//
// Every number in this file is a DESIGN CHOICE made when the firmware was
// written (3 November 2026), not a measured or validated value, unless the
// comment says otherwise. RQ1 is where the matching and stride constants get
// tuned against video.

#ifndef PS_TYPES_H
#define PS_TYPES_H

#include <stdint.h>
#include <stddef.h>
#include <string.h>

#define PS_PROTO 1
#define PS_FW_VERSION "ps-0.1.0"

// Validity, as in PROTOCOL.md and the Aavishkar validity states.
enum class PsVal : uint8_t { VALID = 0, DEGRADED = 1, INVALID = 2 };

inline const char* psValText(PsVal v) {
  switch (v) {
    case PsVal::VALID: return "VALID";
    case PsVal::DEGRADED: return "DEGRADED";
    default: return "INVALID";
  }
}

inline bool psValFromText(const char* s, PsVal& out) {
  if (strcmp(s, "VALID") == 0) { out = PsVal::VALID; return true; }
  if (strcmp(s, "DEGRADED") == 0) { out = PsVal::DEGRADED; return true; }
  if (strcmp(s, "INVALID") == 0) { out = PsVal::INVALID; return true; }
  return false;
}

enum class PsRole : uint8_t { ANKLE = 0, INSOLE = 1 };

inline const char* psRoleText(PsRole r) { return r == PsRole::ANKLE ? "ankle" : "insole"; }

// Battery: -1 means "no measurement" (JSON null). The current prototypes
// (ESP32 DevKit boards) have no battery sense; a MAX17048 at I2C 0x36 is
// read if one is present (the Rev C.1 pod design has one).
static const int8_t PS_BATT_NONE = -1;

// Home flag: -1 null (no home network configured or no scan yet), 0, 1.
static const int8_t PS_HOME_NULL = -1;

// --- Defaults from PROTOCOL.md (protocol values, not choices made here) ---
static const uint32_t PS_DEFAULT_MATCH_MS = 300;
static const uint32_t PS_DEFAULT_SETTLE_MS = 2000;
static const uint32_t PS_DEFAULT_HOME_SCAN_S = 300;
static const uint8_t PS_BATT_LOW_PCT = 10;           // PROTOCOL.md
static const uint32_t PS_HEARTBEAT_MS = 30000;       // PROTOCOL.md
static const uint32_t PS_INSOLE_LOST_MS = 120000;    // PROTOCOL.md
static const int32_t PS_HOME_RSSI_MIN_DBM = -85;     // PROTOCOL.md: RSSI > -85 dBm
static const uint32_t PS_LOG_FLUSH_MAX_MS = 60000;   // PROTOCOL.md upper bound

// --- Design choices: accepted ranges for the config command ---
static const uint32_t PS_MATCH_MS_MIN = 10, PS_MATCH_MS_MAX = 2000;
static const uint32_t PS_SETTLE_MS_MIN = 200, PS_SETTLE_MS_MAX = 30000;
static const uint32_t PS_SCAN_S_MIN = 30, PS_SCAN_S_MAX = 86400;

// --- Design choice: log flush interval (must be <= PS_LOG_FLUSH_MAX_MS) ---
static const uint32_t PS_LOG_FLUSH_MS = 30000;

// MAC helpers (pure).
inline void psMacToHex(const uint8_t mac[6], char out[13]) {
  static const char* hex = "0123456789ABCDEF";
  for (int i = 0; i < 6; ++i) {
    out[2 * i] = hex[mac[i] >> 4];
    out[2 * i + 1] = hex[mac[i] & 0x0F];
  }
  out[12] = '\0';
}

inline int psHexNibble(char c) {
  if (c >= '0' && c <= '9') return c - '0';
  if (c >= 'a' && c <= 'f') return c - 'a' + 10;
  if (c >= 'A' && c <= 'F') return c - 'A' + 10;
  return -1;
}

// Accepts "0A1B2C3D4E5F", "0a:1b:2c:3d:4e:5f" or "0A-1B-2C-3D-4E-5F".
inline bool psParseMac(const char* s, uint8_t mac[6]) {
  if (s == nullptr) return false;
  int n = 0;
  int hi = -1;
  for (const char* p = s; *p; ++p) {
    if (*p == ':' || *p == '-') {
      if (hi >= 0) return false;  // separator in the middle of a byte
      continue;
    }
    const int v = psHexNibble(*p);
    if (v < 0) return false;
    if (hi < 0) {
      hi = v;
    } else {
      if (n >= 6) return false;
      mac[n++] = (uint8_t)((hi << 4) | v);
      hi = -1;
    }
  }
  if (n != 6 || hi >= 0) return false;
  bool allZero = true, allFF = true;
  for (int i = 0; i < 6; ++i) {
    if (mac[i] != 0x00) allZero = false;
    if (mac[i] != 0xFF) allFF = false;
  }
  return !allZero && !allFF;  // neither is a usable unicast peer
}

inline void psBootToHex(uint32_t boot, char out[9]) {
  static const char* hex = "0123456789abcdef";
  for (int i = 0; i < 8; ++i) out[i] = hex[(boot >> (28 - 4 * i)) & 0x0F];
  out[8] = '\0';
}

#endif  // PS_TYPES_H
