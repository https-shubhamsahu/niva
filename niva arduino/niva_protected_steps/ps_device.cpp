// ps_device.cpp - see ps_device.h.

#include "ps_device.h"

#include <NimBLEDevice.h>
#include <Preferences.h>
#include <WiFi.h>
#include <Wire.h>
#include <esp_now.h>
#include <esp_sleep.h>
#include <esp_system.h>
#include <esp_wifi.h>
#include <stdarg.h>

#include "esp_timer.h"
#include "ps_record.h"

PsConfig psCfg;
uint32_t psBootId = 0;
uint8_t psMac[6] = {0};
char psMacHex[13] = {0};

static Preferences prefs;

uint32_t psNowMs() { return (uint32_t)(esp_timer_get_time() / 1000); }

// ---------------------------------------------------------------- NVS -----

void psConfigLoad() {
  prefs.begin("niva_ps", false);
  psCfg.roleSet = prefs.isKey("role");
  psCfg.role = (PsRole)prefs.getUChar("role", (uint8_t)PsRole::INSOLE);
  psCfg.lab = prefs.getBool("lab", false);
  psCfg.peerSet = prefs.getBytes("peer", psCfg.peer, 6) == 6;
  psCfg.channel = prefs.getUChar("ch", PS_DEFAULT_CHANNEL);
  if (psCfg.channel < 1 || psCfg.channel > 13) psCfg.channel = PS_DEFAULT_CHANNEL;
  psCfg.axis = prefs.getChar("axis", 3);
  psCfg.matchMs = prefs.getULong("match", PS_DEFAULT_MATCH_MS);
  psCfg.settleMs = prefs.getULong("settle", PS_DEFAULT_SETTLE_MS);
  psCfg.homeScanS = prefs.getULong("scan", PS_DEFAULT_HOME_SCAN_S);
  prefs.getString("hssid", psCfg.home.ssid, sizeof(psCfg.home.ssid));
  if (prefs.getBytes("hbssid", psCfg.home.bssid, 6) != 6) memset(psCfg.home.bssid, 0, 6);
  psCfg.seqReserved = prefs.getULong("seqres", 0);
  psCfg.acked = prefs.getULong("acked", 0);
  psCfg.insHeard = prefs.getBool("insHeard", false);
  psCfg.insBatt = prefs.getChar("insBatt", PS_BATT_NONE);
  psCfg.insVal = prefs.getUChar("insVal", (uint8_t)PsVal::INVALID);
  psCfg.refSet = prefs.getBytes("ref", psCfg.refZero, sizeof(psCfg.refZero)) == sizeof(psCfg.refZero);
}

void psSaveRole() { prefs.putUChar("role", (uint8_t)psCfg.role); }
void psSaveLab() { prefs.putBool("lab", psCfg.lab); }
void psSavePeer() {
  if (psCfg.peerSet) prefs.putBytes("peer", psCfg.peer, 6);
  else prefs.remove("peer");
}
void psSaveChannel() { prefs.putUChar("ch", psCfg.channel); }
void psSaveAxis() { prefs.putChar("axis", psCfg.axis); }
void psSaveMatchConfig() {
  prefs.putULong("match", psCfg.matchMs);
  prefs.putULong("settle", psCfg.settleMs);
  prefs.putULong("scan", psCfg.homeScanS);
  prefs.putString("hssid", psCfg.home.ssid);
  prefs.putBytes("hbssid", psCfg.home.bssid, 6);
}
void psSaveSeqReserved() { prefs.putULong("seqres", psCfg.seqReserved); }
void psSaveAcked() { prefs.putULong("acked", psCfg.acked); }
void psSaveInsoleState() {
  // Only written when the reported state changes, to spare the flash.
  if (prefs.getBool("insHeard", false) != psCfg.insHeard) prefs.putBool("insHeard", psCfg.insHeard);
  if (prefs.getChar("insBatt", PS_BATT_NONE) != psCfg.insBatt) prefs.putChar("insBatt", psCfg.insBatt);
  if (prefs.getUChar("insVal", 2) != psCfg.insVal) prefs.putUChar("insVal", psCfg.insVal);
}
void psSaveRef() { prefs.putBytes("ref", psCfg.refZero, sizeof(psCfg.refZero)); }

// ------------------------------------------------------------- serial -----

