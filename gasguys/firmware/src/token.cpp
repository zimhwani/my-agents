#include "token.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

namespace gg {

static const uint32_t TEN7 = 10000000UL;
static const uint32_t TEN5 = 100000UL;
static const uint32_t LOOKAHEAD = 30;
static const uint32_t UNIT_GRAMS = 10;

static uint32_t hmacU32(const uint8_t key[32], const char* msg) {
  uint8_t out[32];
  hmacSha256(key, 32, (const uint8_t*)msg, strlen(msg), out);
  return ((uint32_t)out[0] << 24) | ((uint32_t)out[1] << 16) | ((uint32_t)out[2] << 8) | out[3];
}

static uint32_t pad(const uint8_t key[32], uint32_t c) {
  char m[24];
  snprintf(m, sizeof m, "pad:%lu", (unsigned long)c);
  return hmacU32(key, m) % TEN7;
}

static uint32_t mac(const uint8_t key[32], uint32_t c, uint32_t value) {
  char m[40];
  snprintf(m, sizeof m, "mac:%lu:%lu", (unsigned long)c, (unsigned long)value);
  return hmacU32(key, m) % TEN5;
}

bool isUsed(const CounterState& s, uint32_t c) {
  if (c == s.max) return s.max > 0;
  if (c < s.max && s.max - c < 32) return (s.usedMask >> (s.max - c)) & 1;
  return false;
}

CounterState markUsed(CounterState s, uint32_t c) {
  if (c > s.max) {
    uint32_t shift = c - s.max;
    s.usedMask = shift >= 32 ? 0 : ((s.usedMask << shift) | (s.max > 0 ? (1UL << shift) : 0));
    s.max = c;
  } else if (s.max - c < 32) {
    s.usedMask |= (1UL << (s.max - c));
  }
  return s;
}

void generateToken(const uint8_t key[32], uint32_t counter, uint32_t grams, char out[13]) {
  uint32_t value = grams / UNIT_GRAMS;
  uint32_t high = (uint32_t)(((uint64_t)value * 100 + counter % 100 + pad(key, counter)) % TEN7);
  snprintf(out, 13, "%07lu%05lu", (unsigned long)high, (unsigned long)mac(key, counter, value));
}

bool verifyToken(const uint8_t key[32], const char* token, const CounterState& s, uint32_t& grams, uint32_t& counter, CounterState& next) {
  char digits[13];
  size_t n = 0;
  for (const char* p = token; *p && n < 12; p++)
    if (*p >= '0' && *p <= '9') digits[n++] = *p;
  if (n != 12) return false;
  digits[12] = 0;
  uint32_t mac5 = strtoul(digits + 7, nullptr, 10);
  digits[7] = 0;
  uint32_t high = strtoul(digits, nullptr, 10);

  uint32_t from = s.max > 31 ? s.max - 31 : 1;
  for (uint32_t c = from; c <= s.max + LOOKAHEAD; c++) {
    if (isUsed(s, c)) continue;
    uint32_t plain = (high + TEN7 - pad(key, c)) % TEN7;
    if (plain % 100 != c % 100) continue;
    uint32_t value = plain / 100;
    if (mac(key, c, value) != mac5) continue;
    grams = value * UNIT_GRAMS;
    counter = c;
    next = markUsed(s, c);
    return true;
  }
  return false;
}

void signCredit(const uint8_t key[32], uint32_t counter, uint32_t grams, char out[17]) {
  char m[48];
  snprintf(m, sizeof m, "cmd:credit:%lu:%lu", (unsigned long)counter, (unsigned long)grams);
  uint8_t h[32];
  hmacSha256(key, 32, (const uint8_t*)m, strlen(m), h);
  for (int i = 0; i < 8; i++) snprintf(out + i * 2, 3, "%02x", h[i]);
}

bool hexToKey(const char* hex, uint8_t key[32]) {
  if (strlen(hex) != 64) return false;
  for (int i = 0; i < 32; i++) {
    unsigned v;
    if (sscanf(hex + i * 2, "%2x", &v) != 1) return false;
    key[i] = (uint8_t)v;
  }
  return true;
}

} // namespace gg
