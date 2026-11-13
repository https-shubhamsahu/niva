// niva_board.cpp - see niva_board.h. Not host-tested (needs the hardware);
// the register and frame logic it uses is in niva_board_logic.h and tested.

#include "niva_board.h"

#include <Wire.h>

#if NIVA_BOARD_POD_C2

#include <SPI.h>
#include <driver/gpio.h>

// Pod Rev C.2 pins (PINMAP.md section 1).
static const uint8_t PIN_SDA = 0, PIN_SCL = 2;
static const uint8_t PIN_SCK = 4, PIN_MISO = 5, PIN_MOSI = 6;
static const uint8_t PIN_CS_ADC = 7, PIN_CS_IMU = 10;
static const uint8_t PIN_LED_R = 20, PIN_LED_G = 21;

// MCP3208: 1 MHz keeps inside its 2.7 V clock limit with margin (ELECTRICAL-
// REVIEW section 3). LSM6DSO32: SPI mode 3, 10 MHz maximum; 8 MHz used.
static const SPISettings ADC_SPI(1000000, MSBFIRST, SPI_MODE0);
static const SPISettings IMU_SPI(8000000, MSBFIRST, SPI_MODE3);

static const uint8_t ADC_CH[4] = {4, 1, 2, 0};   // heel P5, inner P2, outer P3, toe P1
static const uint8_t ADC_CH_PIEZO = 5, ADC_CH_V33_HALF = 6, ADC_CH_INSERT_ID = 7;

static uint16_t gyroDps = 500;

static uint16_t adcRead(uint8_t ch) {
  uint8_t tx[3], rx[3];
  nivaMcp3208Command(ch, tx);
  SPI.beginTransaction(ADC_SPI);
  digitalWrite(PIN_CS_ADC, LOW);
  SPI.transferBytes(tx, rx, 3);   // one call per frame: 64 of these every 10 ms
  digitalWrite(PIN_CS_ADC, HIGH);
  SPI.endTransaction();
  return nivaMcp3208Result(rx);
}

static void imuWrite(uint8_t reg, uint8_t v) {
  SPI.beginTransaction(IMU_SPI);
  digitalWrite(PIN_CS_IMU, LOW);
  SPI.transfer(reg);
  SPI.transfer(v);
  digitalWrite(PIN_CS_IMU, HIGH);
  SPI.endTransaction();
}

static void imuReadBytes(uint8_t reg, uint8_t* out, size_t n) {
  SPI.beginTransaction(IMU_SPI);
  digitalWrite(PIN_CS_IMU, LOW);
  SPI.transfer(reg | NIVA_LSM6_SPI_READ);
  SPI.transferBytes(nullptr, out, n);   // clocks out 0xFF; the IMU ignores SDI after a read address
  digitalWrite(PIN_CS_IMU, HIGH);
  SPI.endTransaction();
}

void nivaBoardBegin() {
  // Release the deep-sleep holds first, then take the chip selects high.
  gpio_hold_dis((gpio_num_t)PIN_CS_ADC);
  gpio_hold_dis((gpio_num_t)PIN_CS_IMU);
  gpio_deep_sleep_hold_dis();
  pinMode(PIN_CS_ADC, OUTPUT);
  digitalWrite(PIN_CS_ADC, HIGH);
  pinMode(PIN_CS_IMU, OUTPUT);
  digitalWrite(PIN_CS_IMU, HIGH);
  pinMode(PIN_LED_R, OUTPUT);
  digitalWrite(PIN_LED_R, LOW);
  pinMode(PIN_LED_G, OUTPUT);
  digitalWrite(PIN_LED_G, LOW);
  pinMode(NIVA_PIN_BUTTON, INPUT);   // R6 is the pull-up
  SPI.begin(PIN_SCK, PIN_MISO, PIN_MOSI, -1);
  // The IMU powers up with I2C enabled on the SPI wires. Its first transfer
  // must turn that off, before any MCP3208 traffic can look like an I2C
  // start to it (review A17).
  imuWrite(NIVA_LSM6_CTRL4_C, NIVA_LSM6_CTRL4_I2C_DISABLE);
  Wire.begin(PIN_SDA, PIN_SCL, 100000);   // MAX17048, 100 kHz (review A26)
}

void nivaBoardStatusLed(bool on) { digitalWrite(PIN_LED_G, on ? HIGH : LOW); }
void nivaBoardFaultLed(bool on) { digitalWrite(PIN_LED_R, on ? HIGH : LOW); }

uint16_t nivaBoardFsrRaw(uint8_t ch) { return ch < 4 ? adcRead(ADC_CH[ch]) : 0; }
uint16_t nivaBoardPiezoRaw() { return adcRead(ADC_CH_PIEZO); }

