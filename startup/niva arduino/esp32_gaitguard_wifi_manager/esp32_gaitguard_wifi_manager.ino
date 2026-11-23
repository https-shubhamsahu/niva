#include <WiFi.h>
#include <WebSocketsServer.h>

// ------------------------------
// Hardware pin map
// ------------------------------
static const int PIN_HEEL = 32;
static const int PIN_INNER = 33;
static const int PIN_OUTER = 34;
static const int PIN_TOE = 35;
static const int PIN_PIEZO = 36;

// ------------------------------
// Stream and filter settings
// ------------------------------
static const unsigned long STREAM_INTERVAL_MS = 100;

// ------------------------------
// Zero-load calibration settings
// ------------------------------
static const uint16_t CALIBRATION_SAMPLES = 40;

// ------------------------------
// WiFi reconnect settings
// ------------------------------
static const unsigned long WIFI_CHECK_INTERVAL_MS = 3000;

// Hardcode your hotspot credentials here.
static const char* WIFI_SSID = "YOUR_HOTSPOT_NAME";
static const char* WIFI_PASS = "YOUR_HOTSPOT_PASSWORD";

WebSocketsServer wsServer(81);

struct ChannelState {
  float baseline = 0.0f;
};

ChannelState heelState;
ChannelState innerState;
ChannelState outerState;
ChannelState toeState;
ChannelState piezoState;

bool isCalibrated = false;
uint16_t calibrationCount = 0;
float calibrationHeel = 0.0f;
float calibrationInner = 0.0f;
float calibrationOuter = 0.0f;
float calibrationToe = 0.0f;
float calibrationPiezo = 0.0f;

unsigned long lastStreamAt = 0;
unsigned long lastWiFiCheckAt = 0;
 
float applyBaseline(float raw, const ChannelState& state) {
  float adjusted = raw - state.baseline;
  if (adjusted < 0.0f) adjusted = 0.0f;
  return adjusted;
}

void printWiFiStatus() {
  Serial.println("WiFi Connected");
  Serial.print("ESP32 IP: ");
  Serial.println(WiFi.localIP());
}

void connectHardcodedWiFi() {
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASS);

  Serial.print("Connecting to WiFi");
  unsigned long startAt = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startAt < 20000) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    printWiFiStatus();
  } else {
    Serial.println("WiFi connect failed. Check WIFI_SSID/WIFI_PASS.");
  }
}

void maintainWiFi() {
  unsigned long now = millis();
  if (now - lastWiFiCheckAt < WIFI_CHECK_INTERVAL_MS) return;
  lastWiFiCheckAt = now;

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost. Attempting reconnect...");
    WiFi.disconnect(true);
    WiFi.begin(WIFI_SSID, WIFI_PASS);
  }
}

void setup() {
  Serial.begin(115200);
  delay(300);

  analogReadResolution(12);

  pinMode(PIN_HEEL, INPUT);
  pinMode(PIN_INNER, INPUT);
  pinMode(PIN_OUTER, INPUT);
  pinMode(PIN_TOE, INPUT);
  pinMode(PIN_PIEZO, INPUT);

  connectHardcodedWiFi();

  wsServer.begin();

  Serial.println("Calibrating FSR");
}

void loop() {
  maintainWiFi();
  wsServer.loop();

  unsigned long now = millis();
  if (now - lastStreamAt < STREAM_INTERVAL_MS) return;
  lastStreamAt = now;

  float rawHeel = static_cast<float>(analogRead(PIN_HEEL));
  float rawInner = static_cast<float>(analogRead(PIN_INNER));
  float rawOuter = static_cast<float>(analogRead(PIN_OUTER));
  float rawToe = static_cast<float>(analogRead(PIN_TOE));
  float rawPiezo = static_cast<float>(analogRead(PIN_PIEZO));

  if (!isCalibrated) {
    calibrationCount += 1;
    calibrationHeel += rawHeel;
    calibrationInner += rawInner;
    calibrationOuter += rawOuter;
    calibrationToe += rawToe;
    calibrationPiezo += rawPiezo;

    if (calibrationCount >= CALIBRATION_SAMPLES) {
      heelState.baseline = calibrationHeel / calibrationCount;
      innerState.baseline = calibrationInner / calibrationCount;
      outerState.baseline = calibrationOuter / calibrationCount;
      toeState.baseline = calibrationToe / calibrationCount;
      piezoState.baseline = calibrationPiezo / calibrationCount;

      isCalibrated = true;
      Serial.println("Calibration Done");
      Serial.println("SYSTEM READY");
    }

    // Keep stream alive during calibration with zeros.
    const char* calibratingPacket = "{\"heel\":0,\"inner\":0,\"outer\":0,\"toe\":0,\"piezo\":0,\"pitch\":0,\"roll\":0,\"accZ\":0}";
    wsServer.broadcastTXT(calibratingPacket);
    Serial.println("0,0,0,0,0,0,0,0");
    return;
  }

  float heel = applyBaseline(rawHeel, heelState);
  float inner = applyBaseline(rawInner, innerState);
  float outer = applyBaseline(rawOuter, outerState);
  float toe = applyBaseline(rawToe, toeState);
  float piezo = applyBaseline(rawPiezo, piezoState);

  const float pitchDeg = 0.0f;
  const float rollDeg = 0.0f;
  const float accZ = 0.0f;

  char jsonPayload[220];
  snprintf(
    jsonPayload,
    sizeof(jsonPayload),
    "{\"heel\":%.2f,\"inner\":%.2f,\"outer\":%.2f,\"toe\":%.2f,\"piezo\":%.2f,\"pitch\":%.2f,\"roll\":%.2f,\"accZ\":%.2f}",
    heel,
    inner,
    outer,
    toe,
    piezo,
    pitchDeg,
    rollDeg,
    accZ
  );

  wsServer.broadcastTXT(jsonPayload);

  // USB serial CSV output compatible with dashboard serial parser.
  Serial.printf(
    "%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f\n",
    heel,
    inner,
    outer,
    toe,
    piezo,
    pitchDeg,
    rollDeg,
    accZ
  );
}
