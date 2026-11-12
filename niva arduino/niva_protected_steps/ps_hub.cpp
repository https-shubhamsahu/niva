// ps_hub.cpp - the ankle hub role (PROTOCOL.md "Ankle hub").
//
// Tasks:
//   imu task (core 1, or 0 on the single-core ESP32-C3; above loop): 100 Hz
//     IMU read (MPU6050 on the DevKit, LSM6DSO32 on the pod), IMU validity,
//     stride detector; strides go to loop() through a queue.
//   loop(): ESP-NOW receive and clock offset, matcher (P/U/X), log, home
//     scan, BLE GATT server and serial.

#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>

#include "ps_cmd.h"
#include "ps_device.h"
#include "ps_match.h"
#include "ps_record.h"
#include "ps_ringlog.h"
#include "ps_storage_littlefs.h"
#include "ps_stride.h"

// IMU setup for the hub (niva_board.h). Accelerometer +-16 g as FW-03. Gyro
// +-2000 dps (design choice: the insole's +-500 dps could clip mid-swing
// shank rotation, whose size on our wearers is to be measured). Both chips
// read +-32768 counts at full scale, so the saturation check is shared.
static const uint16_t HUB_GYRO_DPS = 2000;
static const int16_t HUB_SAT_RAW = 32000;     // design choice: "near full scale"
static const uint32_t HUB_SCAN_DEFER_MS = 600; // design choice, see matcherDeferred()
static const uint32_t HUB_SCAN_TIMEOUT_MS = 10000;

struct HubStrideMsg {
  uint32_t tMs;
  uint32_t peakMs;
  float peakDps;
  bool imuValid;
};

static QueueHandle_t strideQueue = nullptr;
static volatile uint8_t imuState = (uint8_t)PsVal::INVALID;
static volatile bool imuFaultPending = false;
static volatile int8_t axisSel = 3;
static volatile uint32_t stridesSinceBoot = 0;
static volatile float lastOmega = 0.0f;
static volatile float gyroBias = 0.0f;
static volatile bool imuPresent = false;

static PsLittleFsStorage storage;
static PsRingLog logBook;
static PsMatcher matcher;
static PsInsoleRx insole;
static int8_t homeFlag = PS_HOME_NULL;
static bool fsOk = false;

// Home scan.
static bool scanning = false;
static uint32_t scanStartedAt = 0, nextScanAt = 0, scanEndedAt = 0;
static bool scanEverEnded = false;

// Pairing window (long press or "pair" without an id).
static uint32_t pairWindowUntil = 0;
static uint32_t pairedAtMs = 0;

// BLE streaming.
static PsLogCursor streamCursor;
static bool backlogActive = false;
static bool backlogEndPending = false;
static uint32_t backlogLastSeq = 0;
static char oob[4][160];  // error / backlog_end messages waiting for Records
static uint8_t oobCount = 0;
static uint32_t lastStatusAt = 0;
static char infoCache[240] = {0};

// ------------------------------------------------------------- IMU task ---

static bool imuInit() { return nivaBoardImuBegin(HUB_GYRO_DPS); }
static bool imuRead(int16_t raw[6]) { return nivaBoardImuRead(raw); }

