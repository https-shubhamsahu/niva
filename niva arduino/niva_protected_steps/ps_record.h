// ps_record.h - hub log records: a fixed 32-byte binary form for flash and
// the JSON form of PROTOCOL.md for BLE and serial. Pure C++; host-tested.
//
// Binary layout (little endian), 32 bytes:
//   0 seq u32 | 4 boot u32 | 8 ms u32 | 12 type u8 | 13 a u8 | 14 b i16
//   16 c i32 | 20 d i32 | 24 e i32 | 28 f u8 | 29 g u8 | 30 crc16 (CCITT)
// The CRC lets the reader drop a record torn by a power cut.

#ifndef PS_RECORD_H
#define PS_RECORD_H

#include "ps_json.h"
#include "ps_types.h"

enum class PsRecType : uint8_t { STRIDE = 1, SYNC = 2, INSOLE = 3, GAP = 4, CONTACT = 5 };

enum class PsInsoleEvent : uint8_t { HEARTBEAT = 0, PAIRED = 1, LOST = 2, BATTERY_LOW = 3, UNPAIRED = 4 };
enum class PsGapReason : uint8_t { LOG_FULL = 0, REBOOT = 1, IMU_FAULT = 2 };

static const int16_t PS_DT_NULL = INT16_MIN;
static const size_t PS_REC_BYTES = 32;

struct PsRecord {
  uint32_t seq = 0;
  uint32_t boot = 0;
  uint32_t ms = 0;
  PsRecType type = PsRecType::GAP;

  // STRIDE
  char cls = 'X';
  int8_t home = PS_HOME_NULL;
  int16_t dt = PS_DT_NULL;
  uint16_t peakDps = 0;
  // SYNC
  uint64_t epochMs = 0;
  // INSOLE / CONTACT
  PsInsoleEvent event = PsInsoleEvent::HEARTBEAT;
  int8_t batt = PS_BATT_NONE;
  PsVal val = PsVal::INVALID;
  bool hasId = false;
  uint8_t id[6] = {0};
  bool late = false;
  // GAP
  PsGapReason reason = PsGapReason::REBOOT;
  uint32_t lost = 0;  // records dropped, when known (log_full); 0 = not reported
};

inline uint16_t psCrc16(const uint8_t* d, size_t n) {
  uint16_t crc = 0xFFFF;
  for (size_t i = 0; i < n; ++i) {
    crc ^= (uint16_t)d[i] << 8;
    for (int b = 0; b < 8; ++b) crc = (crc & 0x8000) ? (uint16_t)((crc << 1) ^ 0x1021) : (uint16_t)(crc << 1);
  }
  return crc;
}

namespace psrec_detail {
inline void put32(uint8_t* p, uint32_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24); }
inline uint32_t get32(const uint8_t* p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }
inline void put16(uint8_t* p, uint16_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); }
inline uint16_t get16(const uint8_t* p) { return (uint16_t)(p[0] | (p[1] << 8)); }
}  // namespace psrec_detail

inline void psRecordPack(const PsRecord& r, uint8_t out[PS_REC_BYTES]) {
  using namespace psrec_detail;
  memset(out, 0, PS_REC_BYTES);
  put32(out + 0, r.seq);
  put32(out + 4, r.boot);
  put32(out + 8, r.ms);
  out[12] = (uint8_t)r.type;
  switch (r.type) {
    case PsRecType::STRIDE:
      out[13] = (uint8_t)r.cls;
      put16(out + 14, (uint16_t)r.dt);
      put32(out + 16, r.peakDps);
      out[28] = (uint8_t)r.home;
      break;
    case PsRecType::SYNC:
      put32(out + 16, (uint32_t)(r.epochMs & 0xFFFFFFFFu));
      put32(out + 20, (uint32_t)(r.epochMs >> 32));
      break;
    case PsRecType::INSOLE:
    case PsRecType::CONTACT:
      out[13] = (uint8_t)r.event;
      put16(out + 14, (uint16_t)(int16_t)r.batt);
      memcpy(out + 16, r.id, 6);
      out[28] = (uint8_t)r.val;
      out[29] = (uint8_t)((r.hasId ? 1 : 0) | (r.late ? 2 : 0));
      break;
    case PsRecType::GAP:
      out[13] = (uint8_t)r.reason;
      put32(out + 16, r.lost);
      break;
  }
  put16(out + 30, psCrc16(out, 30));
}

