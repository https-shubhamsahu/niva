// niva_board.h - the two boards Protected Steps runs on, chosen by the build
// target:
//   esp32:esp32:esp32   -> "devkit": the ESP32 DevKit prototypes. FSRs and
//                          piezo on the internal ADC, MPU6050 on I2C 21/22,
//                          LED on GPIO2, BOOT button on GPIO0.
//   esp32:esp32:esp32c3 -> "pod-c2": the Niva pod Rev C.2
//                          (ESP32-C3-MINI-1-N4X). MCP3208 and LSM6DSO32 on one
//                          SPI bus, MAX17048 on I2C GPIO0/GPIO2, red and green
//                          LEDs on GPIO20/21, button on GPIO3. Pin map:
//                          hardware/outputs/NIVA-RevC2-protected-steps/PINMAP.md.
// Everything above this layer (stride detector, matcher, contact detector,
// log, ESP-NOW, BLE) is the same on both boards.

#ifndef NIVA_BOARD_H
#define NIVA_BOARD_H

#include <Arduino.h>

#include "niva_board_logic.h"

#if CONFIG_IDF_TARGET_ESP32C3
#define NIVA_BOARD_POD_C2 1
#define NIVA_BOARD_NAME "pod-c2"
static const uint8_t NIVA_PIN_BUTTON = 3;   // SW1 to GND, R6 10 k pull-up
#elif CONFIG_IDF_TARGET_ESP32
#define NIVA_BOARD_DEVKIT 1
#define NIVA_BOARD_NAME "devkit"
static const uint8_t NIVA_PIN_BUTTON = 0;   // the DevKit BOOT button, active low
#else
#error "Protected Steps supports the ESP32 DevKit and the ESP32-C3 pod only"
#endif

// The ESP32-C3 has one core, so tasks cannot be pinned to core 1 there.
#if CONFIG_FREERTOS_UNICORE
static const BaseType_t NIVA_TASK_CORE = 0;
#else
static const BaseType_t NIVA_TASK_CORE = 1;
#endif

// Buses, LEDs and chip selects. Call once at the top of setup(). On the pod
// it also switches the IMU to SPI-only before any ADC traffic (review A17).
void nivaBoardBegin();

void nivaBoardStatusLed(bool on);   // devkit: GPIO2; pod: green
void nivaBoardFaultLed(bool on);    // pod: red; devkit: no-op

// Insole channels as raw 12-bit counts. ch: 0 heel, 1 inner, 2 outer, 3 toe.
// devkit: internal ADC at 11 dB; pod: MCP3208, ratiometric to VEXC, with
// heel = CH4 (P5), inner = CH1 (P2), outer = CH2 (P3), toe = CH0 (P1).
uint16_t nivaBoardFsrRaw(uint8_t ch);
uint16_t nivaBoardPiezoRaw();

// IMU in raw counts: ax, ay, az, gx, gy, gz. Begin sets +-16 g and the gyro
// range (500 or 2000 dps); the sensitivities depend on the chip.
bool nivaBoardImuBegin(uint16_t gyroDps);
bool nivaBoardImuRead(int16_t raw[6]);
float nivaBoardAccelLsbPerG();
float nivaBoardGyroLsbPerDps();

// Pod: insole tail check from MCP3208 CH6 and CH7. devkit: NOT_SENSED.
NivaTailResult nivaBoardTail();

// Pod: hold both chip selects high through deep sleep (review A2) and turn
// the LEDs off. devkit: LED off.
void nivaBoardPrepareSleep();

#endif  // NIVA_BOARD_H