static void imuTask(void*) {
  PsStrideDetector det;
  det.begin();
  PsGyroBias bias;
  bias.reset();
  int8_t lastAxis = axisSel;
  PsImuValidity val;
  bool present = imuInit();
  imuPresent = present;
  val.begin(present, psNowMs());
  uint32_t lastInitTry = psNowMs();
  TickType_t last = xTaskGetTickCount();
  for (;;) {
    xTaskDelayUntil(&last, pdMS_TO_TICKS(10));  // 100 Hz
    const uint32_t now = psNowMs();
    if (!present) {
      if (now - lastInitTry >= 5000) {  // the IMU may have been reconnected
        lastInitTry = now;
        present = imuInit();
        imuPresent = present;
        if (present) val.begin(true, now);
      }
      imuState = (uint8_t)PsVal::INVALID;
      continue;
    }
    int16_t raw[6] = {0, 0, 0, 0, 0, 0};
    const bool ok = imuRead(raw);
    bool sat = false;
    for (int i = 0; ok && i < 6; ++i) sat = sat || raw[i] >= HUB_SAT_RAW || raw[i] <= -HUB_SAT_RAW;
    if (val.update(ok, sat, raw, now)) imuFaultPending = true;
    imuState = (uint8_t)val.state();
    if (val.state() == PsVal::INVALID) {
      det.reset();
      continue;
    }
    if (!ok) continue;
    const int8_t a = axisSel;
    if (a != lastAxis) {  // axis changed over serial: start again
      lastAxis = a;
      bias.reset();
      det.reset();
    }
    const int idx = 3 + (a < 0 ? -a : a) - 1;
    const float w = bias.update((a < 0 ? -1.0f : 1.0f) * raw[idx] / nivaBoardGyroLsbPerDps());
    lastOmega = w;
    gyroBias = bias.bias();
    PsStride s;
    if (det.update(w, now, s)) {
      HubStrideMsg m;
      m.tMs = s.tMs;
      m.peakMs = s.peakMs;
      m.peakDps = s.peakDps;
      m.imuValid = val.state() == PsVal::VALID;
      stridesSinceBoot = stridesSinceBoot + 1;
      xQueueSend(strideQueue, &m, 0);
    }
  }
}

// ------------------------------------------------------------------ log ---

class HubLogListener : public PsLogListener {
  void onLogged(const PsRecord& r) override {
    char json[200];
    if (psRecordToJson(r, json, sizeof(json)) > 0) psPrintLine(json);
  }
};
static HubLogListener logListener;

static void logRecord(PsRecord& r) {
  if (!fsOk) {
    // No file system: still give the record a seq-less serial line.
    char json[200];
    r.boot = psBootId;
    if (psRecordToJson(r, json, sizeof(json)) > 0) psPrintLine(json);
    return;
  }
  logBook.append(r, psNowMs());
}

static void logInsole(PsInsoleEvent ev, bool withId) {
  PsRecord r;
  r.type = PsRecType::INSOLE;
  r.ms = psNowMs();
  r.event = ev;
  r.batt = psCfg.insHeard ? psCfg.insBatt : PS_BATT_NONE;
  r.val = (PsVal)psCfg.insVal;
  r.hasId = withId;
  memcpy(r.id, psCfg.peer, 6);
  logRecord(r);
}

static void logGap(PsGapReason reason) {
  PsRecord r;
  r.type = PsRecType::GAP;
  r.ms = psNowMs();
  r.reason = reason;
  logRecord(r);
}

static void queueOob(const char* json) {
  psPrintLine(json);
  if (oobCount < 4) {
    strncpy(oob[oobCount], json, sizeof(oob[0]) - 1);
    oob[oobCount][sizeof(oob[0]) - 1] = '\0';
    oobCount++;
  }
}

static void sendError(const char* cmd, const char* reason) {
  char json[160];
  if (psErrorJson(cmd, reason, json, sizeof(json)) > 0) queueOob(json);
}

// ------------------------------------------------------------- insole -----

static PsInsoleView insoleView() {
  PsInsoleView v;
  v.paired = psCfg.peerSet;
  v.heard = psCfg.insHeard;
  v.batt = psCfg.insBatt;
  v.val = (PsVal)psCfg.insVal;
  return v;
}

static void setPaired(const uint8_t mac[6]) {
  const bool same = psCfg.peerSet && memcmp(psCfg.peer, mac, 6) == 0;
  memcpy(psCfg.peer, mac, 6);
  psCfg.peerSet = true;
  psSavePeer();
  psEspNowAddPeer(mac);
  if (!same) {
    // A different insole: nothing it reported before applies.
    psCfg.insHeard = false;
    psCfg.insBatt = PS_BATT_NONE;
    psCfg.insVal = (uint8_t)PsVal::INVALID;
    psSaveInsoleState();
    insole.resetLink();
  }
  pairedAtMs = psNowMs();
  pairWindowUntil = 0;
  logInsole(PsInsoleEvent::PAIRED, true);
}

static void sendPairAck(const uint8_t mac[6]) {
  PsPacket p;
  p.type = PsPktType::PAIR_ACK;
  p.boot = psBootId;
  p.txMs = psNowMs();
  p.channel = psEspNowChannel();
  uint8_t buf[PS_PKT_MAX];
  const size_t n = psPacketEncode(p, buf, sizeof(buf));
  if (n > 0) psEspNowSend(mac, buf, n);
}

