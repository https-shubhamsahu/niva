// GaitGuard Nexus firmware + SH1106 OLED status display
//
// NIVA GaitGuard ESP32 sketch — WiFiManager captive-portal WiFi setup, a
// real MPU6050 IMU feeding pitch/roll/accZ, NVS-persisted FSR baselines,
// mDNS (ws://niva.local:81), and oversampled ADC reads — with a 1.3" I2C
// OLED (SH1106 driver, confirmed via I2C scan at address 0x3C) added on
// top, showing boot status, WiFi/captive-portal state, calibration
// progress, and a live per-channel bar readout once the insole is
// streaming. Everything else is unchanged.
//
// The OLED shares the same I2C bus as the MPU6050 (SDA=21, SCL=22) at a
// different address, so no extra wiring is needed beyond the display itself.
//
// Requires:
//   - WiFiManager by tzapu (https://github.com/tzapu/WiFiManager)
//   - U8g2 by olikraus (Library Manager -> search "U8g2")

#include <WiFi.h>
#include <WebSocketsServer.h>
#include <WiFiManager.h>      // WiFiManager by tzapu (https://github.com/tzapu/WiFiManager)
#include <ESPmDNS.h>
#include <Wire.h>
#include <Preferences.h>
#include <U8g2lib.h>          // U8g2 by olikraus (Library Manager -> search "U8g2")

// -----------------------------------------------------------------------------
// Hardware Pin Map (NIVA GaitGuard Nexus Spec)
// -----------------------------------------------------------------------------
static const int PIN_HEEL   = 32; // FSR Heel (ADC1_CH4)
static const int PIN_INNER  = 33; // FSR Inner / MT1 (ADC1_CH5)
static const int PIN_OUTER  = 34; // FSR Outer / MT5 (ADC1_CH6)
static const int PIN_TOE    = 35; // FSR Toe (ADC1_CH7)
static const int PIN_PIEZO  = 36; // Piezo Heel Disc (ADC1_CH0 / SENSOR_VP)

static const int PIN_SDA    = 21; // Shared I2C bus: MPU6050 (0x68) + OLED (0x3C)
static const int PIN_SCL    = 22;
static const int PIN_LED    = 2;  // Onboard Status LED

// -----------------------------------------------------------------------------
// Configuration Constants
// -----------------------------------------------------------------------------
static const unsigned long STREAM_INTERVAL_MS = 50;  // 20Hz telemetry stream interval
static const uint16_t CALIBRATION_SAMPLES = 60;      // Baseline tare sample count
static const uint8_t ADC_OVERSAMPLE_COUNT = 16;      // Oversampling iterations per channel
static const uint16_t WS_PORT = 81;                  // WebSocket server port
static const int MPU6050_ADDR = 0x68;                 // MPU6050 default I2C address

// Redrawn on its own slower clock so a full 128x64 I2C frame write never
// competes with the 50ms sensor/WebSocket cadence above.
static const unsigned long DISPLAY_INTERVAL_MS = 200;

// Reference ceiling used only to scale the on-screen bar graphs (0..this
// maps to an empty..full bar). Matches the dashboard's own impact-scaling
// reference (`maxImpact: 800`) so the bars roughly agree with what the app
// would call "high" — it isn't a calibration value, just a display scale.
static const float DISPLAY_BAR_MAX = 800.0f;

// -----------------------------------------------------------------------------
// Global Objects & State Variables
// -----------------------------------------------------------------------------
WebSocketsServer wsServer(WS_PORT);
Preferences preferences;

// Full-buffer, hardware I2C SH1106 driver. If your panel turns out to be
// SSD1306 instead (see the fallback note at the bottom of this file), swap
// this one line and nothing else needs to change.
U8G2_SH1106_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);

struct SensorBaselines {
  float heel = 0.0f;
  float inner = 0.0f;
  float outer = 0.0f;
  float toe = 0.0f;
  float piezo = 0.0f;
} baselines;

bool isCalibrated = false;
bool mpuAvailable = false;
uint16_t calibrationCount = 0;
float calAccumHeel = 0.0f, calAccumInner = 0.0f, calAccumOuter = 0.0f, calAccumToe = 0.0f, calAccumPiezo = 0.0f;

// Kinematics (MPU6050 IMU)
float pitchDeg = 0.0f;
float rollDeg = 0.0f;
float accZ = 9.81f; // m/s^2
unsigned long lastKinematicsUpdate = 0;

