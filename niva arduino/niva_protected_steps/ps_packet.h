// ps_packet.h - the insole <-> hub ESP-NOW packets. Internal to the
// firmware (PROTOCOL.md leaves the layout to us). Pure C++; host-tested.
//
// Header (16 bytes, little endian):
//   0 'N' | 1 'S' | 2 version | 3 type | 4 insole boot id u32
//   8 packet seq u32 | 12 txMs u32 (sender clock when handed to the radio)
// HEARTBEAT (+8): batt i8 | val u8 | flags u8 | channel u8 | dropped u32
// CONTACTS  (+4 + 8n): n u8 | val u8 | batt i8 | reserved u8 |
//                      n x { contact seq u32 | contact ms u32 }
// PAIR_REQ  (+0)         insole -> broadcast, during a pairing window
// PAIR_ACK  (+1)         hub -> insole: channel u8
//
// Delivery: the insole sends unicast and treats the ESP-NOW MAC-layer ack
// as the acknowledgement. Unacked contacts stay queued and are resent, so
// the hub deduplicates by contact seq (per insole boot).

#ifndef PS_PACKET_H
#define PS_PACKET_H

#include "ps_types.h"

enum class PsPktType : uint8_t { HEARTBEAT = 1, CONTACTS = 2, PAIR_REQ = 3, PAIR_ACK = 4 };

static const uint8_t PS_PKT_VERSION = 1;
static const size_t PS_PKT_HEADER = 16;
static const uint8_t PS_PKT_MAX_CONTACTS = 16;  // 16 + 4 + 128 = 148 bytes < 250
static const size_t PS_PKT_MAX = 250;           // ESP-NOW v1 payload limit

struct PsPktContact {
  uint32_t seq;
  uint32_t ms;
};

struct PsPacket {
  PsPktType type = PsPktType::HEARTBEAT;
  uint32_t boot = 0;
  uint32_t pktSeq = 0;
  uint32_t txMs = 0;
  int8_t batt = PS_BATT_NONE;
  PsVal val = PsVal::INVALID;
  uint8_t flags = 0;
  uint8_t channel = 0;
  uint32_t dropped = 0;  // contacts the insole lost before they were acked
  uint8_t n = 0;
  PsPktContact c[PS_PKT_MAX_CONTACTS];
};

namespace pspkt_detail {
inline void put32(uint8_t* p, uint32_t v) { p[0] = (uint8_t)v; p[1] = (uint8_t)(v >> 8); p[2] = (uint8_t)(v >> 16); p[3] = (uint8_t)(v >> 24); }
inline uint32_t get32(const uint8_t* p) { return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24); }
}  // namespace pspkt_detail

// Returns the encoded length, or 0 if the packet is invalid.
inline size_t psPacketEncode(const PsPacket& p, uint8_t* out, size_t cap) {
  using namespace pspkt_detail;
  size_t len = PS_PKT_HEADER;
  switch (p.type) {
    case PsPktType::HEARTBEAT: len += 8; break;
    case PsPktType::CONTACTS:
      if (p.n == 0 || p.n > PS_PKT_MAX_CONTACTS) return 0;
      len += 4 + 8u * p.n;
      break;
    case PsPktType::PAIR_REQ: break;
    case PsPktType::PAIR_ACK: len += 1; break;
    default: return 0;
  }
  if (len > cap || len > PS_PKT_MAX) return 0;
  out[0] = 'N';
  out[1] = 'S';
  out[2] = PS_PKT_VERSION;
  out[3] = (uint8_t)p.type;
  put32(out + 4, p.boot);
  put32(out + 8, p.pktSeq);
  put32(out + 12, p.txMs);
  uint8_t* b = out + PS_PKT_HEADER;
  switch (p.type) {
    case PsPktType::HEARTBEAT:
      b[0] = (uint8_t)p.batt;
      b[1] = (uint8_t)p.val;
      b[2] = p.flags;
      b[3] = p.channel;
      put32(b + 4, p.dropped);
      break;
    case PsPktType::CONTACTS:
      b[0] = p.n;
      b[1] = (uint8_t)p.val;
      b[2] = (uint8_t)p.batt;
      b[3] = 0;
      for (uint8_t i = 0; i < p.n; ++i) {
        put32(b + 4 + 8 * i, p.c[i].seq);
        put32(b + 8 + 8 * i, p.c[i].ms);
      }
      break;
    case PsPktType::PAIR_ACK:
      b[0] = p.channel;
      break;
    default:
      break;
  }
  return len;
}

// Rewrites txMs in an encoded packet (each retry is re-stamped).
inline void psPacketStamp(uint8_t* buf, size_t len, uint32_t txMs) {
  if (len >= PS_PKT_HEADER) pspkt_detail::put32(buf + 12, txMs);
}

inline bool psPacketDecode(const uint8_t* in, size_t len, PsPacket& p) {
  using namespace pspkt_detail;
  if (len < PS_PKT_HEADER || in[0] != 'N' || in[1] != 'S' || in[2] != PS_PKT_VERSION) return false;
  p = PsPacket();
  p.type = (PsPktType)in[3];
  p.boot = get32(in + 4);
  p.pktSeq = get32(in + 8);
  p.txMs = get32(in + 12);
  const uint8_t* b = in + PS_PKT_HEADER;
  const size_t body = len - PS_PKT_HEADER;
  switch (p.type) {
    case PsPktType::HEARTBEAT:
      if (body != 8) return false;
      p.batt = (int8_t)b[0];
      if (b[1] > 2) return false;
      p.val = (PsVal)b[1];
      p.flags = b[2];
      p.channel = b[3];
      p.dropped = get32(b + 4);
      return true;
    case PsPktType::CONTACTS:
      if (body < 4) return false;
      p.n = b[0];
      if (p.n == 0 || p.n > PS_PKT_MAX_CONTACTS || body != 4u + 8u * p.n || b[1] > 2) return false;
      p.val = (PsVal)b[1];
      p.batt = (int8_t)b[2];
      for (uint8_t i = 0; i < p.n; ++i) {
        p.c[i].seq = get32(b + 4 + 8 * i);
        p.c[i].ms = get32(b + 8 + 8 * i);
      }
      return true;
    case PsPktType::PAIR_REQ:
      return body == 0;
    case PsPktType::PAIR_ACK:
      if (body != 1) return false;
      p.channel = b[0];
      return true;
    default:
      return false;
  }
}

#endif  // PS_PACKET_H