static void handlePacket(const PsRxPacket& rx) {
  PsPacket p;
  if (!psPacketDecode(rx.data, rx.len, p)) return;
  const bool fromPaired = psCfg.peerSet && memcmp(rx.mac, psCfg.peer, 6) == 0;

  if (p.type == PsPktType::PAIR_REQ) {
    const bool windowOpen = pairWindowUntil != 0 && (int32_t)(pairWindowUntil - psNowMs()) > 0;
    if (fromPaired || windowOpen) {
      if (!fromPaired) setPaired(rx.mac);
      psEspNowAddPeer(rx.mac);
      sendPairAck(rx.mac);
    }
    return;
  }
  if (!fromPaired) return;

  insole.onPacket(p, rx.rxMs);
  if (p.type == PsPktType::HEARTBEAT) {
    const bool wasLow = psCfg.insHeard && psCfg.insBatt != PS_BATT_NONE && psCfg.insBatt < (int8_t)PS_BATT_LOW_PCT;
    psCfg.insHeard = true;
    psCfg.insBatt = p.batt;
    psCfg.insVal = (uint8_t)p.val;
    psSaveInsoleState();
    const bool low = p.batt != PS_BATT_NONE && p.batt < (int8_t)PS_BATT_LOW_PCT;
    logInsole(low && !wasLow ? PsInsoleEvent::BATTERY_LOW : PsInsoleEvent::HEARTBEAT, false);
  } else if (p.type == PsPktType::CONTACTS) {
    PsMatchOut out;
    for (uint8_t i = 0; i < p.n; ++i) {
      if (!insole.acceptContact(p.c[i].seq)) continue;  // a retry we already have
      uint32_t hubMs;
      if (!insole.clock.toHub(p.c[i].ms, hubMs)) continue;
      out.clear();
      matcher.addContact(hubMs, p.val, psNowMs(), out);
      for (uint8_t k = 0; k < out.n; ++k) {
        const PsMatchEvent& e = out.ev[k];
        PsRecord r;
        r.type = PsRecType::CONTACT;
        r.ms = e.c.tMs;
        r.late = e.c.late;
        r.val = e.c.val;
        logRecord(r);
      }
    }
  }
}

// --------------------------------------------------------------- matcher ---

static bool matcherDeferred(uint32_t now) {
  // While the radio is away scanning, ESP-NOW packets from the insole wait
  // for retries. Classification pauses during a scan and for
  // HUB_SCAN_DEFER_MS after it, so those contacts are not counted late.
  // This holds strides longer than settle_ms (a deviation, see README).
  if (scanning) return true;
  return scanEverEnded && (uint32_t)(now - scanEndedAt) < HUB_SCAN_DEFER_MS;
}

static void drainMatcher(PsMatchOut& out) {
  for (uint8_t k = 0; k < out.n; ++k) {
    const PsMatchEvent& e = out.ev[k];
    PsRecord r;
    if (e.isStride) {
      r.type = PsRecType::STRIDE;
      r.ms = e.s.tMs;
      r.cls = e.s.cls;
      r.home = e.s.home;
      int32_t dt = e.s.dt;
      if (dt > 32767) dt = 32767;
      if (dt < -32767) dt = -32767;
      r.dt = e.s.hasDt ? (int16_t)dt : PS_DT_NULL;
      r.peakDps = e.s.peakDps;
    } else {
      r.type = PsRecType::CONTACT;
      r.ms = e.c.tMs;
      r.late = e.c.late;
      r.val = e.c.val;
    }
    logRecord(r);
  }
  out.clear();
}

static void applyMatchParams() {
  PsMatchParams mp;
  mp.matchMs = psCfg.matchMs;
  mp.settleMs = psCfg.settleMs;
  matcher.setParams(mp);
}

// ------------------------------------------------------------ home scan ---

