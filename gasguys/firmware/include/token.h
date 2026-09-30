// GG1 offline token and signed credit commands. Must match core/token.ts exactly; the test vectors
// in test/token_host_test.cpp come from core/__snapshots__/token.test.ts.snap.
#pragma once
#include <stddef.h>
#include <stdint.h>

namespace gg {

struct CounterState {
  uint32_t max = 0;
  uint32_t usedMask = 0; // bit i set: counter (max - i) was used
};

// Platform HMAC-SHA256 (mbedtls on the ESP32, OpenSSL in the host test).
void hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen, uint8_t out[32]);

bool isUsed(const CounterState& s, uint32_t c);
CounterState markUsed(CounterState s, uint32_t c);

// Writes 12 digits and a NUL into out.
void generateToken(const uint8_t key[32], uint32_t counter, uint32_t grams, char out[13]);

// Returns true and fills grams/counter/next when the token is valid and unused.
bool verifyToken(const uint8_t key[32], const char* token, const CounterState& s, uint32_t& grams, uint32_t& counter, CounterState& next);

// 16 hex chars + NUL: first 8 bytes of HMAC(key, "cmd:credit:<counter>:<grams>").
void signCredit(const uint8_t key[32], uint32_t counter, uint32_t grams, char out[17]);

bool hexToKey(const char* hex, uint8_t key[32]);

} // namespace gg
