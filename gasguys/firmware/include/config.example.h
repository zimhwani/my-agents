// Copy to include/config.h (git-ignored) and fill in. Never commit real keys.
#pragma once

#define GG_METER_ID       "37012345678"
// 32-byte per-valve secret, hex. Generated at provisioning and stored in private.meter_keys.
#define GG_METER_KEY_HEX  "000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f"

#define GG_WIFI_SSID      "bench-wifi"
#define GG_WIFI_PASS      "change-me"
#define GG_APN            "internet.econet.co.zw"   // check with the SIM provider

#define GG_MQTT_HOST      "broker.example.com"
#define GG_MQTT_PORT      8883
// Per-device TLS client certificate and key (PEM), issued at provisioning.
#define GG_CA_PEM         "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
#define GG_CLIENT_CERT    "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----\n"
#define GG_CLIENT_KEY     "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"

// Pins (ESP32 DevKit). Motorised ball valve via an H-bridge; HX711 load cell under the cylinder.
#define PIN_VALVE_OPEN    25
#define PIN_VALVE_CLOSE   26
#define PIN_HX711_DT      32
#define PIN_HX711_SCK     33
#define PIN_GAS_SENSOR    34   // MQ-6 analog out (prototype only: its heater draws ~150 mA)
#define PIN_TAMPER        27   // enclosure switch, LOW when the lid is open
#define PIN_BUZZER        13
#define PIN_BATTERY_ADC   35

#define GAS_ALARM_RAW     2200 // ADC reading that counts as a leak; calibrate per sensor
#define LOADCELL_SCALE    21.4f
#define TARE_GRAMS        10500 // empty 9 kg cylinder + valve body; set at install