const char* psSerialPoll() {
  static char line[256];
  static size_t n = 0;
  static bool overflow = false;
  while (Serial.available() > 0) {
    const int c = Serial.read();
    if (c < 0) break;
    if (c == '\n' || c == '\r') {
      if (n == 0 && !overflow) continue;
      line[n] = '\0';
      const bool bad = overflow;
      n = 0;
      overflow = false;
      if (bad) continue;  // too long: dropped
      return line;
    }
    if (n + 1 < sizeof(line)) line[n++] = (char)c;
    else overflow = true;
  }
  return nullptr;
}

void psPrintLine(const char* s) { Serial.println(s); }

void psPrintNote(const char* fmt, ...) {
  char buf[200];
  va_list args;
  va_start(args, fmt);
  vsnprintf(buf, sizeof(buf), fmt, args);
  va_end(args);
  Serial.print("# ");
  Serial.println(buf);
}

// ------------------------------------------------------------- wifi -------

bool psWifiStore(const char* ssid, const char* pass) {
  if (WiFi.getMode() == WIFI_OFF) WiFi.mode(WIFI_STA);
  wifi_config_t conf;
  memset(&conf, 0, sizeof(conf));
  if (ssid != nullptr && ssid[0] != '\0') {
    strncpy((char*)conf.sta.ssid, ssid, sizeof(conf.sta.ssid));
    if (pass != nullptr && pass[0] != '\0') {
      strncpy((char*)conf.sta.password, pass, sizeof(conf.sta.password));
      conf.sta.threshold.authmode = WIFI_AUTH_WPA2_PSK;  // minimum: accepts WPA2, WPA2/WPA3 and WPA3-SAE
    }
    conf.sta.pmf_cfg.capable = true;   // WPA3-SAE requires protected management frames
    conf.sta.pmf_cfg.required = false; // still join WPA2-only networks
    conf.sta.sae_pwe_h2e = WPA3_SAE_PWE_BOTH;
    conf.sta.threshold.rssi = -127;
  }
  // Write through to flash just for this call; the roles otherwise keep Wi-Fi in RAM.
  esp_wifi_set_storage(WIFI_STORAGE_FLASH);
  const esp_err_t err = esp_wifi_set_config(WIFI_IF_STA, &conf);
  esp_wifi_set_storage(WIFI_STORAGE_RAM);
  memset(&conf, 0, sizeof(conf));
  return err == ESP_OK;
}

size_t psWifiStoredSsid(char* out, size_t cap) {
  if (cap == 0) return 0;
  out[0] = '\0';
  wifi_config_t conf;
  if (esp_wifi_get_config(WIFI_IF_STA, &conf) != ESP_OK) return 0;
  size_t n = strnlen((const char*)conf.sta.ssid, sizeof(conf.sta.ssid));
  if (n >= cap) n = cap - 1;
  memcpy(out, conf.sta.ssid, n);
  out[n] = '\0';
  memset(&conf, 0, sizeof(conf));
  return n;
}

void psPrintWifi(const char* event) {
  char ssid[33];
  psWifiStoredSsid(ssid, sizeof(ssid));
  char json[160];
  PsOut o(json, sizeof(json));
  o.raw("{\"t\":\"wifi\",\"event\":\"");
  o.raw(event);
  o.raw("\",\"wifi_ssid\":");
  if (ssid[0]) o.str(ssid); else o.raw("null");
  const bool up = WiFi.status() == WL_CONNECTED;
  o.raw(",\"connected\":");
  o.raw(up ? "true" : "false");
  o.raw(",\"ip\":");
  if (up) {
    char ip[16];
    const IPAddress a = WiFi.localIP();
    snprintf(ip, sizeof(ip), "%u.%u.%u.%u", a[0], a[1], a[2], a[3]);
    o.str(ip);
  } else {
    o.raw("null");
  }
  o.raw("}");
  if (o.ok()) psPrintLine(json);
}

// ------------------------------------------------------------- button -----

int psButtonPoll() {
  static bool init = false, down = false, longSent = false;
  static uint32_t downAt = 0, lastChange = 0;
  if (!init) {
    pinMode(NIVA_PIN_BUTTON, INPUT_PULLUP);
    init = true;
    // A press already down at the first poll is the one that woke the pod
    // (or a stuck button). Ignore it until release, so waking an insole
    // pod never tares it or opens pairing.
    down = longSent = digitalRead(NIVA_PIN_BUTTON) == LOW;
  }
  const uint32_t now = millis();
  const bool pressed = digitalRead(NIVA_PIN_BUTTON) == LOW;
  if (pressed != down && now - lastChange >= 30) {  // 30 ms debounce (design choice)
    lastChange = now;
    down = pressed;
    if (down) {
      downAt = now;
      longSent = false;
    } else if (!longSent && now - downAt < 1000) {
      return 1;
    }
  }
  if (down && !longSent && now - downAt >= PS_LONG_PRESS_MS) {
    longSent = true;
    return 2;
  }
  return 0;
}

