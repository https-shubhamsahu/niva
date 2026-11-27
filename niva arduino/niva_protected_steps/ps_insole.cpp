// ps_insole.cpp - the insole node role (PROTOCOL.md "Insole node").
//
// Acquisition and the contact detector are niva_acq.h / niva_signal.h, the
// same code as niva_hardware. Each foot-load edge (F+) becomes a contact
// that is sent to the paired hub over ESP-NOW and resent until the hub's
// radio acknowledges it. A heartbeat goes every 30 s and whenever validity
// changes. Lab mode adds the niva_hardware telemetry (WebSocket :81, JSON
// frames on serial, legacy BLE service), unchanged.

#include <Arduino.h>
#include <ESPmDNS.h>
#include <WebSocketsServer.h>
#include <WiFi.h>
#include <WiFiManager.h>
#include <Wire.h>

#include "niva_acq.h"
#include "niva_frame.h"
#include "niva_signal.h"
#include "ps_cmd.h"
#include "ps_device.h"
#include "ps_logic.h"
#include "ps_packet.h"
#include "ps_record.h"

// Design choices.
static const float AUTO_TARE_TOL_COUNTS = 150.0f;  // max |zero - reference| per channel
static const uint32_t AUTO_TARE_STABLE_MS = 2000;
static const uint32_t AUTO_TARE_RETRY_MS = 10000;
static const uint32_t DEGRADED_HOLD_MS = PS_HEARTBEAT_MS;
static const uint32_t MIN_FSR_PER_SEC = 90;   // of 100 expected
static const uint8_t CHANNEL_SEARCH_FAILS = 6;
static const uint32_t SEND_TIMEOUT_MS = 200;
static const uint32_t PAIR_REQ_EVERY_MS = 200;
static const uint16_t WS_PORT = 81;
static const uint32_t LAB_JOIN_WAIT_MS = 12000;  // a phone hotspot can take several seconds

static NivaAcquisition acq;
static bool imuAvailable = false;

// Contacts and link.
static PsOutbox outbox;
static uint32_t contactSeq = 0;
static uint32_t pktSeq = 0;
enum class InFlight : uint8_t { NONE, CONTACTS, HEARTBEAT, PAIR_REQ };
static InFlight inFlight = InFlight::NONE;
static uint32_t inFlightSince = 0;
static bool hbPending = true;
static uint32_t hbRetryMs = PsOutbox::kRetryMinMs, hbNextTry = 0, lastHbAt = 0;
static uint8_t failStreak = 0;
static bool everAcked = false;
static uint32_t lastAckAt = 0;
static PsVal reportedVal = PsVal::INVALID;

// Pairing window.
static bool pairing = false;
static uint32_t pairUntil = 0, nextPairReqAt = 0;

// Tare.
static bool explicitTarePending = false;  // the running tare was asked for
static bool autoTareRunning = false;
static uint32_t stableSince = 0, nextAutoTareAt = 0;

// Validity tracking.
static uint32_t degradedUntil = 0;
static uint32_t lastDroppedTotal = 0;
static uint32_t lastTareGen = 0;
static NivaAcqStats lastStats = {0, 0, 0, 0, 0, 0, 0};
static uint32_t lastRateAt = 0;

// Lab mode.
static WebSocketsServer* ws = nullptr;
static WiFiManager* wm = nullptr;
static bool mdnsStarted = false;
static NivaContactQueue frameEvents;
static uint32_t frameTareGen = 0;
static uint32_t lastFrameUs = 0;
static float lastPiezo = 0.0f;

static uint32_t lastStatusAt = 0;
static char infoCache[240] = {0};

// --------------------------------------------------------------- helpers ---

static bool staConnected() { return WiFi.status() == WL_CONNECTED; }

// Pod only: the insole tail as seen on MCP3208 CH6 / CH7 (niva_board.h).
// The DevKit reports NOT_SENSED and the check is skipped.
static NivaTailResult tail = {NivaTail::NOT_SENSED, '?'};
static uint32_t tailCheckedAt = 0;