// Returns false for a torn or unknown record.
inline bool psRecordUnpack(const uint8_t in[PS_REC_BYTES], PsRecord& r) {
  using namespace psrec_detail;
  if (get16(in + 30) != psCrc16(in, 30)) return false;
  r = PsRecord();
  r.seq = get32(in + 0);
  r.boot = get32(in + 4);
  r.ms = get32(in + 8);
  const uint8_t t = in[12];
  if (t < 1 || t > 5) return false;
  r.type = (PsRecType)t;
  switch (r.type) {
    case PsRecType::STRIDE:
      r.cls = (char)in[13];
      r.dt = (int16_t)get16(in + 14);
      r.peakDps = (uint16_t)get32(in + 16);
      r.home = (int8_t)in[28];
      break;
    case PsRecType::SYNC:
      r.epochMs = (uint64_t)get32(in + 16) | ((uint64_t)get32(in + 20) << 32);
      break;
    case PsRecType::INSOLE:
    case PsRecType::CONTACT:
      r.event = (PsInsoleEvent)in[13];
      r.batt = (int8_t)(int16_t)get16(in + 14);
      memcpy(r.id, in + 16, 6);
      r.val = (PsVal)in[28];
      r.hasId = (in[29] & 1) != 0;
      r.late = (in[29] & 2) != 0;
      break;
    case PsRecType::GAP:
      r.reason = (PsGapReason)in[13];
      r.lost = get32(in + 16);
      break;
  }
  return true;
}

inline const char* psInsoleEventText(PsInsoleEvent e) {
  switch (e) {
    case PsInsoleEvent::HEARTBEAT: return "heartbeat";
    case PsInsoleEvent::PAIRED: return "paired";
    case PsInsoleEvent::LOST: return "lost";
    case PsInsoleEvent::BATTERY_LOW: return "battery_low";
    default: return "unpaired";
  }
}

inline const char* psGapReasonText(PsGapReason g) {
  switch (g) {
    case PsGapReason::LOG_FULL: return "log_full";
    case PsGapReason::REBOOT: return "reboot";
    default: return "imu_fault";
  }
}

namespace psrec_detail {
inline void head(PsOut& o, const char* t, const PsRecord& r) {
  char boot[9];
  psBootToHex(r.boot, boot);
  o.raw("{\"t\":\"");
  o.raw(t);
  o.raw("\",\"seq\":");
  o.u64(r.seq);
  o.raw(",\"boot\":\"");
  o.raw(boot);
  o.raw("\",\"ms\":");
  o.u64(r.ms);
}
inline void battField(PsOut& o, int8_t batt) {
  o.raw(",\"batt\":");
  if (batt == PS_BATT_NONE) o.raw("null"); else o.i64(batt);
}
}  // namespace psrec_detail

// Encodes the PROTOCOL.md JSON form. Returns the length, or 0 if `cap` was
// too small. Every record fits in 160 bytes, well under the 240-byte limit.
inline size_t psRecordToJson(const PsRecord& r, char* buf, size_t cap) {
  using namespace psrec_detail;
  PsOut o(buf, cap);
  switch (r.type) {
    case PsRecType::STRIDE: {
      head(o, "stride", r);
      const char c[2] = {r.cls, '\0'};
      o.raw(",\"c\":\"");
      o.raw(c);
      o.raw("\",\"home\":");
      if (r.home == PS_HOME_NULL) o.raw("null"); else o.i64(r.home);
      o.raw(",\"dt\":");
      if (r.dt == PS_DT_NULL) o.raw("null"); else o.i64(r.dt);
      o.raw(",\"pk\":");  // optional field: mid-swing peak, deg/s
      o.u64(r.peakDps);
      o.raw("}");
      break;
    }
    case PsRecType::SYNC:
      head(o, "sync", r);
      o.raw(",\"epoch_ms\":");
      o.u64(r.epochMs);
      o.raw("}");
      break;
    case PsRecType::INSOLE: {
      head(o, "insole", r);
      battField(o, r.batt);
      o.raw(",\"val\":\"");
      o.raw(psValText(r.val));
      o.raw("\",\"event\":\"");
      o.raw(psInsoleEventText(r.event));
      o.raw("\"");
      if (r.hasId) {
        char id[13];
        psMacToHex(r.id, id);
        o.raw(",\"id\":\"");
        o.raw(id);
        o.raw("\"");
      }
      o.raw("}");
      break;
    }
    case PsRecType::GAP:
      head(o, "gap", r);
      o.raw(",\"reason\":\"");
      o.raw(psGapReasonText(r.reason));
      o.raw("\"");
      if (r.lost > 0) {
        o.raw(",\"lost\":");
        o.u64(r.lost);
      }
      o.raw("}");
      break;
    case PsRecType::CONTACT:
      // Not in PROTOCOL.md v1: an insole contact that matched no stride.
      head(o, "contact", r);
      o.raw(",\"late\":");
      o.raw(r.late ? "true" : "false");
      o.raw(",\"val\":\"");
      o.raw(psValText(r.val));
      o.raw("\"}");
      break;
  }
  return o.ok() ? o.len : 0;
}

