// ps_cmd.h - command parser for the BLE Control characteristic, the BLE
// Time write and the USB serial console. Pure C++; unit-tested on the host.
//
// JSON commands are those of PROTOCOL.md ("backlog", "config", "pair",
// "unpair", "ack") plus "role" (see below). Serial also accepts the JSON, plus plain
// text lab commands:
//   role ankle|insole     store the role in NVS and reboot
//   pair <mac>            ankle: pair this insole; insole: pair this hub
//   pair                  open a 60 s pairing window (same as a long press)
//   unpair
//   tare                  insole: tare now (keep it unloaded)
//   lab on|off            insole: lab mode (Wi-Fi WebSocket + JSON frames)
//   axis +x|-x|+y|-y|+z|-z  ankle: gyro axis used as shank angular velocity
//   channel <1..13>       ESP-NOW channel (ankle; the insole searches)
//   home <ssid>|none      ankle: home network SSID
//   wifi <ssid> [<password>] | wifi none
//                         Wi-Fi network that lab mode joins (both roles store it;
//                         the hub never joins). The SSID is the first word, so it
//                         cannot contain spaces; the rest of the line is the password
//                         (8-63 bytes, or none for an open network). Never echoed.
//   time <epoch_ms>       ankle: same as a BLE Time write (lab use)
//   backlog <from_seq>    ankle: print stored records from from_seq
//   status | info | help | reboot

#ifndef PS_CMD_H
#define PS_CMD_H

#include <stdlib.h>

#include "ps_json.h"
#include "ps_types.h"

enum class PsCmdType : uint8_t {
  NONE = 0,   // empty line
  ERROR,      // see reason
  BACKLOG,
  CONFIG,
  PAIR,
  UNPAIR,
  ACK,
  TIME,
  ROLE,
  TARE,
  LAB,
  AXIS,
  CHANNEL,
  HOME,
  WIFI,
  STATUS,
  INFO,
  HELP,
  REBOOT,
};

struct PsCommand {
  PsCmdType type = PsCmdType::NONE;
  char name[16] = {0};     // the "cmd" value or the first serial word, for error records
  char reason[24] = {0};   // for ERROR

  uint32_t fromSeq = 0;    // BACKLOG
  uint32_t uptoSeq = 0;    // ACK
  uint64_t epochMs = 0;    // TIME

  bool macSet = false;     // PAIR: false means "open a pairing window"
  uint8_t mac[6] = {0};

  // CONFIG (each field optional)
  bool hasHomeSsid = false;  // homeSsid[0] == 0 means "clear home network"
  char homeSsid[33] = {0};
  bool hasHomeBssid = false; // all-zero means "clear"
  uint8_t homeBssid[6] = {0};
  bool hasMatchMs = false;
  uint32_t matchMs = 0;
  bool hasSettleMs = false;
  uint32_t settleMs = 0;
  bool hasHomeScanS = false;
  uint32_t homeScanS = 0;

  PsRole role = PsRole::ANKLE;  // ROLE
  bool on = false;              // LAB
  int8_t axis = 0;              // AXIS: +-1 x, +-2 y, +-3 z
  uint8_t channel = 0;          // CHANNEL

  // WIFI: wifiSsid[0] == 0 means "forget the stored network"
  char wifiSsid[33] = {0};
  char wifiPass[64] = {0};
};

namespace pscmd_detail {
inline void setName(PsCommand& c, const char* s, size_t n) {
  if (n >= sizeof(c.name)) n = sizeof(c.name) - 1;
  memcpy(c.name, s, n);
  c.name[n] = '\0';
}
inline bool fail(PsCommand& c, const char* reason) {
  c.type = PsCmdType::ERROR;
  strncpy(c.reason, reason, sizeof(c.reason) - 1);
  c.reason[sizeof(c.reason) - 1] = '\0';
  return false;
}
inline bool u32Field(const PsJsonObject& o, const char* key, uint32_t lo, uint32_t hi,
                     bool& has, uint32_t& out, PsCommand& c) {
  const PsJsonField* f = o.find(key);
  if (f == nullptr) return true;
  if (f->type != PsJsonType::INT) return fail(c, "bad_type");
  if (f->num < (int64_t)lo || f->num > (int64_t)hi) return fail(c, "out_of_range");
  has = true;
  out = (uint32_t)f->num;
  return true;
}
}  // namespace pscmd_detail