// Cached post-baseline channel values so the display loop can redraw at its
// own cadence without re-reading the ADCs itself.
float lastHeel = 0.0f;
float lastInner = 0.0f;
float lastOuter = 0.0f;
float lastToe = 0.0f;
float lastPiezo = 0.0f;

// Timing
unsigned long lastStreamAt = 0;
unsigned long lastDisplayAt = 0;

// -----------------------------------------------------------------------------
// Function Prototypes
// -----------------------------------------------------------------------------
void initMPU6050();
void updateKinematics();
float oversampleADC(int pin);
void performCalibrationStep(float rawH, float rawI, float rawO, float rawT, float rawP);
void saveBaselinesToNVS();
void loadBaselinesFromNVS();
void handleWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length);
void handleIncomingCommand(const String& cmd);

// -----------------------------------------------------------------------------
// Display Helpers
// -----------------------------------------------------------------------------
void showBootScreen() {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_ncenB10_tr);
  u8g2.drawStr(6, 22, "GaitGuard Nexus");
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.drawStr(6, 40, "Booting...");
  u8g2.sendBuffer();
}

void showWiFiPortalActive() {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_ncenB10_tr);
  u8g2.drawStr(6, 22, "GaitGuard Nexus");
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.drawStr(6, 38, "Setup WiFi at:");
  u8g2.drawStr(6, 52, "NIVA-GaitGuard-AP");
  u8g2.sendBuffer();
}

void showWiFiResult(bool connected) {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_ncenB10_tr);
  u8g2.drawStr(6, 22, "GaitGuard Nexus");
  u8g2.setFont(u8g2_font_6x10_tf);

  if (connected) {
    u8g2.drawStr(6, 38, "WiFi connected");
    char ipLine[24];
    snprintf(ipLine, sizeof(ipLine), "IP %s", WiFi.localIP().toString().c_str());
    u8g2.drawStr(6, 52, ipLine);
  } else {
    u8g2.drawStr(6, 38, "Setup timed out");
    u8g2.drawStr(6, 52, "Offline AP mode");
  }
  u8g2.sendBuffer();
  delay(1200); // let the result be readable before the calibration screen takes over
}

void showCalibrating(uint16_t count, uint16_t total) {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.drawStr(6, 12, "Calibrating...");
  u8g2.drawStr(6, 26, "Keep foot unloaded");

  // Progress bar.
  const int barX = 6;
  const int barY = 36;
  const int barW = 116;
  const int barH = 10;
  u8g2.drawFrame(barX, barY, barW, barH);
  int fillW = (int)((float)count / (float)total * (barW - 2));
  if (fillW > barW - 2) fillW = barW - 2;
  if (fillW > 0) u8g2.drawBox(barX + 1, barY + 1, fillW, barH - 2);

  char countLine[16];
  snprintf(countLine, sizeof(countLine), "%u / %u", count, total);
  u8g2.drawStr(6, 60, countLine);

  u8g2.sendBuffer();
}

// One labeled horizontal bar: "H |####------|"
void drawChannelBar(int y, const char* label, float value) {
  u8g2.setFont(u8g2_font_5x8_tf);
  u8g2.drawStr(0, y + 7, label);

  const int barX = 12;
  const int barW = 100;
  const int barH = 8;
  u8g2.drawFrame(barX, y, barW, barH);

  float clamped = value;
  if (clamped < 0) clamped = 0;
  if (clamped > DISPLAY_BAR_MAX) clamped = DISPLAY_BAR_MAX;

  int fillW = (int)((clamped / DISPLAY_BAR_MAX) * (barW - 2));
  if (fillW > 0) u8g2.drawBox(barX + 1, y + 1, fillW, barH - 2);
}

void showLiveReadout(bool wifiConnected) {
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_5x8_tf);
  u8g2.drawStr(0, 7, wifiConnected ? "WiFi OK" : "WiFi --");
  u8g2.drawStr(70, 7, mpuAvailable ? "IMU OK" : "IMU --");

  drawChannelBar(11, "H", lastHeel);
  drawChannelBar(21, "I", lastInner);
  drawChannelBar(31, "O", lastOuter);
  drawChannelBar(41, "T", lastToe);
  drawChannelBar(51, "P", lastPiezo);

  u8g2.sendBuffer();
}