bool nivaBoardImuBegin(uint16_t dps) {
  gyroDps = dps >= 2000 ? 2000 : 500;
  uint8_t id = 0;
  imuReadBytes(NIVA_LSM6_WHO_AM_I, &id, 1);
  if (id != NIVA_LSM6_ID) return false;
  imuWrite(NIVA_LSM6_CTRL3_C, NIVA_LSM6_CTRL3_BDU_IF_INC);
  imuWrite(NIVA_LSM6_CTRL4_C, NIVA_LSM6_CTRL4_I2C_DISABLE);
  imuWrite(NIVA_LSM6_CTRL1_XL, nivaLsm6Ctrl1Xl());
  imuWrite(NIVA_LSM6_CTRL2_G, nivaLsm6Ctrl2G(gyroDps));
  uint8_t back = 0;
  imuReadBytes(NIVA_LSM6_CTRL2_G, &back, 1);
  return back == nivaLsm6Ctrl2G(gyroDps);
}

bool nivaBoardImuRead(int16_t raw[6]) {
  uint8_t b[12];
  imuReadBytes(NIVA_LSM6_OUTX_L_G, b, sizeof(b));
  nivaLsm6Unpack(b, raw);
  return true;   // SPI has no acknowledge; a dead IMU shows up as frozen data in PsImuValidity
}

float nivaBoardAccelLsbPerG() { return NIVA_LSM6_ACCEL_LSB_PER_G; }
float nivaBoardGyroLsbPerDps() { return nivaLsm6GyroLsbPerDps(gyroDps); }

NivaTailResult nivaBoardTail() { return nivaClassifyTail(adcRead(ADC_CH_V33_HALF), adcRead(ADC_CH_INSERT_ID)); }

void nivaBoardPrepareSleep() {
  digitalWrite(PIN_LED_R, LOW);
  digitalWrite(PIN_LED_G, LOW);
  // The LSM6DSO32 keeps its settings through ESP32 resets and deep sleep, so
  // it would stay at 104 Hz (about 0.5 mA). ODR 0 powers both sensors down.
  imuWrite(NIVA_LSM6_CTRL1_XL, 0x00);
  imuWrite(NIVA_LSM6_CTRL2_G, 0x00);
  digitalWrite(PIN_CS_ADC, HIGH);   // MCP3208 standby needs CS high (review A2)
  digitalWrite(PIN_CS_IMU, HIGH);
  gpio_hold_en((gpio_num_t)PIN_CS_ADC);
  gpio_hold_en((gpio_num_t)PIN_CS_IMU);
  gpio_deep_sleep_hold_en();
}

#else  // NIVA_BOARD_DEVKIT

#include "niva_signal.h"   // NIVA_MPU_ADDR and the MPU6050 scale factors

static const uint8_t PIN_FSR[4] = {32, 33, 34, 35};   // heel, inner, outer, toe
static const uint8_t PIN_PIEZO = 36;
static const uint8_t PIN_SDA = 21, PIN_SCL = 22;
static const uint8_t PIN_LED = 2;

static uint16_t gyroDps = 500;

static bool mpuWrite(uint8_t reg, uint8_t v) {
  Wire.beginTransmission(NIVA_MPU_ADDR);
  Wire.write(reg);
  Wire.write(v);
  return Wire.endTransmission() == 0;
}

void nivaBoardBegin() {
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  Wire.begin(PIN_SDA, PIN_SCL, 400000);
}

void nivaBoardStatusLed(bool on) { digitalWrite(PIN_LED, on ? HIGH : LOW); }
void nivaBoardFaultLed(bool) {}

uint16_t nivaBoardFsrRaw(uint8_t ch) { return ch < 4 ? (uint16_t)analogRead(PIN_FSR[ch]) : 0; }
uint16_t nivaBoardPiezoRaw() { return (uint16_t)analogRead(PIN_PIEZO); }

// As before: wake, +-16 g, gyro 500 dps (insole) or 2000 dps (hub), DLPF 44 Hz.
bool nivaBoardImuBegin(uint16_t dps) {
  gyroDps = dps >= 2000 ? 2000 : 500;
  return mpuWrite(0x6B, 0x00) && mpuWrite(0x1C, 0x18) && mpuWrite(0x1B, gyroDps == 2000 ? 0x18 : 0x08) &&
         mpuWrite(0x1A, 0x03);
}

bool nivaBoardImuRead(int16_t raw[6]) {
  Wire.beginTransmission(NIVA_MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(NIVA_MPU_ADDR, (size_t)14, true) != 14) return false;
  uint8_t b[14];
  for (int i = 0; i < 14; ++i) b[i] = (uint8_t)Wire.read();
  raw[0] = (int16_t)((b[0] << 8) | b[1]);
  raw[1] = (int16_t)((b[2] << 8) | b[3]);
  raw[2] = (int16_t)((b[4] << 8) | b[5]);
  raw[3] = (int16_t)((b[8] << 8) | b[9]);
  raw[4] = (int16_t)((b[10] << 8) | b[11]);
  raw[5] = (int16_t)((b[12] << 8) | b[13]);
  return true;
}

float nivaBoardAccelLsbPerG() { return NIVA_ACCEL_LSB_16G; }
float nivaBoardGyroLsbPerDps() { return gyroDps == 2000 ? 16.4f : NIVA_GYRO_LSB_500; }

NivaTailResult nivaBoardTail() { return {NivaTail::NOT_SENSED, '?'}; }

void nivaBoardPrepareSleep() { digitalWrite(PIN_LED, LOW); }

#endif
