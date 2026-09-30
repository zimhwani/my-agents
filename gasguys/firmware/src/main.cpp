// Gasguys smart valve firmware (ESP32, Arduino framework).
//
// The rules mirror core/device.ts, which the web sandbox runs:
//   * The valve is fail-closed: it opens only with credit, gas, no leak, no tamper and enough battery.
//   * Credit is grams of LPG. The load cell measures what left the cylinder while the valve was open
//     and that comes off the credit.
//   * Credit arrives two ways that share one counter, so it can never be applied twice:
//       online:  MQTT gg/<id>/cmd  {"type":"credit","grams":540,"counter":7,"sig":"<16 hex>"}
//       offline: a 12-digit GG1 token keyed in on the keypad (or sent over BLE, not built yet)
//   * Telemetry goes to gg/<id>/telemetry every 5 minutes and on any change.
//
// Bench prototype: not yet run on hardware. Build with `pio run -e bench`.

#include <Arduino.h>
#include <ArduinoJson.h>
#include <HX711.h>
#include <Keypad.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <mbedtls/md.h>

#include "config.h"
#include "token.h"

#if defined(GG_TRANSPORT_WIFI)
#include <WiFi.h>
#include <WiFiClientSecure.h>
WiFiClientSecure net;
#elif defined(GG_TRANSPORT_CELLULAR)
// TinyGSM's SIM7080 driver covers the SIM7070G. TODO before field use: TLS through the modem's own
// SSL stack (TinyGsmClientSecure) with the device certificate; this build connects in plain TCP.
#include <TinyGsmClient.h>
HardwareSerial modemSerial(1);
TinyGsm modem(modemSerial);
TinyGsmClient net(modem);
#endif

// ── Platform HMAC for token.cpp ──────────────────────────────────────────────────────────────────
void gg::hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen, uint8_t out[32]) {
  mbedtls_md_hmac(mbedtls_md_info_from_type(MBEDTLS_MD_SHA256), key, keyLen, msg, msgLen, out);
}

// ── State (persisted in NVS so a reboot or brown-out never loses credit) ────────────────────────
struct State {
  float creditGrams = 0;
  float gasGrams = 0;
  bool leak = false;
  bool tamper = false;
  bool valveOpen = false;
  gg::CounterState counters;
  uint8_t badTokens = 0;
  uint32_t lockedUntilMs = 0;
} st;

Preferences nvs;
HX711 scale;
PubSubClient mqtt(net);
uint8_t meterKey[32];
char topicCmd[48], topicTelemetry[48], topicAck[48];

const byte ROWS = 4, COLS = 3;
char keys[ROWS][COLS] = {{'1', '2', '3'}, {'4', '5', '6'}, {'7', '8', '9'}, {'*', '0', '#'}};
byte rowPins[ROWS] = {19, 18, 5, 17};
byte colPins[COLS] = {16, 4, 15};
Keypad keypad = Keypad(makeKeymap(keys), rowPins, colPins, ROWS, COLS);
String entry;

const uint8_t MAX_BAD_TOKENS = 5;
const uint32_t LOCKOUT_MS = 30UL * 60 * 1000;
const uint32_t TELEMETRY_MS = 5UL * 60 * 1000;

void save() {
  nvs.putFloat("credit", st.creditGrams);
  nvs.putBool("leak", st.leak);
  nvs.putUInt("ctrMax", st.counters.max);
  nvs.putUInt("ctrMask", st.counters.usedMask);
}

void load() {
  st.creditGrams = nvs.getFloat("credit", 0);
  st.leak = nvs.getBool("leak", false); // a leak lock survives reboots until a technician clears it
  st.counters.max = nvs.getUInt("ctrMax", 0);
  st.counters.usedMask = nvs.getUInt("ctrMask", 0);
}

float batteryPct() {
  float v = analogReadMilliVolts(PIN_BATTERY_ADC) * 2 / 1000.0; // 1:2 divider on a Li-ion cell
  return constrain((v - 3.3) / (4.2 - 3.3) * 100, 0, 100);
}

// ── Valve ────────────────────────────────────────────────────────────────────────────────────────
bool shouldOpen() { return st.creditGrams > 0 && st.gasGrams > 0 && !st.leak && !st.tamper && batteryPct() > 5; }