static void serviceTail(uint32_t now) {
  if (tailCheckedAt != 0 && now - tailCheckedAt < 1000) return;   // 1 Hz (design choice)
  tailCheckedAt = now ? now : 1;
  const NivaTailResult r = nivaBoardTail();
  if (r.state == tail.state && r.side == tail.side) return;
  tail = r;
  char line[80];
  snprintf(line, sizeof(line), "{\"t\":\"tail\",\"ms\":%lu,\"state\":\"%s\",\"side\":\"%c\"}", (unsigned long)now,
           nivaTailText(r.state), r.side);
  psPrintLine(line);
}

static PsVal currentVal(uint32_t now) {
  if (acq.validity() != NivaAcqValidity::valid) return PsVal::INVALID;
  // No insert, a shorted tail or an unknown insert: the insole cannot measure.
  if (tail.state != NivaTail::NOT_SENSED && tail.state != NivaTail::OK) return PsVal::INVALID;
  if ((int32_t)(degradedUntil - now) > 0) return PsVal::DEGRADED;
  return PsVal::VALID;
}

static void broadcastLab(const char* line) {
  if (ws) ws->broadcastTXT(line);
}

static void requestExplicitTare() {
  explicitTarePending = true;
  autoTareRunning = false;
  acq.requestTare();
  psPrintNote("TARE: keep the insole unloaded until the tare completes");
}

static void updateDegraded(uint32_t now) {
  NivaAcqSnapshot s;
  acq.snapshot(s);  // note: consumes the piezo peak; only used outside lab mode
  if (s.tareGeneration != lastTareGen) {
    lastTareGen = s.tareGeneration;
    lastDroppedTotal = 0;
  }
  const uint32_t dropped = s.eventsDropped + outbox.dropped() + frameEvents.dropped();
  if (dropped > lastDroppedTotal) {
    lastDroppedTotal = dropped;
    degradedUntil = now + DEGRADED_HOLD_MS;
  }
  if (now - lastRateAt >= 1000) {
    const NivaAcqStats st = acq.stats();
    const uint32_t fsr = st.fsrSamples - lastStats.fsrSamples;
    const uint32_t elapsed = now - lastRateAt;
    if (lastRateAt != 0 && fsr * 1000 < MIN_FSR_PER_SEC * elapsed) degradedUntil = now + DEGRADED_HOLD_MS;
    lastStats = st;
    lastRateAt = now;
  }
}

// ------------------------------------------------------------ ESP-NOW -----

static void onLinkResult(bool ok, uint32_t now) {
  if (ok) {
    failStreak = 0;
    lastAckAt = now;
    if (!everAcked) psPrintNote("hub acknowledged on channel %u", (unsigned)psEspNowChannel());
    everAcked = true;
    const uint8_t ch = psEspNowChannel();
    if (ch != psCfg.channel && ch >= 1 && ch <= 13) {
      psCfg.channel = ch;
      psSaveChannel();
    }
    return;
  }
  if (++failStreak >= CHANNEL_SEARCH_FAILS && !staConnected()) {
    // Not heard by the hub: try the next channel (the hub stays on one).
    failStreak = 0;
    const uint8_t ch = psEspNowChannel();
    psEspNowSetChannel((uint8_t)(ch >= 13 || ch < 1 ? 1 : ch + 1));
    everAcked = false;
  }
}

static bool sendPacket(const uint8_t mac[6], PsPacket& p, InFlight kind, uint32_t now) {
  p.boot = psBootId;
  p.pktSeq = ++pktSeq;
  p.txMs = now;
  uint8_t buf[PS_PKT_MAX];
  const size_t n = psPacketEncode(p, buf, sizeof(buf));
  if (n == 0) return false;
  psPacketStamp(buf, n, psNowMs());  // stamp as late as possible
  if (!psEspNowSend(mac, buf, n)) return false;
  inFlight = kind;
  inFlightSince = now;
  return true;
}