// ------------------------------------------------------------ battery -----

static bool gaugePresent = false;
static int8_t battCached = PS_BATT_NONE;
static uint16_t battMvCached = 0;
static uint32_t battReadAt = 0;
static bool battFresh = false;   // a new reading the power policy has not seen
static NivaPowerPolicy powerPolicy;

static bool gaugeRead16(uint8_t reg, uint16_t& v) {
  Wire.beginTransmission(NIVA_GAUGE_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(NIVA_GAUGE_ADDR, (size_t)2, true) != 2) return false;
  const int hi = Wire.read();
  const int lo = Wire.read();
  v = (uint16_t)((hi << 8) | lo);
  return true;
}

static bool gaugeWrite16(uint8_t reg, uint16_t v) {
  Wire.beginTransmission(NIVA_GAUGE_ADDR);
  Wire.write(reg);
  Wire.write((uint8_t)(v >> 8));
  Wire.write((uint8_t)(v & 0xFF));
  return Wire.endTransmission() == 0;
}

// The pod always has a gauge, so a silent one is a fault: keep asking every
// 10 s and say so once. The DevKit's gauge is optional and shares I2C with
// the MPU6050, so there one answer at boot decides.
#if NIVA_BOARD_POD_C2
static const bool kGaugeExpected = true;
#else
static const bool kGaugeExpected = false;
#endif
static bool gaugeSilentNoted = false;

static void gaugeSetVreset() {
  uint16_t vreset = 0;
  if (gaugeRead16(NIVA_GAUGE_VRESET_ID, vreset)) {
    gaugeWrite16(NIVA_GAUGE_VRESET_ID, nivaGaugeVresetWord(vreset, NIVA_GAUGE_VRESET_MV));
  }
}

static uint16_t gaugeReadMv() {
  uint16_t vcell;
  return gaugeRead16(NIVA_GAUGE_VCELL, vcell) ? nivaGaugeVcellMv(vcell) : 0;
}

void psBatteryBegin() {
  uint16_t version = 0;
  gaugePresent = gaugeRead16(NIVA_GAUGE_VERSION, version);
  battReadAt = 0;
  battCached = PS_BATT_NONE;
  battMvCached = 0;
  powerPolicy = NivaPowerPolicy();
  if (!gaugePresent) return;
  gaugeSetVreset();

  // Boot check, before any radio starts (both roles call this first). A
  // fresh gauge may read 0 until its first conversion: try for about 0.3 s.
  uint16_t restMv = gaugeReadMv();
  for (int i = 0; i < 3 && restMv == 0; ++i) {
    delay(100);
    restMv = gaugeReadMv();
  }
  battMvCached = restMv;
  // psDeepSleep() is used only for low battery, so a deep-sleep wake means
  // the last stop was for low battery.
  const esp_reset_reason_t reason = esp_reset_reason();
  if (nivaPowerSleepAtBoot(restMv, reason == ESP_RST_BROWNOUT, reason == ESP_RST_DEEPSLEEP)) psDeepSleep();
}

static void batteryRefresh() {
  const uint32_t now = millis();
  if (battReadAt != 0 && now - battReadAt < 10000) return;
  battReadAt = now ? now : 1;
  uint16_t soc;
  const bool socOk = gaugeRead16(NIVA_GAUGE_SOC, soc);
  if (socOk) {
    int pct = soc >> 8;  // SOC register: high byte is whole percent
    if (pct > 100) pct = 100;
    battCached = (int8_t)pct;
  } else {
    battCached = PS_BATT_NONE;
  }
  battMvCached = gaugeReadMv();
  battFresh = true;
  if (socOk || battMvCached != 0) {
    if (!gaugePresent) gaugeSetVreset();   // answered for the first time since boot
    gaugePresent = true;
    gaugeSilentNoted = false;
  } else if (!gaugeSilentNoted) {
    psPrintNote("battery gauge not answering: the low-battery cut-off cannot act");
    gaugeSilentNoted = true;
  }
}