// -----------------------------------------------------------------------------
// MPU6050 Wire-based Kinematics Processing
// -----------------------------------------------------------------------------
void initMPU6050() {
  // Wire.begin() is already called in setup() so the OLED and IMU can share
  // the same hardware I2C bus.
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x6B); // PWR_MGMT_1 register
  Wire.write(0x00); // Wake up MPU6050
  if (Wire.endTransmission() == 0) {
    mpuAvailable = true;
    Serial.println("[IMU] MPU6050 initialized successfully at 0x68");
  } else {
    mpuAvailable = false;
    Serial.println("[IMU] WARNING: MPU6050 not detected at 0x68. Kinematics set to fallback (0.0).");
  }
}

void updateKinematics() {
  if (!mpuAvailable) {
    pitchDeg = 0.0f;
    rollDeg = 0.0f;
    accZ = 0.0f;
    return;
  }

  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x3B); // ACCEL_XOUT_H
  if (Wire.endTransmission(false) != 0) return;

  if (Wire.requestFrom(MPU6050_ADDR, 14, true) == 14) {
    int16_t axRaw = (Wire.read() << 8) | Wire.read();
    int16_t ayRaw = (Wire.read() << 8) | Wire.read();
    int16_t azRaw = (Wire.read() << 8) | Wire.read();
    Wire.read(); Wire.read(); // Skip temp bytes
    int16_t gxRaw = (Wire.read() << 8) | Wire.read();
    int16_t gyRaw = (Wire.read() << 8) | Wire.read();
    int16_t gzRaw = (Wire.read() << 8) | Wire.read();

    float ax = axRaw / 16384.0f; // Scale factor for +/-2g
    float ay = ayRaw / 16384.0f;
    float az = azRaw / 16384.0f;

    float gx = gxRaw / 131.0f; // Scale factor for +/-250 deg/s
    float gy = gyRaw / 131.0f;

    // Calculate Accelerometer Angles
    float accelPitch = atan2(-ax, sqrt(ay * ay + az * az)) * 180.0f / M_PI;
    float accelRoll  = atan2(ay, az) * 180.0f / M_PI;

    // Complementary Filter Fusion (96% Gyro, 4% Accel)
    unsigned long now = millis();
    float dt = (now - lastKinematicsUpdate) / 1000.0f;
    if (dt <= 0.0f || dt > 0.5f) dt = 0.01f;
    lastKinematicsUpdate = now;

    pitchDeg = 0.96f * (pitchDeg + gy * dt) + 0.04f * accelPitch;
    rollDeg  = 0.96f * (rollDeg + gx * dt) + 0.04f * accelRoll;
    accZ     = az * 9.81f; // Convert g to m/s^2
  }
}

// -----------------------------------------------------------------------------
// Low-Noise Oversampled Analog Read
// -----------------------------------------------------------------------------
float oversampleADC(int pin) {
  uint32_t sum = 0;
  for (uint8_t i = 0; i < ADC_OVERSAMPLE_COUNT; i++) {
    sum += analogRead(pin);
  }
  return static_cast<float>(sum) / ADC_OVERSAMPLE_COUNT;
}

// -----------------------------------------------------------------------------
// Calibration Logic & Non-Volatile Storage (NVS)
// -----------------------------------------------------------------------------
void performCalibrationStep(float rawH, float rawI, float rawO, float rawT, float rawP) {
  calibrationCount++;
  calAccumHeel  += rawH;
  calAccumInner += rawI;
  calAccumOuter += rawO;
  calAccumToe   += rawT;
  calAccumPiezo += rawP;

  // Toggle status LED during calibration phase
  digitalWrite(PIN_LED, (calibrationCount % 2 == 0) ? HIGH : LOW);

  if (calibrationCount >= CALIBRATION_SAMPLES) {
    baselines.heel  = calAccumHeel  / CALIBRATION_SAMPLES;
    baselines.inner = calAccumInner / CALIBRATION_SAMPLES;
    baselines.outer = calAccumOuter / CALIBRATION_SAMPLES;
    baselines.toe   = calAccumToe   / CALIBRATION_SAMPLES;
    baselines.piezo = calAccumPiezo / CALIBRATION_SAMPLES;

    isCalibrated = true;
    saveBaselinesToNVS();

    Serial.println("[CALIBRATION] Tare Baseline Complete!");
    Serial.printf("[CALIBRATION] Baselines -> Heel:%.1f, Inner:%.1f, Outer:%.1f, Toe:%.1f, Piezo:%.1f\n",
                  baselines.heel, baselines.inner, baselines.outer, baselines.toe, baselines.piezo);
    digitalWrite(PIN_LED, HIGH);
  }
}