// Parses one JSON command (BLE Control, or a serial line starting with '{').
// Returns true for a valid command; otherwise cmd.type == ERROR and
// cmd.reason / cmd.name say why, for the {"t":"error"} record.
inline bool psParseJsonCommand(const char* text, size_t n, PsCommand& cmd) {
  using namespace pscmd_detail;
  cmd = PsCommand();
  PsJsonObject o;
  if (!psJsonParse(text, n, o)) return fail(cmd, "malformed");
  const PsJsonField* c = o.find("cmd");
  if (c == nullptr) {
    // A Time write may also arrive here on serial.
    if (o.find("epoch_ms") != nullptr) {
      int64_t ms;
      if (!o.getInt("epoch_ms", ms) || ms <= 0) return fail(cmd, "bad_epoch_ms");
      cmd.type = PsCmdType::TIME;
      cmd.epochMs = (uint64_t)ms;
      return true;
    }
    return fail(cmd, "missing_cmd");
  }
  if (c->type != PsJsonType::STRING) return fail(cmd, "bad_cmd");
  setName(cmd, c->str, c->strLen);
  char name[16];
  if (!o.getString("cmd", name, sizeof(name))) return fail(cmd, "unknown_cmd");

  if (strcmp(name, "backlog") == 0) {
    int64_t v = 0;
    const PsJsonField* f = o.find("from_seq");
    if (f == nullptr) {
      v = 0;  // whole log
    } else if (f->type != PsJsonType::INT || f->num < 0 || f->num > 0xFFFFFFFFLL) {
      return fail(cmd, "bad_from_seq");
    } else {
      v = f->num;
    }
    cmd.type = PsCmdType::BACKLOG;
    cmd.fromSeq = (uint32_t)v;
    return true;
  }
  if (strcmp(name, "ack") == 0) {
    const PsJsonField* f = o.find("upto_seq");
    if (f == nullptr || f->type != PsJsonType::INT || f->num < 0 || f->num > 0xFFFFFFFFLL) {
      return fail(cmd, "bad_upto_seq");
    }
    cmd.type = PsCmdType::ACK;
    cmd.uptoSeq = (uint32_t)f->num;
    return true;
  }
  if (strcmp(name, "unpair") == 0) {
    cmd.type = PsCmdType::UNPAIR;
    return true;
  }
  if (strcmp(name, "role") == 0) {
    // Not in PROTOCOL.md v1's command list, which says the role can be set
    // over BLE without naming a command: {"cmd":"role","role":"insole"}.
    char role[12];
    if (!o.getString("role", role, sizeof(role))) return fail(cmd, "bad_role");
    if (strcmp(role, "ankle") == 0) cmd.role = PsRole::ANKLE;
    else if (strcmp(role, "insole") == 0) cmd.role = PsRole::INSOLE;
    else return fail(cmd, "bad_role");
    cmd.type = PsCmdType::ROLE;
    return true;
  }
  if (strcmp(name, "pair") == 0) {
    char mac[24];
    if (o.find("insole") == nullptr) {
      cmd.type = PsCmdType::PAIR;  // no id: open a pairing window
      return true;
    }
    if (!o.getString("insole", mac, sizeof(mac)) || !psParseMac(mac, cmd.mac)) {
      return fail(cmd, "bad_insole_id");
    }
    cmd.type = PsCmdType::PAIR;
    cmd.macSet = true;
    return true;
  }
  if (strcmp(name, "config") == 0) {
    bool any = false;
    if (o.find("home_ssid") != nullptr) {
      if (o.isNull("home_ssid")) {
        cmd.homeSsid[0] = '\0';
      } else if (!o.getString("home_ssid", cmd.homeSsid, sizeof(cmd.homeSsid))) {
        return fail(cmd, "bad_home_ssid");  // not a string, or over 32 bytes
      }
      cmd.hasHomeSsid = true;
      any = true;
    }
    if (o.find("home_bssid") != nullptr) {
      char b[24];
      if (o.isNull("home_bssid")) {
        memset(cmd.homeBssid, 0, 6);
      } else if (!o.getString("home_bssid", b, sizeof(b)) || !psParseMac(b, cmd.homeBssid)) {
        return fail(cmd, "bad_home_bssid");
      }
      cmd.hasHomeBssid = true;
      any = true;
    }
    if (!u32Field(o, "match_ms", PS_MATCH_MS_MIN, PS_MATCH_MS_MAX, cmd.hasMatchMs, cmd.matchMs, cmd)) return false;
    if (!u32Field(o, "settle_ms", PS_SETTLE_MS_MIN, PS_SETTLE_MS_MAX, cmd.hasSettleMs, cmd.settleMs, cmd)) return false;
    if (!u32Field(o, "home_scan_s", PS_SCAN_S_MIN, PS_SCAN_S_MAX, cmd.hasHomeScanS, cmd.homeScanS, cmd)) return false;
    any = any || cmd.hasMatchMs || cmd.hasSettleMs || cmd.hasHomeScanS;
    if (!any) return fail(cmd, "empty_config");
    cmd.type = PsCmdType::CONFIG;
    return true;
  }
  return fail(cmd, "unknown_cmd");
}

