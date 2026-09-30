// Host-side check that the firmware token maths matches core/token.ts.
//   g++ -std=c++17 -Iinclude test/token_host_test.cpp src/token.cpp -lcrypto -o /tmp/tok && /tmp/tok
#include <openssl/hmac.h>
#include <stdio.h>
#include <string.h>

#include "token.h"

void gg::hmacSha256(const uint8_t* key, size_t keyLen, const uint8_t* msg, size_t msgLen, uint8_t out[32]) {
  unsigned len = 32;
  HMAC(EVP_sha256(), key, (int)keyLen, msg, msgLen, out, &len);
}

static int fails = 0;
static void expect(bool ok, const char* what) {
  printf("%s %s\n", ok ? "ok  " : "FAIL", what);
  if (!ok) fails++;
}

int main() {
  uint8_t key[32];
  gg::hexToKey("000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f", key);
  char t[13];
  gg::generateToken(key, 1, 1000, t);   expect(!strcmp(t, "310774333884"), "vector 1");
  gg::generateToken(key, 2, 2500, t);   expect(!strcmp(t, "660454528386"), "vector 2");
  gg::generateToken(key, 42, 999990, t); expect(!strcmp(t, "085640737893"), "vector 3");
  char sig[17];
  gg::signCredit(key, 1, 1000, sig);     expect(!strcmp(sig, "8a353b972e254ea0"), "credit signature");

  gg::CounterState s, next;
  uint32_t grams, counter;
  expect(gg::verifyToken(key, "3107 7433 3884", s, grams, counter, next) && grams == 1000 && counter == 1, "verify token 1");
  expect(!gg::verifyToken(key, "310774333884", next, grams, counter, next), "reject replay");
  s = gg::markUsed(gg::CounterState{}, 3);
  expect(gg::verifyToken(key, "660454528386", s, grams, counter, next) && grams == 2500, "accept older unused counter");
  expect(!gg::verifyToken(key, "660454528387", s, grams, counter, next), "reject typo");
  return fails ? 1 : 0;
}