void saveBaselinesToNVS() {
  preferences.begin("gaitguard", false);
  preferences.putFloat("b_heel", baselines.heel);
  preferences.putFloat("b_inner", baselines.inner);
  preferences.putFloat("b_outer", baselines.outer);
  preferences.putFloat("b_toe", baselines.toe);
  preferences.putFloat("b_piezo", baselines.piezo);
  preferences.putBool("calibrated", true);
  preferences.end();
}

void loadBaselinesFromNVS() {
  preferences.begin("gaitguard", true);
  bool saved = preferences.getBool("calibrated", false);
  if (saved) {
    baselines.heel  = preferences.getFloat("b_heel", 0.0f);
    baselines.inner = preferences.getFloat("b_inner", 0.0f);
    baselines.outer = preferences.getFloat("b_outer", 0.0f);
    baselines.toe   = preferences.getFloat("b_toe", 0.0f);
    baselines.piezo = preferences.getFloat("b_piezo", 0.0f);
    isCalibrated = true;
    Serial.println("[NVS] Loaded saved tare baselines from Flash storage.");
  }
  preferences.end();
}

// -----------------------------------------------------------------------------
// WebSocket Event & Interactive Command Handlers
// -----------------------------------------------------------------------------
void handleWebSocketEvent(uint8_t num, WStype_t type, uint8_t * payload, size_t length) {
  if (type == WStype_TEXT) {
    String cmd = String((char*)payload);
    cmd.trim();
    Serial.printf("[WS] Client #%u sent command: %s\n", num, cmd.c_str());
    handleIncomingCommand(cmd);
  } else if (type == WStype_CONNECTED) {
    IPAddress ip = wsServer.remoteIP(num);
    Serial.printf("[WS] Client #%u connected from %d.%d.%d.%d\n", num, ip[0], ip[1], ip[2], ip[3]);
  }
}

void handleIncomingCommand(const String& cmd) {
  if (cmd.equalsIgnoreCase("calibrate") || cmd.equalsIgnoreCase("tare") || cmd.indexOf("calibrate") >= 0) {
    Serial.println("[CMD] Initiating runtime FSR re-tare...");
    isCalibrated = false;
    calibrationCount = 0;
    calAccumHeel = calAccumInner = calAccumOuter = calAccumToe = calAccumPiezo = 0.0f;
  }
}

// -----------------------------------------------------------------------------
// Main Setup and Execution Loop
// -----------------------------------------------------------------------------
void setup() {
  Serial.begin(115200);
  delay(300);

  // Bring the I2C bus up first (shared by the OLED and MPU6050) so the boot
  // screen can show immediately.
  Wire.begin(PIN_SDA, PIN_SCL, 400000); // 400kHz Fast I2C
  u8g2.begin();
  showBootScreen();

  pinMode(PIN_LED, OUTPUT);
  digitalWrite(PIN_LED, LOW);

  analogReadResolution(12);
  analogSetAttenuation(ADC_11db); // Full 0-3.3V range

  pinMode(PIN_HEEL, INPUT);
  pinMode(PIN_INNER, INPUT);
  pinMode(PIN_OUTER, INPUT);
  pinMode(PIN_TOE, INPUT);
  pinMode(PIN_PIEZO, INPUT);

  // Initialize IMU
  initMPU6050();

  // Restore saved baselines from Flash NVS if present
  loadBaselinesFromNVS();

  // WiFiManager captive portal
  WiFiManager wm;
  wm.setConfigPortalTimeout(180); // 3-minute AP timeout before proceeding
  wm.setAPCallback([](WiFiManager *myWM) {
    Serial.println("[WIFI] Captive Portal Active! Connect phone to AP: NIVA-GaitGuard-AP (IP: 192.168.4.1)");
    showWiFiPortalActive();
  });

  Serial.println("[WIFI] Connecting to WiFi...");
  bool res = wm.autoConnect("NIVA-GaitGuard-AP", "gaitguard123");

  if (!res) {
    Serial.println("[WIFI] WiFi setup timed out. Proceeding in offline AP fallback mode.");
  } else {
    Serial.println("[WIFI] WiFi Connected Successfully!");
    Serial.print("[WIFI] ESP32 Local IP: ");
    Serial.println(WiFi.localIP());
  }
  showWiFiResult(res);

  // Setup mDNS hostnames (ws://niva.local:81 and ws://gaitguard.local:81)
  if (MDNS.begin("niva")) {
    MDNS.addService("ws", "tcp", WS_PORT);
    Serial.println("[mDNS] Hostname registered: ws://niva.local:81");
  }
  if (MDNS.begin("gaitguard")) {
    MDNS.addService("ws", "tcp", WS_PORT);
  }

  // Start WebSocket Server
  wsServer.begin();
  wsServer.onEvent(handleWebSocketEvent);

  Serial.println("[SYSTEM] NIVA GaitGuard ESP32 System Ready!");
}