static void serviceHomeScan(uint32_t now) {
  if (!psCfg.home.configured()) {
    homeFlag = PS_HOME_NULL;
    return;
  }
  if (!scanning) {
    if ((int32_t)(now - nextScanAt) < 0) return;
    // Active scan, 60 ms per channel (design choice: keeps the radio away
    // from the ESP-NOW channel for about a second).
    if (WiFi.scanNetworks(true, false, false, 60) == WIFI_SCAN_FAILED) {
      homeFlag = PS_HOME_NULL;
      nextScanAt = now + psCfg.homeScanS * 1000UL;
      return;
    }
    scanning = true;
    scanStartedAt = now;
    return;
  }
  const int16_t n = WiFi.scanComplete();
  if (n == WIFI_SCAN_RUNNING && now - scanStartedAt < HUB_SCAN_TIMEOUT_MS) return;
  if (n >= 0) {
    static PsScanEntry entries[24];
    int k = 0;
    for (int i = 0; i < n && k < 24; ++i) {
      strncpy(entries[k].ssid, WiFi.SSID(i).c_str(), 32);
      entries[k].ssid[32] = '\0';
      const uint8_t* b = WiFi.BSSID(i);
      if (b) memcpy(entries[k].bssid, b, 6); else memset(entries[k].bssid, 0, 6);
      entries[k].rssi = WiFi.RSSI(i);
      ++k;
    }
    // More than 24 networks: check the rest without storing them.
    int8_t flag = psHomeFlag(psCfg.home, entries, k);
    for (int i = k; i < n && flag == 0; ++i) {
      if (WiFi.RSSI(i) > PS_HOME_RSSI_MIN_DBM && psCfg.home.ssid[0] && WiFi.SSID(i) == psCfg.home.ssid) flag = 1;
    }
    homeFlag = flag;
  } else {
    homeFlag = PS_HOME_NULL;  // failed or timed out: unknown, not "away"
  }
  WiFi.scanDelete();
  psEspNowSetChannel(psCfg.channel);  // back to the insole's channel
  scanning = false;
  scanEndedAt = now;
  scanEverEnded = true;
  nextScanAt = now + psCfg.homeScanS * 1000UL;
}

// ------------------------------------------------------------- commands ---

static void printInfo() {
  char json[240];
  if (psInfoJson(PsRole::ANKLE, psBootId, psMac, psBatteryPercent(), "insole", psCfg.peerSet, psCfg.peer, json, sizeof(json)) > 0) {
    psPrintLine(json);
  }
}

static size_t buildStatus(char* json, size_t cap) {
  PsHubStatus s;
  s.ms = psNowMs();
  s.batt = psBatteryPercent();
  s.val = (PsVal)imuState;
  s.home = homeFlag;
  s.strides = stridesSinceBoot;
  s.paired = psCfg.peerSet;
  memcpy(s.insoleId, psCfg.peer, 6);
  s.seen = insole.seen;
  s.seenMs = insole.lastRxMs;
  s.insoleBatt = psCfg.insBatt;
  s.insoleHeard = psCfg.insHeard;
  s.insoleVal = (PsVal)psCfg.insVal;
  return psHubStatusJson(s, json, cap);
}

static void serialBacklog(uint32_t from) {
  if (!fsOk) { sendError("backlog", "no_storage"); return; }
  logBook.flush(psNowMs());
  PsLogCursor c;
  c.nextSeq = from;
  PsRecord recs[8];
  int n;
  uint32_t last = from > 0 ? from - 1 : 0;
  char json[200];
  while ((n = logBook.read(c, recs, 8)) > 0) {
    for (int i = 0; i < n; ++i) {
      if (psRecordToJson(recs[i], json, sizeof(json)) > 0) psPrintLine(json);
      last = recs[i].seq;
    }
  }
  if (psBacklogEndJson(last, json, sizeof(json)) > 0) psPrintLine(json);
}

