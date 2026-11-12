// ps_device.h - ESP32 services shared by both roles: NVS configuration,
// identity, serial lines, the BOOT button, battery, ESP-NOW and the
// Protected Steps BLE service. Not host-tested (needs the ESP32).

#ifndef PS_DEVICE_H
#define PS_DEVICE_H

#include <Arduino.h>

#include "niva_board.h"   // pins and sensors of the DevKit and the pod Rev C.2
#include "ps_logic.h"
#include "ps_types.h"

static const uint8_t PS_DEFAULT_CHANNEL = 1;     // design choice
static const uint32_t PS_PAIR_WINDOW_MS = 60000; // design choice
static const uint32_t PS_LONG_PRESS_MS = 3000;   // design choice

// Everything kept in NVS (namespace "niva_ps").
struct PsConfig {
  PsRole role = PsRole::INSOLE;
  bool roleSet = false;
  bool lab = false;                 // insole only
  bool peerSet = false;             // hub: paired insole; insole: its hub
  uint8_t peer[6] = {0};
  uint8_t channel = PS_DEFAULT_CHANNEL;
  int8_t axis = 3;                  // hub: +z (design choice, see README)
  uint32_t matchMs = PS_DEFAULT_MATCH_MS;
  uint32_t settleMs = PS_DEFAULT_SETTLE_MS;
  uint32_t homeScanS = PS_DEFAULT_HOME_SCAN_S;
  PsHomeConfig home;
  uint32_t seqReserved = 0;         // hub log
  uint32_t acked = 0;               // hub log
  bool insHeard = false;            // hub: last insole heartbeat, kept across reboots
  int8_t insBatt = PS_BATT_NONE;
  uint8_t insVal = (uint8_t)PsVal::INVALID;
  bool refSet = false;              // insole: zeros of the last explicit tare
  float refZero[4] = {0, 0, 0, 0};
};

extern PsConfig psCfg;
extern uint32_t psBootId;
extern uint8_t psMac[6];   // Wi-Fi STA MAC: the id used for pairing and ESP-NOW
extern char psMacHex[13];

void psConfigLoad();
void psSaveRole();
void psSaveLab();
void psSavePeer();
void psSaveChannel();
void psSaveAxis();
void psSaveMatchConfig();   // match_ms, settle_ms, home_scan_s, home ssid/bssid
void psSaveSeqReserved();
void psSaveAcked();
void psSaveInsoleState();
void psSaveRef();

uint32_t psNowMs();  // u32 ms since boot (PROTOCOL.md device time)

// Serial: returns a complete line (without the newline) or nullptr.
const char* psSerialPoll();
void psPrintLine(const char* s);          // one JSON line
void psPrintNote(const char* fmt, ...)    // "# ..." human-readable line
    __attribute__((format(printf, 1, 2)));

// Station Wi-Fi for lab mode. Written to the Wi-Fi NVS that WiFi.begin()
// (no arguments) and WiFiManager read, so it survives reflashing and is shared
// with niva_hardware. Saving never joins the network or moves the ESP-NOW
// channel. An empty SSID forgets the network. The password is never printed.
bool psWifiStore(const char* ssid, const char* pass);
size_t psWifiStoredSsid(char* out, size_t cap);  // "" if none
void psPrintWifi(const char* event);              // {"t":"wifi",...} on serial

// BOOT button. Returns 1 for a short press, 2 for a long press, 0 otherwise.
int psButtonPoll();

// Battery: MAX17048 fuel gauge at I2C 0x36 if fitted, else PS_BATT_NONE.
// Begin also lowers the gauge's reset threshold to 2.68 V (review A12) and
// tells the power policy whether this boot followed a brown-out reset.
void psBatteryBegin();
int8_t psBatteryPercent();      // cached; refreshed every 10 s
uint16_t psBatteryMillivolts(); // cell voltage, refreshed with the percent; 0 without a gauge

// Low-battery policy (NivaPowerPolicy in niva_board_logic.h), evaluated at
// each 10 s gauge refresh. True once the device should stop; the role then
// flushes what it must and calls psDeepSleep(), which wakes on the button.
bool psPowerCheck();
void psDeepSleep();

// ESP-NOW. Received packets are queued by the Wi-Fi task and read here.
struct PsRxPacket {
  uint8_t mac[6];
  uint8_t len;
  uint8_t data[PS_PKT_MAX];
  uint32_t rxMs;
  int8_t rssi;
};
bool psEspNowBegin(uint8_t channel);
bool psEspNowSetChannel(uint8_t channel);
uint8_t psEspNowChannel();
bool psEspNowAddPeer(const uint8_t mac[6]);
bool psEspNowSend(const uint8_t mac[6], const uint8_t* data, size_t len);
bool psEspNowReceive(PsRxPacket& out);
// Result of the last send: -1 none yet, 0 failed, 1 acknowledged. Reading clears it.
int psEspNowTakeSendResult();

// BLE. The hub registers all five characteristics, the insole Info and
// Status (and, in lab mode, the legacy telemetry service).
struct PsBleIncoming {
  bool isTime;
  uint16_t len;
  char text[244];
};
void psBleBegin(bool hub, bool legacyTelemetry);
bool psBleConnected();
uint16_t psBleMtu();
bool psBleRecordsSubscribed();
void psBleSetInfo(const char* json);
bool psBleNotifyRecord(const char* json);   // false: not sent, try again later
bool psBleNotifyStatus(const char* json);
bool psBleTakeIncoming(PsBleIncoming& out);
bool psBleTakeConnectEvent();               // true once after each new connection
void psBleLegacySend(const char* frame);    // lab mode: fragmented frame, as niva_hardware
bool psBleLegacyTakeCommand(char* out, size_t cap);

void psHubSetup();
void psHubLoop();
void psInsoleSetup();
void psInsoleLoop();

#endif  // PS_DEVICE_H