int8_t psBatteryPercent() {
  if (!gaugePresent && !kGaugeExpected) return PS_BATT_NONE;
  batteryRefresh();
  return battCached;
}

uint16_t psBatteryMillivolts() {
  if (!gaugePresent && !kGaugeExpected) return 0;
  batteryRefresh();
  return battMvCached;
}

bool psPowerCheck() {
  if (!gaugePresent && !kGaugeExpected) return false;
  batteryRefresh();
  if (!battFresh) return false;
  battFresh = false;
  return powerPolicy.shouldShutDown(battMvCached);
}

void psDeepSleep() {
  psPrintNote("battery low (%u mV): deep sleep; press the button to wake", (unsigned)battMvCached);
  Serial.flush();
  nivaBoardPrepareSleep();
#if NIVA_BOARD_POD_C2
  esp_deep_sleep_enable_gpio_wakeup(1ULL << NIVA_PIN_BUTTON, ESP_GPIO_WAKEUP_GPIO_LOW);
#else
  esp_sleep_enable_ext0_wakeup((gpio_num_t)NIVA_PIN_BUTTON, 0);
#endif
  esp_deep_sleep_start();
}

// ------------------------------------------------------------ ESP-NOW -----

static QueueHandle_t rxQueue = nullptr;
static volatile int sendResult = -1;

static void onEspNowRecv(const esp_now_recv_info_t* info, const uint8_t* data, int len) {
  if (rxQueue == nullptr || info == nullptr || len <= 0 || len > (int)PS_PKT_MAX) return;
  PsRxPacket p;
  memcpy(p.mac, info->src_addr, 6);
  p.len = (uint8_t)len;
  memcpy(p.data, data, (size_t)len);
  p.rxMs = psNowMs();
  p.rssi = info->rx_ctrl ? (int8_t)info->rx_ctrl->rssi : 0;
  xQueueSend(rxQueue, &p, 0);  // full queue: dropped, the sender retries
}

static void onEspNowSent(const esp_now_send_info_t* info, esp_now_send_status_t status) {
  (void)info;
  sendResult = status == ESP_NOW_SEND_SUCCESS ? 1 : 0;
}

bool psEspNowBegin(uint8_t channel) {
  if (rxQueue == nullptr) rxQueue = xQueueCreate(16, sizeof(PsRxPacket));
  if (WiFi.getMode() == WIFI_OFF) WiFi.mode(WIFI_STA);
  psEspNowSetChannel(channel);
  if (esp_now_init() != ESP_OK) return false;
  esp_now_register_recv_cb(onEspNowRecv);
  esp_now_register_send_cb(onEspNowSent);
  static const uint8_t bcast[6] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
  psEspNowAddPeer(bcast);
  return true;
}

bool psEspNowSetChannel(uint8_t channel) {
  if (channel < 1 || channel > 13) return false;
  return esp_wifi_set_channel(channel, WIFI_SECOND_CHAN_NONE) == ESP_OK;
}

uint8_t psEspNowChannel() {
  uint8_t primary = 0;
  wifi_second_chan_t second;
  if (esp_wifi_get_channel(&primary, &second) != ESP_OK) return 0;
  return primary;
}

bool psEspNowAddPeer(const uint8_t mac[6]) {
  esp_now_peer_info_t peer;
  memset(&peer, 0, sizeof(peer));
  memcpy(peer.peer_addr, mac, 6);
  peer.channel = 0;  // follow the current channel
  peer.ifidx = WIFI_IF_STA;
  peer.encrypt = false;
  if (esp_now_is_peer_exist(mac)) return esp_now_mod_peer(&peer) == ESP_OK;
  return esp_now_add_peer(&peer) == ESP_OK;
}

bool psEspNowSend(const uint8_t mac[6], const uint8_t* data, size_t len) {
  sendResult = -1;
  return esp_now_send(mac, data, len) == ESP_OK;
}

bool psEspNowReceive(PsRxPacket& out) {
  return rxQueue != nullptr && xQueueReceive(rxQueue, &out, 0) == pdTRUE;
}

int psEspNowTakeSendResult() {
  const int r = sendResult;
  if (r >= 0) sendResult = -1;
  return r;
}

// ---------------------------------------------------------------- BLE -----