static void handleCommand(const PsCommand& c, bool fromBle) {
  switch (c.type) {
    case PsCmdType::NONE:
      return;
    case PsCmdType::ERROR:
      sendError(c.name[0] ? c.name : "?", c.reason);
      return;
    case PsCmdType::BACKLOG:
      if (fromBle) {
        if (fsOk) logBook.flush(psNowMs());
        streamCursor.nextSeq = c.fromSeq;
        backlogActive = true;
        backlogEndPending = false;
      } else {
        serialBacklog(c.fromSeq);
      }
      return;
    case PsCmdType::ACK:
      if (fsOk) logBook.ack(c.uptoSeq);
      return;
    case PsCmdType::CONFIG:
    case PsCmdType::HOME: {
      const uint32_t match = c.hasMatchMs ? c.matchMs : psCfg.matchMs;
      const uint32_t settle = c.hasSettleMs ? c.settleMs : psCfg.settleMs;
      if (settle < match) { sendError(c.name, "settle_lt_match"); return; }
      psCfg.matchMs = match;
      psCfg.settleMs = settle;
      if (c.hasHomeScanS) psCfg.homeScanS = c.homeScanS;
      if (c.hasHomeSsid) strncpy(psCfg.home.ssid, c.homeSsid, sizeof(psCfg.home.ssid));
      if (c.hasHomeBssid) memcpy(psCfg.home.bssid, c.homeBssid, 6);
      psSaveMatchConfig();
      applyMatchParams();
      if (c.hasHomeSsid || c.hasHomeBssid || c.hasHomeScanS) nextScanAt = psNowMs();  // scan now
      psPrintNote("config match_ms=%lu settle_ms=%lu home_scan_s=%lu home_ssid=\"%s\"",
                  (unsigned long)psCfg.matchMs, (unsigned long)psCfg.settleMs,
                  (unsigned long)psCfg.homeScanS, psCfg.home.ssid);
      return;
    }
    case PsCmdType::PAIR:
      if (c.macSet) {
        setPaired(c.mac);
        psPrintNote("paired with insole %02X%02X%02X%02X%02X%02X", c.mac[0], c.mac[1], c.mac[2], c.mac[3], c.mac[4], c.mac[5]);
      } else {
        pairWindowUntil = psNowMs() + PS_PAIR_WINDOW_MS;
        psPrintNote("pairing window open for %lu s: long-press the insole button", (unsigned long)(PS_PAIR_WINDOW_MS / 1000));
      }
      return;
    case PsCmdType::UNPAIR:
      if (psCfg.peerSet) {
        logInsole(PsInsoleEvent::UNPAIRED, true);
        psCfg.peerSet = false;
        psSavePeer();
        psCfg.insHeard = false;
        psCfg.insBatt = PS_BATT_NONE;
        psCfg.insVal = (uint8_t)PsVal::INVALID;
        psSaveInsoleState();
        insole.resetLink();
      }
      return;
    case PsCmdType::TIME: {
      PsRecord r;
      r.type = PsRecType::SYNC;
      r.ms = psNowMs();
      r.epochMs = c.epochMs;
      logRecord(r);
      return;
    }
    case PsCmdType::ROLE:
      psCfg.role = c.role;
      psSaveRole();
      if (fsOk) logBook.flush(psNowMs());
      psPrintNote("role set to %s; rebooting", psRoleText(c.role));
      delay(100);
      ESP.restart();
      return;
    case PsCmdType::AXIS:
      psCfg.axis = c.axis;
      axisSel = c.axis;
      psSaveAxis();
      psPrintNote("axis %c%c", c.axis < 0 ? '-' : '+', "xyz"[(c.axis < 0 ? -c.axis : c.axis) - 1]);
      return;
    case PsCmdType::CHANNEL:
      psCfg.channel = c.channel;
      psSaveChannel();
      psEspNowSetChannel(c.channel);
      psPrintNote("ESP-NOW channel %u", (unsigned)c.channel);
      return;
    case PsCmdType::STATUS: {
      char json[240];
      if (buildStatus(json, sizeof(json)) > 0) psPrintLine(json);
      psPrintNote("imu=%s omega=%.1f dps gyro_offset=%.1f dps axis=%d log_records=%lu oldest=%lu last=%lu acked=%lu segments=%u fs_used=%u/%u ch=%u pending_strides=%u pending_contacts=%u",
                  psValText((PsVal)imuState), (double)lastOmega, (double)gyroBias, (int)psCfg.axis,
                  (unsigned long)(fsOk ? logBook.storedRecords() : 0), (unsigned long)(fsOk ? logBook.oldestSeq() : 0),
                  (unsigned long)(fsOk ? logBook.lastSeq() : 0), (unsigned long)(fsOk ? logBook.ackedUpto() : 0),
                  (unsigned)(fsOk ? logBook.segments() : 0), (unsigned)(fsOk ? storage.usedBytes() : 0),
                  (unsigned)(fsOk ? storage.totalBytes() : 0), (unsigned)psEspNowChannel(),
                  (unsigned)matcher.pendingStrides(), (unsigned)matcher.pendingContacts());
      psPrintWifi("status");
      return;
    }
    case PsCmdType::INFO:
      printInfo();
      psPrintWifi("info");
      return;
    case PsCmdType::WIFI:
      if (!psWifiStore(c.wifiSsid, c.wifiPass)) { sendError("wifi", "store_failed"); return; }
      psPrintWifi(c.wifiSsid[0] ? "saved" : "forgotten");
      psPrintNote("stored for lab mode in the insole role; the hub only scans and never joins");
      return;
    case PsCmdType::HELP:
      psPrintNote("ankle hub commands: role ankle|insole, pair [<insole mac>], unpair, axis +x|-x|+y|-y|+z|-z, channel <1-13>, home <ssid>|none, time <epoch_ms>, backlog [from_seq], ack <seq>, wifi <ssid> [<password>]|none, status, info, reboot; or PROTOCOL.md JSON");
      return;
    case PsCmdType::REBOOT:
      if (fsOk) logBook.flush(psNowMs());
      ESP.restart();
      return;
    case PsCmdType::TARE:
    case PsCmdType::LAB:
      sendError(c.name, "insole_only");
      return;
  }
}

