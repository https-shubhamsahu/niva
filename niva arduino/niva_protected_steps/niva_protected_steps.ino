// Niva: Protected Steps firmware (PROTOCOL.md v1). One firmware, two roles:
//   ankle  - ankle hub: IMU stride detection, ESP-NOW receive, P/U/X
//            classification, LittleFS log, BLE GATT server for the app.
//   insole - insole node: FSR contact detection (niva_signal.h), ESP-NOW
//            contacts and heartbeats to the paired hub; lab mode keeps the
//            niva_hardware telemetry.
// The role is stored in NVS ("role ankle" / "role insole" on serial at
// 115200 baud). A board that has never been given a role starts as insole.
//
// Boards (niva_board.h picks the hardware from the target):
//   DevKit prototypes: esp32:esp32:esp32:PartitionScheme=huge_app
//   Niva pod Rev C.2:  esp32:esp32:esp32c3:PartitionScheme=huge_app,CDCOnBoot=cdc
// Libraries: NimBLE-Arduino, WiFiManager (tzapu), WebSockets (Markus Sattler).
// The code lives in the .cpp/.h files of this folder; see README.md.

#include <Arduino.h>
#include <WiFi.h>
#include <Wire.h>
#include <esp_mac.h>
#include <esp_random.h>

#include "ps_device.h"

#if NIVA_BOARD_POD_C2 && !ARDUINO_USB_CDC_ON_BOOT
#error "Pod Rev C.2: build with CDCOnBoot=cdc. Serial must be USB-CDC; UART0's pins drive the LEDs."
#endif

void setup() {
  Serial.setTxBufferSize(2048);  // JSON lines must not stall loop()
#if NIVA_BOARD_POD_C2
  Serial.setTxTimeoutMs(0);      // no USB host on a worn pod: drop logs, never block (review E17)
#endif
  Serial.begin(115200);
  nivaBoardBegin();

  psConfigLoad();
  esp_read_mac(psMac, ESP_MAC_WIFI_STA);
  psMacToHex(psMac, psMacHex);
  // Boot id: 32 random bits. esp_random() is a true RNG once the radio runs;
  // before that it is seeded by the bootloader's entropy source. 0 is avoided.
  do { psBootId = esp_random(); } while (psBootId == 0);

  char boot[9];
  psBootToHex(psBootId, boot);
  Serial.printf("{\"t\":\"boot\",\"proto\":%d,\"fw\":\"%s\",\"board\":\"%s\",\"role\":\"%s\",\"role_set\":%s,\"lab\":%s,\"boot\":\"%s\",\"id\":\"%s\",\"reset\":%d}\n",
                PS_PROTO, PS_FW_VERSION, NIVA_BOARD_NAME, psRoleText(psCfg.role), psCfg.roleSet ? "true" : "false",
                psCfg.lab ? "true" : "false", boot, psMacHex, (int)esp_reset_reason());

  if (psCfg.role == PsRole::ANKLE) psHubSetup();
  else psInsoleSetup();
}

void loop() {
  if (psCfg.role == PsRole::ANKLE) psHubLoop();
  else psInsoleLoop();
}