void loop() {
  wsServer.loop();
  updateKinematics();

  // Check incoming Serial commands
  if (Serial.available()) {
    String serialCmd = Serial.readStringUntil('\n');
    handleIncomingCommand(serialCmd);
  }

  unsigned long now = millis();
  if (now - lastStreamAt < STREAM_INTERVAL_MS) {
    // Still let the display redraw on its own cadence even on ticks where
    // we skip sensor sampling, so WiFi/IMU status changes show up promptly.
    if (now - lastDisplayAt >= DISPLAY_INTERVAL_MS) {
      lastDisplayAt = now;
      if (isCalibrated) {
        showLiveReadout(WiFi.status() == WL_CONNECTED);
      } else {
        showCalibrating(calibrationCount, CALIBRATION_SAMPLES);
      }
    }
    return;
  }
  lastStreamAt = now;

  // Read oversampled ADC values
  float rawHeel  = oversampleADC(PIN_HEEL);
  float rawInner = oversampleADC(PIN_INNER);
  float rawOuter = oversampleADC(PIN_OUTER);
  float rawToe   = oversampleADC(PIN_TOE);
  float rawPiezo = oversampleADC(PIN_PIEZO);

  if (!isCalibrated) {
    performCalibrationStep(rawHeel, rawInner, rawOuter, rawToe, rawPiezo);

    // Send zero telemetry frame during tare phase
    const char* calPacket = "{\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"piezo\":0,\"pitch\":0,\"roll\":0,\"accZ\":0}";
    wsServer.broadcastTXT(calPacket);
    Serial.println("CALIBRATING,0,0,0,0,0,0,0,0");
    return;
  }

  // Apply baselines and clamp minimum to zero
  float heel  = max(0.0f, rawHeel  - baselines.heel);
  float inner = max(0.0f, rawInner - baselines.inner);
  float outer = max(0.0f, rawOuter - baselines.outer);
  float toe   = max(0.0f, rawToe   - baselines.toe);
  float piezo = max(0.0f, rawPiezo - baselines.piezo);

  lastHeel = heel;
  lastInner = inner;
  lastOuter = outer;
  lastToe = toe;
  lastPiezo = piezo;

  // Broadcast WebSocket JSON frame
  char jsonPayload[256];
  snprintf(
    jsonPayload,
    sizeof(jsonPayload),
    "{\"heel\":%.2f,\"inner\":%.2f,\"outer\":%.2f,\"toe\":%.2f,\"piezo\":%.2f,\"pitch\":%.2f,\"roll\":%.2f,\"accZ\":%.2f}",
    heel, inner, outer, toe, piezo, pitchDeg, rollDeg, accZ
  );
  wsServer.broadcastTXT(jsonPayload);

  // Output USB Serial CSV (Compatible with NIVA web serial parser)
  Serial.printf("%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",
                heel, inner, outer, toe, piezo, pitchDeg, rollDeg, accZ);

  if (now - lastDisplayAt >= DISPLAY_INTERVAL_MS) {
    lastDisplayAt = now;
    showLiveReadout(WiFi.status() == WL_CONNECTED);
  }
}

// -----------------------------------------------------------------------------
// If the display stays blank
// -----------------------------------------------------------------------------
// 1. Try U8G2_SH1106_128X64_VCOMH0_F_HW_I2C instead of ...NONAME_F_HW_I2C
//    (same line, both declaration above and nowhere else needs to change).
// 2. If neither SH1106 variant works, your panel may actually be SSD1306:
//    U8G2_SSD1306_128X64_NONAME_F_HW_I2C u8g2(U8G2_R0, U8X8_PIN_NONE);
// 3. Re-run an I2C scanner sketch to confirm the address is still 0x3C —
//    some SSD1306/SH1106 boards ship at 0x3D instead.