void driveValve(bool open) {
  // Motorised ball valve: power only while moving, so a flat battery leaves it where it is. The
  // low-battery rule above closes it while there is still charge for one stroke.
  digitalWrite(open ? PIN_VALVE_OPEN : PIN_VALVE_CLOSE, HIGH);
  delay(400);
  digitalWrite(PIN_VALVE_OPEN, LOW);
  digitalWrite(PIN_VALVE_CLOSE, LOW);
  st.valveOpen = open;
  Serial.printf("[valve] %s\n", open ? "OPEN" : "CLOSED");
}

bool telemetryDue = true;
void settleValve() {
  bool want = shouldOpen();
  if (want != st.valveOpen) {
    driveValve(want);
    telemetryDue = true;
  }
}

// ── Credit ───────────────────────────────────────────────────────────────────────────────────────
void addCredit(uint32_t grams, uint32_t counter, const char* via) {
  st.counters = gg::markUsed(st.counters, counter);
  st.creditGrams += grams;
  save();
  Serial.printf("[%s] +%lu g (ctr %lu)\n", via, (unsigned long)grams, (unsigned long)counter);
  tone(PIN_BUZZER, 2200, 120);
  settleValve();
  telemetryDue = true;
}

void onToken(const String& token) {
  if (millis() < st.lockedUntilMs) {
    Serial.println("[token] keypad locked");
    tone(PIN_BUZZER, 400, 600);
    return;
  }
  uint32_t grams, counter;
  gg::CounterState next;
  if (!gg::verifyToken(meterKey, token.c_str(), st.counters, grams, counter, next)) {
    Serial.printf("[token] %s rejected\n", token.c_str());
    tone(PIN_BUZZER, 400, 600);
    if (++st.badTokens >= MAX_BAD_TOKENS) {
      st.lockedUntilMs = millis() + LOCKOUT_MS; // slows brute-forcing the 5-digit MAC
      st.badTokens = 0;
    }
    return;
  }
  st.badTokens = 0;
  addCredit(grams, counter, "token");
}

void onCommand(char*, byte* payload, unsigned int len) {
  JsonDocument doc;
  if (deserializeJson(doc, payload, len)) return;
  const char* type = doc["type"] | "";
  const char* id = doc["id"] | "";
  bool ok = true;

  if (!strcmp(type, "credit")) {
    uint32_t grams = doc["grams"], counter = doc["counter"];
    char sig[17];
    gg::signCredit(meterKey, counter, grams, sig);
    if (strcmp(sig, doc["sig"] | "") != 0) {
      ok = false; // not signed with this valve's key: ignore, even though it came over our broker
      Serial.println("[mqtt] credit with bad signature ignored");
    } else if (gg::isUsed(st.counters, counter) || counter + 32 <= st.counters.max) {
      Serial.printf("[mqtt] credit ctr %lu already applied\n", (unsigned long)counter); // idempotent
    } else {
      addCredit(grams, counter, "mqtt");
    }
  } else if (!strcmp(type, "clear_leak")) {
    // Only after a technician visit; ops sends it from the console.
    st.leak = false;
    save();
    settleValve();
  } else if (!strcmp(type, "ping")) {
    telemetryDue = true;
  }

  char ack[96];
  snprintf(ack, sizeof ack, "{\"id\":\"%s\",\"ok\":%s}", id, ok ? "true" : "false");
  mqtt.publish(topicAck, ack);
}

// ── Sensors ──────────────────────────────────────────────────────────────────────────────────────
float lastWeighed = -1;
void readScale() {
  if (!scale.is_ready()) return;
  float grams = max(0.0f, scale.get_units(5) - TARE_GRAMS);
  if (lastWeighed >= 0 && st.valveOpen) {
    float used = lastWeighed - grams;
    if (used > 2) { // ignore noise; drift is always in the customer's favour
      st.creditGrams = max(0.0f, st.creditGrams - used);
      save();
    }
  }
  if (lastWeighed >= 0 && grams - lastWeighed > 3000) {
    Serial.println("[scale] new cylinder detected");
    telemetryDue = true;
  }
  lastWeighed = grams;
  st.gasGrams = grams;
}

void readSafety() {
  bool leakNow = analogRead(PIN_GAS_SENSOR) > GAS_ALARM_RAW;
  if (leakNow && !st.leak) {
    st.leak = true; // latches until clear_leak
    save();
    Serial.println("[safety] LPG over threshold, shutting valve");
    telemetryDue = true;
  }
  bool tamperNow = digitalRead(PIN_TAMPER) == LOW;
  if (tamperNow != st.tamper) {
    st.tamper = tamperNow;
    telemetryDue = true;
  }
  if (st.leak) tone(PIN_BUZZER, 3000, 200);
}