#define PS_UUID(x) "1ddf" x "-9fe3-4008-8f54-527ea31bac22"
static const char* PS_SVC_UUID = PS_UUID("0000");
static const char* PS_INFO_UUID = PS_UUID("0001");
static const char* PS_TIME_UUID = PS_UUID("0002");
static const char* PS_RECORDS_UUID = PS_UUID("0003");
static const char* PS_CONTROL_UUID = PS_UUID("0004");
static const char* PS_STATUS_UUID = PS_UUID("0005");
// The niva_hardware telemetry service, kept for lab mode (SIH and Aavishkar apps).
static const char* LEGACY_SVC_UUID = "c4f00001-dc50-4c44-a4d8-f0164e510001";
static const char* LEGACY_RX_UUID = "c4f00002-dc50-4c44-a4d8-f0164e510001";
static const char* LEGACY_TX_UUID = "c4f00003-dc50-4c44-a4d8-f0164e510001";

static NimBLEServer* bleServer = nullptr;
static NimBLECharacteristic* chInfo = nullptr;
static NimBLECharacteristic* chRecords = nullptr;
static NimBLECharacteristic* chStatus = nullptr;
static NimBLECharacteristic* chLegacyTx = nullptr;
static QueueHandle_t bleInQueue = nullptr;
static volatile bool bleIsConnected = false;
static volatile bool bleConnectEvent = false;
static volatile uint16_t bleConn = 0;
static volatile uint16_t bleMtuValue = 23;
static volatile bool recordsSubscribed = false;
static portMUX_TYPE legacyMux = portMUX_INITIALIZER_UNLOCKED;
static char legacyCmd[64];
static volatile bool legacyCmdReady = false;
static uint8_t legacySeq = 0;

class PsServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo& info) override {
    bleConn = info.getConnHandle();
    bleMtuValue = info.getMTU();
    bleIsConnected = true;
    bleConnectEvent = true;
  }
  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int) override {
    bleIsConnected = false;
    recordsSubscribed = false;
  }
  void onMTUChange(uint16_t mtu, NimBLEConnInfo&) override { bleMtuValue = mtu; }
};

class PsTimeCallbacks : public NimBLECharacteristicCallbacks {
  void onRead(NimBLECharacteristic* c, NimBLEConnInfo&) override {
    char b[64];
    if (psTimeReadJson(psNowMs(), psBootId, b, sizeof(b)) > 0) c->setValue(b);
  }
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override { queueIncoming(c, true); }

public:
  static void queueIncoming(NimBLECharacteristic* c, bool isTime) {
    if (bleInQueue == nullptr) return;
    PsBleIncoming in;
    in.isTime = isTime;
    const NimBLEAttValue v = c->getValue();
    size_t n = v.length();
    if (n >= sizeof(in.text)) n = sizeof(in.text) - 1;  // the parser rejects the truncated JSON
    memcpy(in.text, v.data(), n);
    in.text[n] = '\0';
    in.len = (uint16_t)n;
    xQueueSend(bleInQueue, &in, 0);
  }
};

class PsControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override { PsTimeCallbacks::queueIncoming(c, false); }
};

class PsRecordsCallbacks : public NimBLECharacteristicCallbacks {
  void onSubscribe(NimBLECharacteristic*, NimBLEConnInfo&, uint16_t subValue) override {
    recordsSubscribed = (subValue & 0x0001) != 0;
  }
};

class PsLegacyRxCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic* c, NimBLEConnInfo&) override {
    const NimBLEAttValue v = c->getValue();
    size_t n = v.length();
    if (n >= sizeof(legacyCmd)) n = sizeof(legacyCmd) - 1;
    portENTER_CRITICAL(&legacyMux);
    memcpy(legacyCmd, v.data(), n);
    legacyCmd[n] = '\0';
    legacyCmdReady = true;
    portEXIT_CRITICAL(&legacyMux);
  }
};