// ----------------------------------------------------------------- BLE ----

static void serviceBle(uint32_t now) {
  if (psBleTakeConnectEvent()) {
    // Live records start from now; older ones come with "backlog".
    streamCursor.nextSeq = fsOk ? logBook.lastSeq() + 1 : 0;
    backlogActive = false;
    backlogEndPending = false;
    oobCount = 0;
  }
  PsBleIncoming in;
  while (psBleTakeIncoming(in)) {
    if (in.isTime) {
      uint64_t epoch;
      if (psParseTimeWrite(in.text, in.len, epoch)) {
        PsCommand c;
        c.type = PsCmdType::TIME;
        c.epochMs = epoch;
        handleCommand(c, true);
      } else {
        sendError("time", "malformed");
      }
    } else {
      PsCommand c;
      psParseJsonCommand(in.text, in.len, c);
      handleCommand(c, true);
    }
  }
  if (!psBleConnected()) return;

  // Info is cached and refreshed only when it changes.
  char info[240];
  if (psInfoJson(PsRole::ANKLE, psBootId, psMac, psBatteryPercent(), "insole", psCfg.peerSet, psCfg.peer, info, sizeof(info)) > 0 &&
      strcmp(info, infoCache) != 0) {
    strcpy(infoCache, info);
    psBleSetInfo(info);
  }

  if (now - lastStatusAt >= 1000) {
    lastStatusAt = now;
    char json[240];
    if (buildStatus(json, sizeof(json)) > 0) psBleNotifyStatus(json);
  }

  if (!psBleRecordsSubscribed()) return;
  // Out-of-band messages first (errors).
  while (oobCount > 0) {
    if (!psBleNotifyRecord(oob[0])) return;
    for (uint8_t i = 1; i < oobCount; ++i) strcpy(oob[i - 1], oob[i]);
    oobCount--;
  }
  if (!fsOk) return;
  // Records from the cursor: a backlog, then the live stream. A record is
  // only passed once its notification was accepted.
  PsRecord recs[4];
  PsLogCursor c = streamCursor;
  const int n = logBook.read(c, recs, 4);
  char json[200];
  for (int i = 0; i < n; ++i) {
    if (psRecordToJson(recs[i], json, sizeof(json)) == 0 || !psBleNotifyRecord(json)) return;
    streamCursor.nextSeq = recs[i].seq + 1;
  }
  if (n == 0 && backlogActive) {
    backlogActive = false;
    backlogEndPending = true;
    backlogLastSeq = streamCursor.nextSeq > 0 ? streamCursor.nextSeq - 1 : 0;
  }
  if (backlogEndPending) {
    if (psBacklogEndJson(backlogLastSeq, json, sizeof(json)) > 0 && psBleNotifyRecord(json)) backlogEndPending = false;
  }
}

// --------------------------------------------------------------- public ---

