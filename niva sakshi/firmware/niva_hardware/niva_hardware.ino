// Niva instrument firmware.
//
// This firmware reports sensor observations; it does not classify gait or
// make a clinical decision. A frame is only marked "valid" after an explicit
// unloaded tare. The phone and dashboard must suppress derived metrics for
// every other state.
//
// Required Arduino libraries:
//   WiFiManager by tzapu, WebSockets by Markus Sattler, U8g2 by olikraus.
// BLEDevice is supplied by the ESP32 Arduino core.

#include <Arduino.h>
#include <WiFi.h>
#include <WebSocketsServer.h>
#include <WiFiManager.h>
#include <ESPmDNS.h>
#include <Wire.h>
#include <U8g2lib.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <stdarg.h>
#include "esp_timer.h"

#include "niva_signal.h"

// Hardware map. All analogue inputs are ADC1 pins, which remain usable while
// Wi-Fi is active on the original ESP32.
static const uint8_t PIN_HEEL = 32;
static const uint8_t PIN_INNER = 33;
static const uint8_t PIN_OUTER = 34;
static const uint8_t PIN_TOE = 35;
static const uint8_t PIN_PIEZO = 36;
static const uint8_t PIN_SDA = 21;
static const uint8_t PIN_SCL = 22;
static const uint8_t PIN_LED = 2;

static const uint16_t WS_PORT = 81;
static const uint16_t TARE_SAMPLES = 100;
static const uint8_t FSR_OVERSAMPLE_COUNT = 16;
static const uint16_t BLE_FRAGMENT_BYTES = 18;  // 20-byte default ATT payload minus framing.

// These UUIDs form the versioned Niva telemetry GATT contract. TX is notified
// by the insole; RX accepts UTF-8 commands such as {"cmd":"tare"}.
static const char* BLE_DEVICE_NAME = "Niva Insole";
static const char* BLE_SERVICE_UUID = "c4f00001-dc50-4c44-a4d8-f0164e510001";
static const char* BLE_RX_UUID = "c4f00002-dc50-4c44-a4d8-f0164e510001";
static const char* BLE_TX_UUID = "c4f00003-dc50-4c44-a4d8-f0164e510001";

enum class ValidityState : uint8_t { uncalibrated, calibrating, valid };

WebSocketsServer wsServer(WS_PORT);
WiFiManager wifiManager;
U8G2_SH1106_128X64_NONAME_F_HW_I2C display(U8G2_R0, U8X8_PIN_NONE);

BLEServer* bleServer = nullptr;
BLECharacteristic* bleTx = nullptr;
bool bleConnected = false;
bool bleWasConnected = false;
bool mdnsStarted = false;

ValidityState validity = ValidityState::uncalibrated;
NivaSensorCal fsr[4];
NivaRollingZero rollingZero[4];
NivaBiquadLPF fsrFilter[4];
NivaPeakHold piezoPeak;
NivaQuietDetector quietDetector;
NivaMahony ahrs;
NivaContactDetector contacts;

// Double precision because the noise estimate is a small difference of two
// large sums (E[x^2] - mean^2), which float cannot resolve.
double tareAccum[4] = {0, 0, 0, 0};
double tareSqAccum[4] = {0, 0, 0, 0};
uint16_t tareCount = 0;
float tareZeroSum = 0.0f;

bool mpuAvailable = false;
bool imuClipped = false;
float pitchDeg = 0.0f;
float rollDeg = 0.0f;
float accZ = 0.0f;
float accelMagnitudeG = 0.0f;

float lastFsr[4] = {0, 0, 0, 0};
float lastPiezo = 0.0f;

uint32_t lastFsrAtUs = 0;
uint32_t lastPiezoAtUs = 0;
uint32_t lastStreamAtUs = 0;
uint32_t lastDisplayAtMs = 0;
uint32_t lastImuAtUs = 0;
uint8_t bleSequence = 0;

// One clock for frames and contact events: milliseconds since boot from the
// 64-bit esp_timer. micros() is 32-bit and wraps after about 71.6 minutes,
// which would break any duration measured across the wrap.
uint64_t deviceMs() {
  return static_cast<uint64_t>(esp_timer_get_time() / 1000);
}