// --- Messages that are not log records ---

inline size_t psBacklogEndJson(uint32_t lastSeq, char* buf, size_t cap) {
  PsOut o(buf, cap);
  o.raw("{\"t\":\"backlog_end\",\"last_seq\":");
  o.u64(lastSeq);
  o.raw("}");
  return o.ok() ? o.len : 0;
}

inline size_t psErrorJson(const char* cmd, const char* reason, char* buf, size_t cap) {
  PsOut o(buf, cap);
  o.raw("{\"t\":\"error\",\"cmd\":");
  o.str(cmd);
  o.raw(",\"reason\":");
  o.str(reason);
  o.raw("}");
  return o.ok() ? o.len : 0;
}

inline size_t psTimeReadJson(uint32_t ms, uint32_t boot, char* buf, size_t cap) {
  char b[9];
  psBootToHex(boot, b);
  PsOut o(buf, cap);
  o.raw("{\"ms\":");
  o.u64(ms);
  o.raw(",\"boot\":\"");
  o.raw(b);
  o.raw("\"}");
  return o.ok() ? o.len : 0;
}

// Info. `peerLabel` is "insole" on the hub and "hub" on the insole.
inline size_t psInfoJson(PsRole role, uint32_t boot, const uint8_t id[6], int8_t batt,
                         const char* peerLabel, bool hasPeer, const uint8_t peer[6],
                         char* buf, size_t cap) {
  char b[9], i[13], p[13];
  psBootToHex(boot, b);
  psMacToHex(id, i);
  PsOut o(buf, cap);
  o.raw("{\"proto\":");
  o.i64(PS_PROTO);
  o.raw(",\"role\":\"");
  o.raw(psRoleText(role));
  o.raw("\",\"fw\":\"" PS_FW_VERSION "\",\"boot\":\"");
  o.raw(b);
  o.raw("\",\"id\":\"");
  o.raw(i);
  o.raw("\"");
  psrec_detail::battField(o, batt);
  o.raw(",\"");
  o.raw(peerLabel);
  o.raw("\":");
  if (hasPeer) {
    psMacToHex(peer, p);
    o.raw("\"");
    o.raw(p);
    o.raw("\"");
  } else {
    o.raw("null");
  }
  o.raw("}");
  return o.ok() ? o.len : 0;
}

struct PsHubStatus {
  uint32_t ms;
  int8_t batt;
  PsVal val;
  int8_t home;
  uint32_t strides;
  bool paired;
  uint8_t insoleId[6];
  bool seen;          // any packet from the insole this boot
  uint32_t seenMs;
  int8_t insoleBatt;
  bool insoleHeard;   // a heartbeat has been received
  PsVal insoleVal;
};

inline size_t psHubStatusJson(const PsHubStatus& s, char* buf, size_t cap) {
  PsOut o(buf, cap);
  o.raw("{\"t\":\"status\",\"ms\":");
  o.u64(s.ms);
  psrec_detail::battField(o, s.batt);
  o.raw(",\"val\":\"");
  o.raw(psValText(s.val));
  o.raw("\",\"home\":");
  if (s.home == PS_HOME_NULL) o.raw("null"); else o.i64(s.home);
  o.raw(",\"strides_since_boot\":");
  o.u64(s.strides);
  o.raw(",\"insole\":");
  if (!s.paired) {
    o.raw("null");
  } else {
    char id[13];
    psMacToHex(s.insoleId, id);
    o.raw("{\"id\":\"");
    o.raw(id);
    o.raw("\",\"seen_ms\":");
    if (s.seen) o.u64(s.seenMs); else o.raw("null");
    psrec_detail::battField(o, s.insoleHeard ? s.insoleBatt : PS_BATT_NONE);
    o.raw(",\"val\":");
    if (s.insoleHeard) {
      o.raw("\"");
      o.raw(psValText(s.insoleVal));
      o.raw("\"");
    } else {
      o.raw("null");
    }
    o.raw("}");
  }
  o.raw("}");
  return o.ok() ? o.len : 0;
}

#endif  // PS_RECORD_H