// Parses a BLE Time write: {"epoch_ms":1793650000000}.
inline bool psParseTimeWrite(const char* text, size_t n, uint64_t& epochMs) {
  PsJsonObject o;
  if (!psJsonParse(text, n, o)) return false;
  int64_t v;
  if (!o.getInt("epoch_ms", v) || v <= 0) return false;
  epochMs = (uint64_t)v;
  return true;
}

// Parses one serial line (text command or JSON).
inline bool psParseSerialLine(const char* line, PsCommand& cmd) {
  using namespace pscmd_detail;
  cmd = PsCommand();
  // Trim.
  while (*line == ' ' || *line == '\t') ++line;
  size_t n = strlen(line);
  while (n > 0 && (line[n - 1] == ' ' || line[n - 1] == '\t' || line[n - 1] == '\r' || line[n - 1] == '\n')) --n;
  if (n == 0) { cmd.type = PsCmdType::NONE; return false; }
  if (line[0] == '{') return psParseJsonCommand(line, n, cmd);

  char buf[128];  // fits "wifi" + a 32-byte SSID + a 63-byte password
  if (n >= sizeof(buf)) { setName(cmd, line, 15); return fail(cmd, "too_long"); }
  memcpy(buf, line, n);
  buf[n] = '\0';
  char* word = buf;
  char* arg = strchr(buf, ' ');
  if (arg != nullptr) {
    *arg++ = '\0';
    while (*arg == ' ') ++arg;
    if (*arg == '\0') arg = nullptr;
  }
  for (char* p = word; *p; ++p) if (*p >= 'A' && *p <= 'Z') *p = (char)(*p - 'A' + 'a');
  setName(cmd, word, strlen(word));

  auto noArg = [&](PsCmdType t) -> bool {
    if (arg != nullptr) return fail(cmd, "unexpected_arg");
    cmd.type = t;
    return true;
  };

  if (strcmp(word, "role") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    if (strcmp(arg, "ankle") == 0) cmd.role = PsRole::ANKLE;
    else if (strcmp(arg, "insole") == 0) cmd.role = PsRole::INSOLE;
    else return fail(cmd, "bad_role");
    cmd.type = PsCmdType::ROLE;
    return true;
  }
  if (strcmp(word, "pair") == 0) {
    if (arg != nullptr) {
      if (!psParseMac(arg, cmd.mac)) return fail(cmd, "bad_mac");
      cmd.macSet = true;
    }
    cmd.type = PsCmdType::PAIR;
    return true;
  }
  if (strcmp(word, "lab") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    if (strcmp(arg, "on") == 0) cmd.on = true;
    else if (strcmp(arg, "off") == 0) cmd.on = false;
    else return fail(cmd, "bad_arg");
    cmd.type = PsCmdType::LAB;
    return true;
  }
  if (strcmp(word, "axis") == 0) {
    if (arg == nullptr || strlen(arg) != 2 || (arg[0] != '+' && arg[0] != '-')) return fail(cmd, "bad_axis");
    int a = 0;
    if (arg[1] == 'x' || arg[1] == 'X') a = 1;
    else if (arg[1] == 'y' || arg[1] == 'Y') a = 2;
    else if (arg[1] == 'z' || arg[1] == 'Z') a = 3;
    else return fail(cmd, "bad_axis");
    cmd.axis = (int8_t)(arg[0] == '-' ? -a : a);
    cmd.type = PsCmdType::AXIS;
    return true;
  }
  if (strcmp(word, "channel") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    char* end = nullptr;
    const long ch = strtol(arg, &end, 10);
    if (end == arg || *end != '\0' || ch < 1 || ch > 13) return fail(cmd, "bad_channel");
    cmd.channel = (uint8_t)ch;
    cmd.type = PsCmdType::CHANNEL;
    return true;
  }
  if (strcmp(word, "home") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    // The rest of the line, verbatim, is the SSID ("none" clears it).
    const char* ssid = line + (arg - buf);
    size_t len = n - (size_t)(arg - buf);
    if (len > 32) return fail(cmd, "ssid_too_long");
    cmd.hasHomeSsid = true;
    if (len == 4 && memcmp(ssid, "none", 4) == 0) {
      cmd.homeSsid[0] = '\0';
    } else {
      memcpy(cmd.homeSsid, ssid, len);
      cmd.homeSsid[len] = '\0';
    }
    cmd.type = PsCmdType::HOME;
    return true;
  }
  if (strcmp(word, "wifi") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    char* pass = strchr(arg, ' ');
    if (pass != nullptr) {
      *pass++ = '\0';
      while (*pass == ' ') ++pass;
    }
    const size_t sl = strlen(arg);
    const size_t pl = pass != nullptr ? strlen(pass) : 0;
    if (sl > 32) return fail(cmd, "ssid_too_long");
    if (pl == 0 && strcmp(arg, "none") == 0) {
      cmd.type = PsCmdType::WIFI;  // forget
      return true;
    }
    if (pl != 0 && (pl < 8 || pl > 63)) return fail(cmd, "bad_password");
    memcpy(cmd.wifiSsid, arg, sl + 1);
    if (pl != 0) memcpy(cmd.wifiPass, pass, pl + 1);
    cmd.type = PsCmdType::WIFI;
    return true;
  }
  if (strcmp(word, "time") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    char* end = nullptr;
    const unsigned long long v = strtoull(arg, &end, 10);
    if (end == arg || *end != '\0' || v == 0) return fail(cmd, "bad_epoch_ms");
    cmd.epochMs = (uint64_t)v;
    cmd.type = PsCmdType::TIME;
    return true;
  }
  if (strcmp(word, "backlog") == 0) {
    uint32_t from = 0;
    if (arg != nullptr) {
      char* end = nullptr;
      const unsigned long long v = strtoull(arg, &end, 10);
      if (end == arg || *end != '\0' || v > 0xFFFFFFFFULL) return fail(cmd, "bad_from_seq");
      from = (uint32_t)v;
    }
    cmd.fromSeq = from;
    cmd.type = PsCmdType::BACKLOG;
    return true;
  }
  if (strcmp(word, "ack") == 0) {
    if (arg == nullptr) return fail(cmd, "missing_arg");
    char* end = nullptr;
    const unsigned long long v = strtoull(arg, &end, 10);
    if (end == arg || *end != '\0' || v > 0xFFFFFFFFULL) return fail(cmd, "bad_upto_seq");
    cmd.uptoSeq = (uint32_t)v;
    cmd.type = PsCmdType::ACK;
    return true;
  }
  if (strcmp(word, "unpair") == 0) return noArg(PsCmdType::UNPAIR);
  if (strcmp(word, "tare") == 0 || strcmp(word, "calibrate") == 0) return noArg(PsCmdType::TARE);
  if (strcmp(word, "status") == 0) return noArg(PsCmdType::STATUS);
  if (strcmp(word, "info") == 0) return noArg(PsCmdType::INFO);
  if (strcmp(word, "help") == 0) return noArg(PsCmdType::HELP);
  if (strcmp(word, "reboot") == 0) return noArg(PsCmdType::REBOOT);
  return fail(cmd, "unknown_cmd");
}

#endif  // PS_CMD_H