const char* validityText() {
  switch (validity) {
    case ValidityState::valid: return "valid";
    case ValidityState::calibrating: return "calibrating";
    default: return "uncalibrated";
  }
}

float readAveragedADC(uint8_t pin) {
  uint32_t sum = 0;
  for (uint8_t sample = 0; sample < FSR_OVERSAMPLE_COUNT; ++sample) {
    sum += analogRead(pin);
  }
  return static_cast<float>(sum) / FSR_OVERSAMPLE_COUNT;
}

bool readIMU(float& ax, float& ay, float& az, float& gx, float& gy, float& gz) {
  if (!mpuAvailable) return false;

  Wire.beginTransmission(NIVA_MPU_ADDR);
  Wire.write(0x3B);
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(NIVA_MPU_ADDR, 14, true) != 14) {
    return false;
  }

  const int16_t axRaw = (Wire.read() << 8) | Wire.read();
  const int16_t ayRaw = (Wire.read() << 8) | Wire.read();
  const int16_t azRaw = (Wire.read() << 8) | Wire.read();
  Wire.read();
  Wire.read();
  const int16_t gxRaw = (Wire.read() << 8) | Wire.read();
  const int16_t gyRaw = (Wire.read() << 8) | Wire.read();
  const int16_t gzRaw = (Wire.read() << 8) | Wire.read();

  ax = axRaw / NIVA_ACCEL_LSB_16G;
  ay = ayRaw / NIVA_ACCEL_LSB_16G;
  az = azRaw / NIVA_ACCEL_LSB_16G;
  gx = gxRaw / NIVA_GYRO_LSB_500 * DEG_TO_RAD;
  gy = gyRaw / NIVA_GYRO_LSB_500 * DEG_TO_RAD;
  gz = gzRaw / NIVA_GYRO_LSB_500 * DEG_TO_RAD;
  return true;
}

void updateIMU(uint32_t nowUs) {
  float ax, ay, az, gx, gy, gz;
  if (!readIMU(ax, ay, az, gx, gy, gz)) return;

  float dt = (lastImuAtUs == 0) ? 0.01f : (nowUs - lastImuAtUs) / 1000000.0f;
  lastImuAtUs = nowUs;
  if (dt <= 0.0f || dt > 0.1f) dt = 0.01f;

  ahrs.update(ax, ay, az, gx, gy, gz, dt);
  pitchDeg = ahrs.pitchDeg();
  rollDeg = ahrs.rollDeg();
  accZ = az * 9.80665f;
  accelMagnitudeG = sqrtf(ax * ax + ay * ay + az * az);
  imuClipped = fabsf(ax) >= NIVA_CLIP_G || fabsf(ay) >= NIVA_CLIP_G || fabsf(az) >= NIVA_CLIP_G;
}

void resetTare() {
  tareCount = 0;
  tareZeroSum = 0.0f;
  for (uint8_t i = 0; i < 4; ++i) {
    tareAccum[i] = 0.0;
    tareSqAccum[i] = 0.0;
  }
  contacts.reset();
  validity = ValidityState::calibrating;
  digitalWrite(PIN_LED, LOW);
  Serial.println("[TARE] Keep the insole unloaded until tare completes.");
}

void completeTare() {
  tareZeroSum = 0.0f;
  float noise[4];
  for (uint8_t i = 0; i < 4; ++i) {
    const double mean = tareAccum[i] / tareCount;
    const double variance = tareSqAccum[i] / tareCount - mean * mean;
    fsr[i].zero = static_cast<float>(mean);
    fsr[i].zeroAtCal = fsr[i].zero;
    rollingZero[i].begin(fsr[i].zero);
    fsrFilter[i].begin(100.0f, 10.0f);
    tareZeroSum += fsr[i].zero;
    // Unloaded noise in load-index units: the calibration's slope at zero
    // load is c1, so a raw-count sigma scales by |c1|.
    noise[i] = (variance > 0.0 ? static_cast<float>(sqrt(variance)) : 0.0f) * fabsf(fsr[i].c1);
  }
  contacts.begin(noise);
  piezoPeak.reset(analogRead(PIN_PIEZO));
  validity = ValidityState::valid;
  digitalWrite(PIN_LED, HIGH);
  Serial.println("[TARE] Complete. Frames are now eligible for recording.");
  Serial.printf("[CONTACT] noise floor heel=%.1f inner=%.1f outer=%.1f toe=%.1f\n",
                contacts.noiseFloor(0), contacts.noiseFloor(1),
                contacts.noiseFloor(2), contacts.noiseFloor(3));
}