static void finishSend(bool ok, uint32_t now) {
  switch (inFlight) {
    case InFlight::CONTACTS:
      outbox.sent(ok, now);
      onLinkResult(ok, now);
      break;
    case InFlight::HEARTBEAT:
      if (ok) {
        hbPending = false;
        hbRetryMs = PsOutbox::kRetryMinMs;
      } else {
        hbNextTry = now + hbRetryMs;
        hbRetryMs = hbRetryMs * 2 > PsOutbox::kRetryMaxMs ? PsOutbox::kRetryMaxMs : hbRetryMs * 2;
      }
      onLinkResult(ok, now);
      break;
    default:
      break;  // broadcast pair requests are never acknowledged
  }
  inFlight = InFlight::NONE;
}

static void serviceLink(uint32_t now) {
  const int r = psEspNowTakeSendResult();
  if (inFlight != InFlight::NONE) {
    if (r >= 0) finishSend(r == 1, now);
    else if (now - inFlightSince > SEND_TIMEOUT_MS) finishSend(false, now);
    else return;
  }

  // Incoming: only PAIR_ACK matters to the insole.
  PsRxPacket rx;
  while (psEspNowReceive(rx)) {
    PsPacket p;
    if (!psPacketDecode(rx.data, rx.len, p) || p.type != PsPktType::PAIR_ACK) continue;
    if (!pairing && !(psCfg.peerSet && memcmp(rx.mac, psCfg.peer, 6) == 0)) continue;
    memcpy(psCfg.peer, rx.mac, 6);
    psCfg.peerSet = true;
    psSavePeer();
    psEspNowAddPeer(rx.mac);
    psCfg.channel = psEspNowChannel();
    psSaveChannel();
    pairing = false;
    hbPending = true;
    hbNextTry = now;
    char id[13];
    psMacToHex(rx.mac, id);
    psPrintNote("paired with hub %s on channel %u", id, (unsigned)psCfg.channel);
  }

  if (pairing) {
    if ((int32_t)(now - pairUntil) >= 0) {
      pairing = false;
      psPrintNote("pairing window closed without an answer");
      if (!staConnected()) psEspNowSetChannel(psCfg.channel);
    } else if ((int32_t)(now - nextPairReqAt) >= 0) {
      nextPairReqAt = now + PAIR_REQ_EVERY_MS;
      if (!staConnected()) {
        const uint8_t ch = psEspNowChannel();
        psEspNowSetChannel((uint8_t)(ch >= 13 || ch < 1 ? 1 : ch + 1));
      }
      static const uint8_t bcast[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
      PsPacket p;
      p.type = PsPktType::PAIR_REQ;
      sendPacket(bcast, p, InFlight::PAIR_REQ, now);
    }
    return;
  }
  if (!psCfg.peerSet) return;

  if (hbPending && (int32_t)(now - hbNextTry) >= 0) {
    PsPacket p;
    p.type = PsPktType::HEARTBEAT;
    p.batt = psBatteryPercent();
    p.val = reportedVal;
    p.channel = psEspNowChannel();
    p.dropped = outbox.dropped();
    if (sendPacket(psCfg.peer, p, InFlight::HEARTBEAT, now)) return;
    inFlight = InFlight::HEARTBEAT;  // could not even be queued: back off like a lost send
    finishSend(false, now);
  }
  PsPacket p;
  if (outbox.due(now, p)) {
    p.val = reportedVal;
    p.batt = psBatteryPercent();
    if (!sendPacket(psCfg.peer, p, InFlight::CONTACTS, now)) outbox.abort(now);
  }
}

// ------------------------------------------------------------- contacts ---

static void serviceContacts(uint32_t now) {
  NivaAcqSnapshot s;
  NivaContactEvent ev[NivaContactQueue::kCapacity];
  const uint8_t n = acq.popEvents(ev, NivaContactQueue::kCapacity);
  for (uint8_t i = 0; i < n; ++i) {
    if (psCfg.lab) frameEvents.push(ev[i]);
    if (ev[i].channel != NIVA_FOOT || ev[i].edge != NIVA_EDGE_ON) continue;
    const uint32_t ms = (uint32_t)ev[i].tMs;
    ++contactSeq;
    if (psCfg.peerSet) outbox.push(contactSeq, ms);
    char line[96];
    snprintf(line, sizeof(line), "{\"t\":\"contact\",\"seq\":%lu,\"ms\":%lu,\"val\":\"%s\"}",
             (unsigned long)contactSeq, (unsigned long)ms, psValText(currentVal(now)));
    psPrintLine(line);
    broadcastLab(line);
  }
  (void)s;
}

// ----------------------------------------------------------------- tare ---

static void serviceTare(uint32_t now) {
  NivaTareReport rep;
  if (acq.takeTareReport(rep)) {
    if (autoTareRunning) {
      autoTareRunning = false;
      int worst = -1;
      float worstDiff = 0.0f;
      for (int i = 0; i < 4; ++i) {
        const float d = fabsf(rep.zero[i] - psCfg.refZero[i]);
        if (d > AUTO_TARE_TOL_COUNTS && d > worstDiff) { worst = i; worstDiff = d; }
      }
      if (worst >= 0) {
        acq.invalidate();
        nextAutoTareAt = now + AUTO_TARE_RETRY_MS;
        psPrintNote("auto-tare rejected: channel %d is %.0f counts from the reference (loaded?); retrying in %lu s",
                    worst, (double)worstDiff, (unsigned long)(AUTO_TARE_RETRY_MS / 1000));
        return;
      }
      psPrintNote("auto-tare accepted");
    } else {
      // An explicit tare becomes the reference for later automatic tares.
      for (int i = 0; i < 4; ++i) psCfg.refZero[i] = rep.zero[i];
      psCfg.refSet = true;
      psSaveRef();
      explicitTarePending = false;
      psPrintNote("TARE complete; zeros stored as the auto-tare reference");
    }
    psPrintNote("zero heel=%.0f inner=%.0f outer=%.0f toe=%.0f; contact noise floor %.1f %.1f %.1f %.1f",
                (double)rep.zero[0], (double)rep.zero[1], (double)rep.zero[2], (double)rep.zero[3],
                (double)rep.noise[0], (double)rep.noise[1], (double)rep.noise[2], (double)rep.noise[3]);
    return;
  }
  // Outside lab mode the insole tares itself, but only when the unloaded
  // signal agrees with the last explicit tare (a tare under load would hide
  // every later contact).
  if (psCfg.lab || !psCfg.refSet || autoTareRunning || explicitTarePending) return;
  if (acq.validity() != NivaAcqValidity::uncalibrated || (int32_t)(now - nextAutoTareAt) < 0) return;
  if (!acq.loadStable()) { stableSince = 0; return; }
  if (stableSince == 0) stableSince = now ? now : 1;
  if (now - stableSince >= AUTO_TARE_STABLE_MS) {
    stableSince = 0;
    autoTareRunning = true;
    acq.requestTare();
  }
}

// ------------------------------------------------------------- commands ---

static void printInfo() {
  char json[240];
  if (psInfoJson(PsRole::INSOLE, psBootId, psMac, psBatteryPercent(), "hub", psCfg.peerSet, psCfg.peer, json, sizeof(json)) > 0) {
    psPrintLine(json);
  }
}

static size_t buildStatus(char* json, size_t cap, uint32_t now) {
  PsOut o(json, cap);
  o.raw("{\"t\":\"status\",\"ms\":");
  o.u64(now);
  o.raw(",\"batt\":");
  const int8_t b = psBatteryPercent();
  if (b == PS_BATT_NONE) o.raw("null"); else o.i64(b);
  o.raw(",\"val\":\"");
  o.raw(psValText(currentVal(now)));
  o.raw("\",\"acq\":\"");
  o.raw(nivaAcqValidityText(acq.validity()));
  o.raw("\",\"hub\":");
  if (psCfg.peerSet) {
    char id[13];
    psMacToHex(psCfg.peer, id);
    o.raw("{\"id\":\"");
    o.raw(id);
    o.raw("\",\"acked_ms\":");
    if (everAcked) o.u64(lastAckAt); else o.raw("null");
    o.raw("}");
  } else {
    o.raw("null");
  }
  o.raw(",\"contacts_since_boot\":");
  o.u64(contactSeq);
  o.raw(",\"pending\":");
  o.u64(outbox.size());
  o.raw(",\"dropped\":");
  o.u64(outbox.dropped());
  o.raw(",\"ch\":");
  o.u64(psEspNowChannel());
  o.raw(",\"lab\":");
  o.raw(psCfg.lab ? "true" : "false");
  o.raw("}");
  return o.ok() ? o.len : 0;
}

static void handleCommand(const PsCommand& c) {
  char json[200];
  switch (c.type) {
    case PsCmdType::NONE:
      return;
    case PsCmdType::ERROR:
      if (psErrorJson(c.name[0] ? c.name : "?", c.reason, json, sizeof(json)) > 0) psPrintLine(json);
      return;
    case PsCmdType::TARE:
      requestExplicitTare();
      return;
    case PsCmdType::PAIR:
      if (c.macSet) {
        memcpy(psCfg.peer, c.mac, 6);
        psCfg.peerSet = true;
        psSavePeer();
        psEspNowAddPeer(c.mac);
        hbPending = true;
        everAcked = false;
        psPrintNote("hub set to %02X%02X%02X%02X%02X%02X", c.mac[0], c.mac[1], c.mac[2], c.mac[3], c.mac[4], c.mac[5]);
      } else {
        pairing = true;
        pairUntil = psNowMs() + PS_PAIR_WINDOW_MS;
        nextPairReqAt = psNowMs();
        psPrintNote("pairing for %lu s: open the hub's pairing window too", (unsigned long)(PS_PAIR_WINDOW_MS / 1000));
      }
      return;
    case PsCmdType::UNPAIR:
      psCfg.peerSet = false;
      psSavePeer();
      outbox.reset();
      psPrintNote("unpaired");
      return;
    case PsCmdType::ROLE:
      psCfg.role = c.role;
      psSaveRole();
      psPrintNote("role set to %s; rebooting", psRoleText(c.role));
      delay(100);
      ESP.restart();
      return;
    case PsCmdType::LAB:
      psCfg.lab = c.on;
      psSaveLab();
      psPrintNote("lab mode %s; rebooting", c.on ? "on" : "off");
      delay(100);
      ESP.restart();
      return;
    case PsCmdType::CHANNEL:
      psCfg.channel = c.channel;
      psSaveChannel();
      if (!psEspNowSetChannel(c.channel)) psPrintNote("channel not changed (connected to Wi-Fi?)");
      return;
    case PsCmdType::STATUS: {
      if (buildStatus(json, sizeof(json), psNowMs()) > 0) psPrintLine(json);
      const NivaAcqStats st = acq.stats();
      float raw[4];
      acq.lastRaw(raw);
      psPrintNote("ms=%lu raw heel=%.0f inner=%.0f outer=%.0f toe=%.0f; counters piezo=%lu fsr=%lu imu=%lu imuFail=%lu overruns=%lu burstUs last=%lu max=%lu; imu=%s",
                  (unsigned long)psNowMs(), (double)raw[0], (double)raw[1], (double)raw[2], (double)raw[3],
                  (unsigned long)st.piezoSamples, (unsigned long)st.fsrSamples, (unsigned long)st.imuReads,
                  (unsigned long)st.imuFailures, (unsigned long)st.overruns, (unsigned long)st.burstUsLast,
                  (unsigned long)st.burstUsMax, imuAvailable ? "yes" : "no");
      psPrintWifi("status");
      return;
    }
    case PsCmdType::INFO:
      printInfo();
      psPrintWifi("info");
      return;
    case PsCmdType::WIFI:
      if (!psWifiStore(c.wifiSsid, c.wifiPass)) {
        if (psErrorJson("wifi", "store_failed", json, sizeof(json)) > 0) psPrintLine(json);
        return;
      }
      psPrintWifi(c.wifiSsid[0] ? "saved" : "forgotten");
      if (psCfg.lab) {
        psPrintNote("rebooting to join the new network");
        delay(100);
        ESP.restart();
      } else {
        psPrintNote("stored; lab mode joins it ('lab on')");
      }
      return;
    case PsCmdType::HELP:
      psPrintNote("insole commands: role ankle|insole, pair [<hub mac>], unpair, tare, lab on|off, wifi <ssid> [<password>]|none, channel <1-13>, status, info, reboot");
      return;
    case PsCmdType::REBOOT:
      ESP.restart();
      return;
    default:
      if (psErrorJson(c.name, "hub_only", json, sizeof(json)) > 0) psPrintLine(json);
      return;
  }
}

static void handleLine(const char* line) {
  // niva_hardware accepted {"cmd":"tare"}; keep that working here.
  if (strstr(line, "\"tare\"") != nullptr) { requestExplicitTare(); return; }
  PsCommand c;
  psParseSerialLine(line, c);
  handleCommand(c);
}

// ------------------------------------------------------------- lab mode ---

static void startLab() {
  wm = new WiFiManager();
  ws = new WebSocketsServer(WS_PORT);
  WiFi.mode(WIFI_STA);
  WiFi.begin();  // reconnect only if credentials were already stored
  // Give a stored network (the 'wifi' command, or an earlier portal save) time
  // to connect first: WiFiManager turns the station off if it starts its portal
  // while the station is still unconnected.
  char ssid[33];
  if (psWifiStoredSsid(ssid, sizeof(ssid)) > 0) {
    psPrintNote("lab: joining %s", ssid);
    const uint32_t t0 = millis();
    while (WiFi.status() != WL_CONNECTED && millis() - t0 < LAB_JOIN_WAIT_MS) delay(100);
  }
  psPrintWifi("lab");
  wm->setConfigPortalBlocking(false);
  wm->setConfigPortalTimeout(180);
  wm->startConfigPortal("NIVA-GaitGuard-AP", "gaitguard123");
  ws->begin();
  ws->onEvent([](uint8_t, WStype_t type, uint8_t* payload, size_t length) {
    if (type != WStype_TEXT) return;
    char cmd[96];
    const size_t n = length < sizeof(cmd) - 1 ? length : sizeof(cmd) - 1;
    memcpy(cmd, payload, n);
    cmd[n] = '\0';
    for (char* p = cmd; *p; ++p) if (*p >= 'A' && *p <= 'Z') *p = (char)(*p - 'A' + 'a');
    if (strstr(cmd, "tare") != nullptr || strstr(cmd, "calibrate") != nullptr) requestExplicitTare();
  });
}

static void serviceLab() {
  if (!psCfg.lab) return;
  ws->loop();
  wm->process();
  if (staConnected() && !mdnsStarted) {
    mdnsStarted = MDNS.begin("niva");
    if (mdnsStarted) MDNS.addService("ws", "tcp", WS_PORT);
  }
  char cmd[64];
  if (psBleLegacyTakeCommand(cmd, sizeof(cmd))) {
    for (char* p = cmd; *p; ++p) if (*p >= 'A' && *p <= 'Z') *p = (char)(*p - 'A' + 'a');
    if (strstr(cmd, "tare") != nullptr || strstr(cmd, "calibrate") != nullptr) requestExplicitTare();
  }

  const uint32_t nowUs = micros();
  if (nowUs - lastFrameUs < NIVA_STREAM_PERIOD_US) return;
  lastFrameUs = nowUs;
  NivaAcqSnapshot s;
  acq.snapshot(s);
  if (s.validity == NivaAcqValidity::valid) lastPiezo = s.impact;
  if (s.tareGeneration != frameTareGen) {
    frameTareGen = s.tareGeneration;
    frameEvents.clear();
  }
  NivaFrameData d;
  d.timestampMs = nivaDeviceMs();
  d.valid = s.validity == NivaAcqValidity::valid;
  d.validityText = nivaAcqValidityText(s.validity);
  for (int i = 0; i < 4; ++i) d.fsr[i] = s.fsr[i];
  d.piezo = lastPiezo;
  d.pitch = s.pitch;
  d.roll = s.roll;
  d.accZ = s.accZ;
  d.imuClipped = s.imuClipped;
  d.contact = s.contactMask;
  d.eventsDropped = (unsigned long)(s.eventsDropped + frameEvents.dropped());
  static char frame[1024];
  nivaBuildFrame(frame, sizeof(frame), d, frameEvents);
  ws->broadcastTXT(frame);
  psBleLegacySend(frame);
  psPrintLine(frame);
}

// --------------------------------------------------------------- public ---

void psInsoleSetup() {
  psBatteryBegin();
  // +-16 g, +-500 dps as niva_hardware (MPU6050 on the DevKit, LSM6DSO32 on the pod).
  imuAvailable = nivaBoardImuBegin(500);
  if (!imuAvailable) psPrintNote("IMU not available; pitch, roll and acceleration are unavailable");

  if (!acq.begin(imuAvailable)) psPrintNote("acquisition task could not start");

  if (psCfg.lab) {
    startLab();
  } else {
    WiFi.persistent(false);
    WiFi.mode(WIFI_STA);
    WiFi.disconnect(false, false);
  }
  if (!psEspNowBegin(psCfg.channel)) psPrintNote("ESP-NOW init failed");
  if (psCfg.peerSet) psEspNowAddPeer(psCfg.peer);
  outbox.reset();
  psBleBegin(false, psCfg.lab);
  nextAutoTareAt = psNowMs() + 2000;
  printInfo();
  if (!psCfg.refSet) psPrintNote("no tare reference yet: unload the insole and send 'tare' (or short-press BOOT)");
  if (!psCfg.peerSet) psPrintNote("no hub paired: 'pair <hub mac>' or long-press BOOT with the hub's pairing window open");
}

void psInsoleLoop() {
  const uint32_t now = psNowMs();
  if (const char* line = psSerialPoll()) handleLine(line);

  const int b = psButtonPoll();
  if (b == 1) requestExplicitTare();
  if (b == 2) {
    PsCommand c;
    c.type = PsCmdType::PAIR;
    handleCommand(c);
  }

  serviceTail(now);
  serviceTare(now);
  serviceContacts(now);
  if (!psCfg.lab) updateDegraded(now);  // lab mode: the frame consumes the piezo peak
  else {
    const uint32_t dropped = frameEvents.dropped() + outbox.dropped();
    if (dropped > lastDroppedTotal) { lastDroppedTotal = dropped; degradedUntil = now + DEGRADED_HOLD_MS; }
  }

  const PsVal v = currentVal(now);
  if (v != reportedVal) {
    reportedVal = v;
    hbPending = true;  // tell the hub at once
    hbNextTry = now;
  }
  if (now - lastHbAt >= PS_HEARTBEAT_MS) {
    lastHbAt = now;
    hbPending = true;
    hbNextTry = now;
    hbRetryMs = PsOutbox::kRetryMinMs;
    char line[120];
    const int8_t batt = psBatteryPercent();
    char battText[8];
    if (batt == PS_BATT_NONE) strcpy(battText, "null"); else snprintf(battText, sizeof(battText), "%d", batt);
    snprintf(line, sizeof(line), "{\"t\":\"heartbeat\",\"ms\":%lu,\"batt\":%s,\"val\":\"%s\",\"ch\":%u,\"hub_acked\":%s}",
             (unsigned long)now, battText, psValText(v), (unsigned)psEspNowChannel(), everAcked ? "true" : "false");
    if (!psCfg.lab) psPrintLine(line);
  }
  serviceLink(now);
  serviceLab();

  if (psBleConnected() && now - lastStatusAt >= 1000) {
    lastStatusAt = now;
    char json[240];
    if (buildStatus(json, sizeof(json), now) > 0) psBleNotifyStatus(json);
  }
  char info[240];
  if (psInfoJson(PsRole::INSOLE, psBootId, psMac, psBatteryPercent(), "hub", psCfg.peerSet, psCfg.peer, info, sizeof(info)) > 0 &&
      strcmp(info, infoCache) != 0) {
    strcpy(infoCache, info);
    psBleSetInfo(info);
  }
  if (psPowerCheck()) psDeepSleep();
  delay(1);
}