void psHubSetup() {
  axisSel = psCfg.axis;
  strideQueue = xQueueCreate(16, sizeof(HubStrideMsg));
  psBatteryBegin();

  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.disconnect(false, false);  // scan only: never join a network
  if (!psEspNowBegin(psCfg.channel)) psPrintNote("ESP-NOW init failed");
  if (psCfg.peerSet) psEspNowAddPeer(psCfg.peer);

  fsOk = storage.begin();
  if (fsOk) {
    const size_t segBytes = 256 * PS_REC_BYTES;  // 8 KB segments (design choice)
    // Keep a quarter of the file system free for LittleFS's own blocks.
    uint32_t maxSeg = (uint32_t)(storage.totalBytes() * 3 / 4 / segBytes);
    if (maxSeg > PsRingLog::kMaxSegments) maxSeg = PsRingLog::kMaxSegments;
    const bool hadLog = psCfg.seqReserved > 0;
    logBook.begin(&storage, &logListener, psBootId, 256, (uint16_t)maxSeg, psCfg.seqReserved, psCfg.acked, psNowMs());
    if (hadLog) logGap(PsGapReason::REBOOT);
    psPrintNote("log: %lu records stored, seq %lu..%lu, %lu segments max, LittleFS %u of %u bytes used",
                (unsigned long)logBook.storedRecords(), (unsigned long)logBook.oldestSeq(),
                (unsigned long)logBook.lastSeq(), (unsigned long)maxSeg,
                (unsigned)storage.usedBytes(), (unsigned)storage.totalBytes());
  } else {
    psPrintNote("LittleFS failed: records go to serial only and are NOT stored");
  }

  PsMatchParams mp;
  mp.matchMs = psCfg.matchMs;
  mp.settleMs = psCfg.settleMs;
  matcher.begin(mp);
  insole.clock.begin();
  pairedAtMs = psNowMs();
  nextScanAt = psNowMs() + 2000;

  psBleBegin(true, false);
  xTaskCreatePinnedToCore(imuTask, "ps_imu", 4096, nullptr, 5, nullptr, NIVA_TASK_CORE);
  printInfo();
}

void psHubLoop() {
  const uint32_t now = psNowMs();

  if (const char* line = psSerialPoll()) {
    PsCommand c;
    psParseSerialLine(line, c);
    handleCommand(c, false);
  }

  PsRxPacket rx;
  for (int i = 0; i < 8 && psEspNowReceive(rx); ++i) handlePacket(rx);

  PsMatchOut out;
  HubStrideMsg m;
  while (xQueueReceive(strideQueue, &m, 0) == pdTRUE) {
    const bool unknown = PsMatcher::unknownAt(insoleView(), m.imuValid, matcher.params());
    float pk = m.peakDps;
    if (pk < 0) pk = 0;
    if (pk > 65535) pk = 65535;
    matcher.addStride(m.tMs, (uint16_t)pk, homeFlag, unknown, out);
    drainMatcher(out);
  }
  if (!matcherDeferred(now)) {
    matcher.poll(now, out);
    drainMatcher(out);
  }

  if (psCfg.peerSet && insole.checkLost(now, pairedAtMs)) logInsole(PsInsoleEvent::LOST, false);
  if (imuFaultPending) {
    imuFaultPending = false;
    logGap(PsGapReason::IMU_FAULT);
  }

  serviceHomeScan(now);
  if (fsOk) logBook.flushIfDue(now);
  serviceBle(now);

  const int b = psButtonPoll();
  if (b == 2) {
    pairWindowUntil = now + PS_PAIR_WINDOW_MS;
    psPrintNote("pairing window open for %lu s", (unsigned long)(PS_PAIR_WINDOW_MS / 1000));
  }

  // LED: fast blink while pairing, on while a phone is connected. The pod's
  // red LED shows an IMU that is not VALID.
  const bool pairing = pairWindowUntil != 0 && (int32_t)(pairWindowUntil - now) > 0;
  nivaBoardStatusLed(pairing ? ((now / 125) & 1) : psBleConnected());
  nivaBoardFaultLed(imuState != (uint8_t)PsVal::VALID);

  if (psPowerCheck()) {
    if (fsOk) logBook.flush(now);
    psDeepSleep();
  }
  delay(2);
}