void sampleFsrAndImu(uint32_t nowUs) {
  const float raw[4] = {
    readAveragedADC(PIN_HEEL), readAveragedADC(PIN_INNER),
    readAveragedADC(PIN_OUTER), readAveragedADC(PIN_TOE),
  };
  updateIMU(nowUs);

  float rawSum = 0.0f;
  for (uint8_t i = 0; i < 4; ++i) rawSum += raw[i];
  quietDetector.push(accelMagnitudeG, rawSum);

  if (validity == ValidityState::calibrating) {
    for (uint8_t i = 0; i < 4; ++i) {
      tareAccum[i] += raw[i];
      tareSqAccum[i] += static_cast<double>(raw[i]) * raw[i];
    }
    ++tareCount;
    if (tareCount >= TARE_SAMPLES) completeTare();
    return;
  }
  if (validity != ValidityState::valid) return;

  // A stored zero is intentionally never reused at boot. Only update a zero
  // after the detector observes a stable, unloaded device, never while a foot
  // is bearing weight. The retained sign in NivaSensorCal exposes drift rather
  // than hiding it with an early clamp.
  const bool safelyUnloaded = quietDetector.imuQuiet() && quietDetector.unloaded(tareZeroSum);
  for (uint8_t i = 0; i < 4; ++i) {
    if (rollingZero[i].update(raw[i], safelyUnloaded, true, millis())) {
      fsr[i].zero = rollingZero[i].zero();
    }
    lastFsr[i] = fsrFilter[i].step(fsr[i].apply(raw[i]));
  }
  // Edges are found here at the acquisition rate. Telemetry leaves at 20 Hz,
  // so a client timing edges from frames would only see 50 ms steps.
  contacts.update(lastFsr, deviceMs());
}

void samplePiezo() {
  // This path is deliberately a single fast read plus peak-hold. FSR
  // oversampling and low-pass filtering must never be applied to the impact
  // transient.
  piezoPeak.sample(static_cast<float>(analogRead(PIN_PIEZO)));
}

void drawStatus() {
  display.clearBuffer();
  display.setFont(u8g2_font_6x10_tf);
  display.drawStr(0, 12, "Niva instrument");
  display.drawStr(0, 28, validityText());
  display.drawStr(0, 42, bleConnected ? "BLE connected" : "BLE advertising");
  display.drawStr(0, 56, WiFi.status() == WL_CONNECTED ? "WiFi connected" : "WiFi setup available");
  display.sendBuffer();
}

void startAdvertising() {
  BLEAdvertising* advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->start();
}

class NivaBleServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer*) override { bleConnected = true; }
  void onDisconnect(BLEServer*) override { bleConnected = false; }
};

void handleCommand(const String& command) {
  String normalized = command;
  normalized.trim();
  normalized.toLowerCase();
  if (normalized == "tare" || normalized == "calibrate" || normalized.indexOf("\"tare\"") >= 0) {
    resetTare();
  } else if (normalized == "status") {
    Serial.printf("[STATUS] validity=%s, imuClipped=%s\n", validityText(), imuClipped ? "true" : "false");
  }
}

class NivaBleCommandCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) override {
    const String command = characteristic->getValue().c_str();
    handleCommand(command);
  }
};