void psBleBegin(bool hub, bool legacyTelemetry) {
  if (bleInQueue == nullptr) bleInQueue = xQueueCreate(4, sizeof(PsBleIncoming));
  char name[24];
  snprintf(name, sizeof(name), "Niva-%s-%s", hub ? "Ankle" : "Insole", psMacHex + 8);
  NimBLEDevice::init(name);
  NimBLEDevice::setMTU(247);
  bleServer = NimBLEDevice::createServer();
  bleServer->setCallbacks(new PsServerCallbacks());
  bleServer->advertiseOnDisconnect(true);

  NimBLEService* svc = bleServer->createService(PS_SVC_UUID);
  chInfo = svc->createCharacteristic(PS_INFO_UUID, NIMBLE_PROPERTY::READ);
  chStatus = svc->createCharacteristic(PS_STATUS_UUID, NIMBLE_PROPERTY::NOTIFY);
  if (hub) {
    NimBLECharacteristic* t = svc->createCharacteristic(PS_TIME_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::WRITE);
    t->setCallbacks(new PsTimeCallbacks());
    chRecords = svc->createCharacteristic(PS_RECORDS_UUID, NIMBLE_PROPERTY::NOTIFY);
    chRecords->setCallbacks(new PsRecordsCallbacks());
    NimBLECharacteristic* c = svc->createCharacteristic(PS_CONTROL_UUID, NIMBLE_PROPERTY::WRITE);
    c->setCallbacks(new PsControlCallbacks());
  }

  if (legacyTelemetry) {
    NimBLEService* legacy = bleServer->createService(LEGACY_SVC_UUID);
    chLegacyTx = legacy->createCharacteristic(LEGACY_TX_UUID, NIMBLE_PROPERTY::NOTIFY);
    NimBLECharacteristic* rx = legacy->createCharacteristic(LEGACY_RX_UUID, NIMBLE_PROPERTY::WRITE);
    rx->setCallbacks(new PsLegacyRxCallbacks());
  }
  bleServer->start();  // NimBLE 2.x starts every service with the server

  NimBLEAdvertising* adv = NimBLEDevice::getAdvertising();
  adv->enableScanResponse(true);
  // One 128-bit UUID fits in an advertisement. Lab mode advertises the
  // legacy service so the existing apps find the insole as before.
  adv->addServiceUUID(legacyTelemetry ? LEGACY_SVC_UUID : PS_SVC_UUID);
  adv->setName(name);
  adv->start();
}

bool psBleConnected() { return bleIsConnected; }
uint16_t psBleMtu() { return bleMtuValue; }
bool psBleRecordsSubscribed() { return bleIsConnected && recordsSubscribed; }

void psBleSetInfo(const char* json) {
  if (chInfo) chInfo->setValue(json);
}

static bool notifyJson(NimBLECharacteristic* c, const char* json) {
  if (c == nullptr || !bleIsConnected) return false;
  const size_t n = strlen(json);
  // An ATT notification carries MTU - 3 bytes. A record that does not fit
  // is not sent truncated; it stays in the log for a backlog request.
  if (n + 3 > bleMtuValue) return false;
  return c->notify((const uint8_t*)json, n, bleConn);
}

bool psBleNotifyRecord(const char* json) { return recordsSubscribed && notifyJson(chRecords, json); }
bool psBleNotifyStatus(const char* json) { return notifyJson(chStatus, json); }

bool psBleTakeIncoming(PsBleIncoming& out) {
  return bleInQueue != nullptr && xQueueReceive(bleInQueue, &out, 0) == pdTRUE;
}

bool psBleTakeConnectEvent() {
  const bool e = bleConnectEvent;
  if (e) bleConnectEvent = false;
  return e;
}

void psBleLegacySend(const char* payload) {
  // Same framing as niva_hardware: [seq][flags][<=18 bytes], flags 1 = first, 2 = last.
  static const size_t kFrag = 18;
  if (chLegacyTx == nullptr || !bleIsConnected) return;
  const size_t length = strlen(payload);
  for (size_t offset = 0; offset < length; offset += kFrag) {
    const size_t fl = (length - offset) < kFrag ? (length - offset) : kFrag;
    uint8_t fragment[kFrag + 2];
    uint8_t flags = offset == 0 ? 0x01 : 0x00;
    if (offset + fl == length) flags |= 0x02;
    fragment[0] = legacySeq;
    fragment[1] = flags;
    memcpy(fragment + 2, payload + offset, fl);
    if (!chLegacyTx->notify(fragment, fl + 2, bleConn)) break;  // out of buffers: frame dropped
  }
  ++legacySeq;
}

bool psBleLegacyTakeCommand(char* out, size_t cap) {
  if (!legacyCmdReady) return false;
  portENTER_CRITICAL(&legacyMux);
  strncpy(out, legacyCmd, cap - 1);
  out[cap - 1] = '\0';
  legacyCmdReady = false;
  portEXIT_CRITICAL(&legacyMux);
  return true;
}