// ── Network ──────────────────────────────────────────────────────────────────────────────────────
void connectNetwork() {
#if defined(GG_TRANSPORT_WIFI)
  if (WiFi.status() == WL_CONNECTED) return;
  WiFi.begin(GG_WIFI_SSID, GG_WIFI_PASS);
  for (int i = 0; i < 40 && WiFi.status() != WL_CONNECTED; i++) delay(250);
  net.setCACert(GG_CA_PEM);
  net.setCertificate(GG_CLIENT_CERT);
  net.setPrivateKey(GG_CLIENT_KEY);
#elif defined(GG_TRANSPORT_CELLULAR)
  if (modem.isGprsConnected()) return;
  modem.gprsConnect(GG_APN);
#endif
}

void connectMqtt() {
  if (mqtt.connected()) return;
  connectNetwork();
  // A retained last-will tells the backend the valve dropped off; it's still safe offline.
  char will[48];
  snprintf(will, sizeof will, "gg/%s/status", GG_METER_ID);
  if (mqtt.connect(GG_METER_ID, nullptr, nullptr, will, 1, true, "offline")) {
    mqtt.publish(will, "online", true);
    mqtt.subscribe(topicCmd, 1);
    telemetryDue = true;
  }
}

void publishTelemetry() {
  JsonDocument doc;
  doc["meterId"] = GG_METER_ID;
  doc["gasGrams"] = (int)st.gasGrams;
  doc["creditGrams"] = (int)st.creditGrams;
  doc["valve"] = st.valveOpen ? "open" : "closed";
  doc["batteryPct"] = (int)batteryPct();
  doc["leak"] = st.leak;
  doc["tamper"] = st.tamper;
  doc["tokenCounter"] = st.counters.max;
  doc["rssi"] =
#if defined(GG_TRANSPORT_WIFI)
      WiFi.RSSI();
#else
      modem.getSignalQuality();
#endif
  char buf[256];
  size_t n = serializeJson(doc, buf);
  if (mqtt.publish(topicTelemetry, (const uint8_t*)buf, n, false)) telemetryDue = false;
}

// ── Main loop ────────────────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  pinMode(PIN_VALVE_OPEN, OUTPUT);
  pinMode(PIN_VALVE_CLOSE, OUTPUT);
  pinMode(PIN_TAMPER, INPUT_PULLUP);
  pinMode(PIN_BUZZER, OUTPUT);
  driveValve(false); // known state at boot: closed

  nvs.begin("gasguys", false);
  load();
  gg::hexToKey(GG_METER_KEY_HEX, meterKey);
  snprintf(topicCmd, sizeof topicCmd, "gg/%s/cmd", GG_METER_ID);
  snprintf(topicTelemetry, sizeof topicTelemetry, "gg/%s/telemetry", GG_METER_ID);
  snprintf(topicAck, sizeof topicAck, "gg/%s/ack", GG_METER_ID);

  scale.begin(PIN_HX711_DT, PIN_HX711_SCK);
  scale.set_scale(LOADCELL_SCALE);

#if defined(GG_TRANSPORT_CELLULAR)
  modemSerial.begin(115200, SERIAL_8N1, 22, 21);
  modem.restart();
#endif
  mqtt.setServer(GG_MQTT_HOST, GG_MQTT_PORT);
  mqtt.setCallback(onCommand);
  Serial.printf("Gasguys valve %s, credit %.0f g\n", GG_METER_ID, st.creditGrams);
}

uint32_t lastSense = 0, lastTelemetry = 0, lastConnectTry = 0;

void loop() {
  // Keypad works with or without network: that's the whole point of the offline token.
  char k = keypad.getKey();
  if (k >= '0' && k <= '9' && entry.length() < 12) entry += k;
  if (k == '*') entry = "";
  if (k == '#') {
    onToken(entry);
    entry = "";
  }

  if (millis() - lastSense > 1000) {
    lastSense = millis();
    readScale();
    readSafety();
    settleValve();
  }

  if (!mqtt.connected() && millis() - lastConnectTry > 30000) {
    lastConnectTry = millis();
    connectMqtt();
  }
  mqtt.loop();
  if (mqtt.connected() && (telemetryDue || millis() - lastTelemetry > TELEMETRY_MS)) {
    lastTelemetry = millis();
    publishTelemetry();
  }
}