void initBle() {
  BLEDevice::init(BLE_DEVICE_NAME);
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new NivaBleServerCallbacks());
  BLEService* service = bleServer->createService(BLE_SERVICE_UUID);
  bleTx = service->createCharacteristic(BLE_TX_UUID, BLECharacteristic::PROPERTY_NOTIFY);
  bleTx->addDescriptor(new BLE2902());
  BLECharacteristic* rx = service->createCharacteristic(BLE_RX_UUID, BLECharacteristic::PROPERTY_WRITE);
  rx->setCallbacks(new NivaBleCommandCallbacks());
  service->start();
  startAdvertising();
}

void sendBleFrame(const char* payload) {
  if (!bleConnected || bleTx == nullptr) return;
  const size_t length = strlen(payload);
  for (size_t offset = 0; offset < length; offset += BLE_FRAGMENT_BYTES) {
    const size_t fragmentLength = min(static_cast<size_t>(BLE_FRAGMENT_BYTES), length - offset);
    uint8_t fragment[BLE_FRAGMENT_BYTES + 2];
    uint8_t flags = offset == 0 ? 0x01 : 0x00;
    if (offset + fragmentLength == length) flags |= 0x02;
    fragment[0] = bleSequence;
    fragment[1] = flags;
    memcpy(fragment + 2, payload + offset, fragmentLength);
    bleTx->setValue(fragment, fragmentLength + 2);
    bleTx->notify();
  }
  ++bleSequence;
}

// Appends printf-style text at frame[len]. Returns false and leaves len
// unchanged if the text would not fit.
static bool appendf(char* buf, size_t cap, size_t& len, const char* fmt, ...)
    __attribute__((format(printf, 4, 5)));
static bool appendf(char* buf, size_t cap, size_t& len, const char* fmt, ...) {
  if (len >= cap) return false;
  va_list args;
  va_start(args, fmt);
  const int n = vsnprintf(buf + len, cap - len, fmt, args);
  va_end(args);
  if (n < 0 || static_cast<size_t>(n) >= cap - len) {
    buf[len] = '\0';
    return false;
  }
  len += static_cast<size_t>(n);
  return true;
}

// Contact events ride inside the telemetry frame rather than as a separate
// message type, so clients that predate them simply ignore three new fields.
// Each entry of "events" is "<code>@<deviceMs>":
//   h+ h- i+ i- o+ o- t+ t-  one sensor (heel, inner, outer, toe) loads or unloads
//   F+x                      the foot loads; x is the sensor that loaded first,
//                            or * when two sensors crossed on the same sample
//   F-                       the last loaded sensor unloads
static const char kChannelCode[4] = {'h', 'i', 'o', 't'};
static const uint8_t kMaxEventsPerFrame = 16;   // the rest wait for the next frame
static const size_t kFrameTailReserve = 64;     // room for the closing fields

void publishFrame() {
  const float impact = piezoPeak.consume();
  if (validity == ValidityState::valid) lastPiezo = impact;

  // Keep the legacy field names so existing Wi-Fi Flutter/web clients remain
  // compatible. `validity`, `sampleHz` and `imuClipped` make transport and
  // measurement limits explicit for new clients.
  static char frame[1024];
  size_t len = 0;
  const unsigned long long timestampMs = deviceMs();
  if (validity == ValidityState::valid) {
    appendf(frame, sizeof(frame), len,
      "{\"deviceTimestampMs\":%llu,\"heel\":%.2f,\"inner\":%.2f,\"outer\":%.2f,\"toe\":%.2f,\"piezo\":%.2f,\"impact\":%.2f,\"pitch\":%.2f,\"roll\":%.2f,\"accZ\":%.2f,\"validity\":\"valid\",\"sampleHz\":100,\"imuClipped\":%s,\"contact\":%u,\"events\":[",
      timestampMs, lastFsr[0], lastFsr[1], lastFsr[2], lastFsr[3], lastPiezo, lastPiezo,
      pitchDeg, rollDeg, accZ, imuClipped ? "true" : "false",
      static_cast<unsigned>(contacts.mask()));

    uint8_t written = 0;
    NivaContactEvent e;
    while (written < kMaxEventsPerFrame && sizeof(frame) - len > kFrameTailReserve &&
           contacts.queue().pop(e)) {
      char code[4] = {0, 0, 0, 0};
      const bool on = e.edge == NIVA_EDGE_ON;
      if (e.channel == NIVA_FOOT) {
        code[0] = 'F';
        code[1] = on ? '+' : '-';
        if (on) code[2] = (e.first == NIVA_TIE) ? '*' : kChannelCode[static_cast<uint8_t>(e.first)];
      } else {
        code[0] = kChannelCode[static_cast<uint8_t>(e.channel)];
        code[1] = on ? '+' : '-';
      }
      if (appendf(frame, sizeof(frame), len, "%s\"%s@%llu\"", written == 0 ? "" : ",",
                  code, static_cast<unsigned long long>(e.tMs))) {
        ++written;
      }
    }
    appendf(frame, sizeof(frame), len, "],\"eventsDropped\":%lu}",
            static_cast<unsigned long>(contacts.queue().dropped()));
  } else {
    appendf(frame, sizeof(frame), len,
      "{\"deviceTimestampMs\":%llu,\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"piezo\":0,\"impact\":0,\"pitch\":0,\"roll\":0,\"accZ\":0,\"validity\":\"%s\",\"sampleHz\":100,\"imuClipped\":false,\"contact\":0,\"events\":[],\"eventsDropped\":0}",
      timestampMs, validityText());
  }
  wsServer.broadcastTXT(frame);
  sendBleFrame(frame);
  Serial.println(frame);
}

void initMpu6050() {
  Wire.beginTransmission(NIVA_MPU_ADDR);
  Wire.write(0x6B);
  Wire.write(0x00);
  if (Wire.endTransmission() != 0 || !nivaConfigureIMU(Wire)) {
    Serial.println("[IMU] Not available; pitch, roll and acceleration are unavailable.");
    mpuAvailable = false;
    return;
  }
  ahrs.begin();
  mpuAvailable = true;
}

void initNetwork() {
  WiFi.mode(WIFI_STA);
  WiFi.begin();  // reconnect only if credentials were already stored
  wifiManager.setConfigPortalBlocking(false);
  wifiManager.setConfigPortalTimeout(180);
  wifiManager.startConfigPortal("NIVA-GaitGuard-AP", "gaitguard123");
  wsServer.begin();
  wsServer.onEvent([](uint8_t, WStype_t type, uint8_t* payload, size_t length) {
    if (type != WStype_TEXT) return;
    String command;
    command.reserve(length);
    for (size_t i = 0; i < length; ++i) command += static_cast<char>(payload[i]);
    handleCommand(command);
  });
}

void maintainNetwork() {
  wifiManager.process();
  if (WiFi.status() == WL_CONNECTED && !mdnsStarted) {
    mdnsStarted = MDNS.begin("niva");
    if (mdnsStarted) MDNS.addService("ws", "tcp", WS_PORT);
  }
}

void setup() {
  Serial.begin(115200);
  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);
  analogReadResolution(12);
  analogSetAttenuation(ADC_11db);
  Wire.begin(PIN_SDA, PIN_SCL, 400000);
  display.begin();
  quietDetector.begin();
  initMpu6050();
  initBle();
  initNetwork();
  drawStatus();
  Serial.println("[SYSTEM] Niva ready. Connect by BLE or WebSocket, then tare unloaded.");
}

void loop() {
  wsServer.loop();
  maintainNetwork();
  if (Serial.available()) handleCommand(Serial.readStringUntil('\n'));

  const uint32_t nowUs = micros();
  if (nowUs - lastPiezoAtUs >= NIVA_PIEZO_PERIOD_US) {
    lastPiezoAtUs = nowUs;
    samplePiezo();
  }
  if (nowUs - lastFsrAtUs >= NIVA_FSR_PERIOD_US) {
    lastFsrAtUs = nowUs;
    sampleFsrAndImu(nowUs);
  }
  if (nowUs - lastStreamAtUs >= NIVA_STREAM_PERIOD_US) {
    lastStreamAtUs = nowUs;
    publishFrame();
  }
  if (!bleConnected && bleWasConnected) startAdvertising();
  bleWasConnected = bleConnected;

  if (millis() - lastDisplayAtMs >= 250) {
    lastDisplayAtMs = millis();
    drawStatus();
  }
}
