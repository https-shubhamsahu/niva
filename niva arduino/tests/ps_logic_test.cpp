// Off-target tests for the pure logic of niva_protected_steps/: JSON and
// command parsing, stride detector, clock offset, matcher (P/U/X), records,
// ring log, ESP-NOW packets, outbox, home flag, IMU validity.
//
// Every signal here is synthetic, shaped to exercise the logic. Passing
// these tests is a software result; it says nothing about how well the
// firmware detects real strides or contacts (that is RQ1).

#include <stdio.h>
#include <stdlib.h>

#include <math.h>

#include <map>
#include <string>
#include <vector>

#include "ps_cmd.h"
#include "ps_json.h"
#include "ps_logic.h"
#include "ps_match.h"
#include "ps_offset.h"
#include "ps_packet.h"
#include "ps_record.h"
#include "ps_ringlog.h"
#include "ps_stride.h"

static int failures = 0;
static int checks = 0;
#define CHECK(cond)                                                    \
  do {                                                                 \
    checks++;                                                          \
    if (!(cond)) {                                                     \
      printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);           \
      failures++;                                                      \
    }                                                                  \
  } while (0)

static bool parseJson(const char* s, PsCommand& c) { return psParseJsonCommand(s, strlen(s), c); }

// ------------------------------------------------------------------ JSON ---

static void testJson() {
  PsJsonObject o;
  CHECK(psJsonParse("{}", 2, o) && o.n == 0);
  const char* s = " { \"a\" : \"x\\\"y\" , \"b\":-12, \"c\":true, \"d\":null } ";
  CHECK(psJsonParse(s, strlen(s), o) && o.n == 4);
  char buf[16];
  CHECK(o.getString("a", buf, sizeof(buf)) && strcmp(buf, "x\"y") == 0);
  int64_t v = 0;
  CHECK(o.getInt("b", v) && v == -12);
  CHECK(o.isNull("d"));
  CHECK(!o.getInt("a", v));
  const char* bad[] = {"", "{", "{\"a\":}", "{\"a\":1,}", "{\"a\":{}}", "{\"a\":[1]}", "{\"a\":1.5}",
                       "{\"a\":01}", "{\"a\":1}x", "{\"a\":\"\\u0041\"}", "{\"a\":1,\"a\":2}", "{a:1}",
                       "{\"a\":1234567890123456789}"};
  for (const char* b : bad) CHECK(!psJsonParse(b, strlen(b), o));
  CHECK(psJsonParse("{\"e\":1793650000000}", 19, o) && o.getInt("e", v) && v == 1793650000000LL);

  char out[32];
  CHECK(psJsonQuote(out, sizeof(out), "a\"b\\c\n") > 0 && strcmp(out, "\"a\\\"b\\\\c\\u000a\"") == 0);
  CHECK(psJsonQuote(out, 4, "abcdef") == 0);  // does not fit
}

// -------------------------------------------------------------- commands ---

static void testCommands() {
  PsCommand c;
  // PROTOCOL.md examples, verbatim.
  CHECK(parseJson("{\"cmd\":\"backlog\",\"from_seq\":1000}", c) && c.type == PsCmdType::BACKLOG && c.fromSeq == 1000);
  CHECK(parseJson("{\"cmd\":\"config\",\"home_ssid\":\"MyHome\",\"match_ms\":300,\"settle_ms\":2000,\"home_scan_s\":300}", c));
  CHECK(c.type == PsCmdType::CONFIG && c.hasHomeSsid && strcmp(c.homeSsid, "MyHome") == 0);
  CHECK(c.hasMatchMs && c.matchMs == 300 && c.hasSettleMs && c.settleMs == 2000 && c.hasHomeScanS && c.homeScanS == 300);
  CHECK(parseJson("{\"cmd\":\"pair\",\"insole\":\"0A1B2C3D4E5F\"}", c) && c.type == PsCmdType::PAIR && c.macSet);
  CHECK(c.mac[0] == 0x0A && c.mac[5] == 0x5F);
  CHECK(parseJson("{\"cmd\":\"unpair\"}", c) && c.type == PsCmdType::UNPAIR);
  CHECK(parseJson("{\"cmd\":\"ack\",\"upto_seq\":1203}", c) && c.type == PsCmdType::ACK && c.uptoSeq == 1203);
  uint64_t epoch = 0;
  CHECK(psParseTimeWrite("{\"epoch_ms\":1793650000000}", 26, epoch) && epoch == 1793650000000ULL);
  CHECK(!psParseTimeWrite("{\"epoch_ms\":\"x\"}", 16, epoch));

  // Errors carry a reason and the command name.
  CHECK(!parseJson("{\"cmd\":\"bogus\"}", c) && c.type == PsCmdType::ERROR && strcmp(c.reason, "unknown_cmd") == 0 && strcmp(c.name, "bogus") == 0);
  CHECK(!parseJson("not json", c) && strcmp(c.reason, "malformed") == 0);
  CHECK(!parseJson("{\"cmd\":\"pair\",\"insole\":\"zz\"}", c) && strcmp(c.reason, "bad_insole_id") == 0);
  CHECK(!parseJson("{\"cmd\":\"pair\",\"insole\":\"FFFFFFFFFFFF\"}", c));
  CHECK(!parseJson("{\"cmd\":\"config\",\"match_ms\":0}", c) && strcmp(c.reason, "out_of_range") == 0);
  CHECK(!parseJson("{\"cmd\":\"config\",\"match_ms\":\"300\"}", c) && strcmp(c.reason, "bad_type") == 0);
  CHECK(!parseJson("{\"cmd\":\"config\"}", c) && strcmp(c.reason, "empty_config") == 0);
  CHECK(!parseJson("{\"cmd\":\"config\",\"home_ssid\":\"123456789012345678901234567890123\"}", c));  // 33 bytes
  CHECK(parseJson("{\"cmd\":\"config\",\"home_ssid\":null}", c) && c.hasHomeSsid && c.homeSsid[0] == '\0');
  CHECK(!parseJson("{\"cmd\":\"ack\"}", c) && strcmp(c.reason, "bad_upto_seq") == 0);
  CHECK(!parseJson("{\"cmd\":\"backlog\",\"from_seq\":-1}", c));
  CHECK(parseJson("{\"cmd\":\"backlog\"}", c) && c.fromSeq == 0);
  CHECK(!parseJson("{\"x\":1}", c) && strcmp(c.reason, "missing_cmd") == 0);
  CHECK(parseJson("{\"cmd\":\"role\",\"role\":\"insole\"}", c) && c.type == PsCmdType::ROLE && c.role == PsRole::INSOLE);
  CHECK(!parseJson("{\"cmd\":\"role\",\"role\":\"hand\"}", c) && strcmp(c.reason, "bad_role") == 0);

  // Serial text commands.
  CHECK(psParseSerialLine("role ankle\r", c) && c.type == PsCmdType::ROLE && c.role == PsRole::ANKLE);
  CHECK(psParseSerialLine("  ROLE insole ", c) && c.role == PsRole::INSOLE);
  CHECK(!psParseSerialLine("role foot", c) && strcmp(c.reason, "bad_role") == 0);
  CHECK(!psParseSerialLine("role", c) && strcmp(c.reason, "missing_arg") == 0);
  CHECK(psParseSerialLine("pair 0a:1b:2c:3d:4e:5f", c) && c.macSet && c.mac[1] == 0x1B);
  CHECK(psParseSerialLine("pair", c) && c.type == PsCmdType::PAIR && !c.macSet);
  CHECK(!psParseSerialLine("pair 0a:1b:2c", c));
  CHECK(psParseSerialLine("axis -y", c) && c.type == PsCmdType::AXIS && c.axis == -2);
  CHECK(psParseSerialLine("axis +z", c) && c.axis == 3);
  CHECK(!psParseSerialLine("axis z", c));
  CHECK(psParseSerialLine("channel 6", c) && c.channel == 6);
  CHECK(!psParseSerialLine("channel 14", c) && !psParseSerialLine("channel 6x", c));
  CHECK(psParseSerialLine("home My Home WiFi", c) && c.type == PsCmdType::HOME && strcmp(c.homeSsid, "My Home WiFi") == 0);
  CHECK(psParseSerialLine("home none", c) && c.hasHomeSsid && c.homeSsid[0] == '\0');
  // wifi: first word is the SSID, the rest of the line (case kept) the password.
  CHECK(psParseSerialLine("wifi TestNet Pass word9", c) && c.type == PsCmdType::WIFI &&
        strcmp(c.wifiSsid, "TestNet") == 0 && strcmp(c.wifiPass, "Pass word9") == 0);
  CHECK(psParseSerialLine("WIFI none", c) && c.type == PsCmdType::WIFI && c.wifiSsid[0] == '\0' && c.wifiPass[0] == '\0');
  CHECK(psParseSerialLine("wifi OpenCafe", c) && c.type == PsCmdType::WIFI &&
        strcmp(c.wifiSsid, "OpenCafe") == 0 && c.wifiPass[0] == '\0');  // open network
  CHECK(psParseSerialLine("wifi 12345678901234567890123456789012 abcdefgh", c) && strlen(c.wifiSsid) == 32);
  CHECK(!psParseSerialLine("wifi 123456789012345678901234567890123 abcdefgh", c) && strcmp(c.reason, "ssid_too_long") == 0);
  CHECK(!psParseSerialLine("wifi TestNet abcdefg", c) && strcmp(c.reason, "bad_password") == 0);  // 7 bytes
  CHECK(psParseSerialLine("wifi TestNet abcdefgh", c) && strcmp(c.wifiPass, "abcdefgh") == 0);     // 8 bytes
  CHECK(psParseSerialLine("wifi TestNet 123456789012345678901234567890123456789012345678901234567890123", c) &&
        strlen(c.wifiPass) == 63);
  CHECK(!psParseSerialLine("wifi TestNet 1234567890123456789012345678901234567890123456789012345678901234", c) &&
        strcmp(c.reason, "bad_password") == 0);  // 64 bytes
  CHECK(!psParseSerialLine("wifi", c) && strcmp(c.reason, "missing_arg") == 0 && strcmp(c.name, "wifi") == 0);
  CHECK(psParseSerialLine("time 1793650000000", c) && c.type == PsCmdType::TIME && c.epochMs == 1793650000000ULL);
  CHECK(psParseSerialLine("backlog", c) && c.type == PsCmdType::BACKLOG && c.fromSeq == 0);
  CHECK(psParseSerialLine("backlog 17", c) && c.fromSeq == 17);
  CHECK(psParseSerialLine("ack 5", c) && c.uptoSeq == 5);
  CHECK(psParseSerialLine("lab on", c) && c.type == PsCmdType::LAB && c.on);
  CHECK(psParseSerialLine("tare", c) && c.type == PsCmdType::TARE);
  CHECK(!psParseSerialLine("tare now", c) && strcmp(c.reason, "unexpected_arg") == 0);
  CHECK(psParseSerialLine("{\"cmd\":\"unpair\"}", c) && c.type == PsCmdType::UNPAIR);
  CHECK(!psParseSerialLine("", c) && c.type == PsCmdType::NONE);
  CHECK(!psParseSerialLine("frobnicate", c) && strcmp(c.reason, "unknown_cmd") == 0);
}

// ---------------------------------------------------------------- stride ---

// Synthetic shank angular velocity, deg/s, at time t within a stride of
// period T (ms). Shape: loading dip just after initial contact, small
// stance values, then one swing hump. Values are invented to exercise the
// detector; they are not a model of anyone's gait.
static float gaitOmega(uint32_t tInStride, uint32_t T, float swingPeak) {
  const float ph = (float)tInStride / (float)T;
  if (ph < 0.10f) return -120.0f * sinf((float)M_PI * ph / 0.10f);  // dip, min at 0.05 T
  if (ph < 0.60f) return -30.0f;
  return swingPeak * sinf((float)M_PI * (ph - 0.60f) / 0.40f);      // peak at 0.8 T
}

static float noise(int k) {  // deterministic, +-10
  return (float)(((k * 7919) % 21) - 10);
}

static void testStride() {
  // Steady walking: 20 strides of 1100 ms.
  PsStrideDetector d;
  d.begin();
  std::vector<PsStride> got;
  const uint32_t T = 1100;
  for (uint32_t t = 0; t < 20 * T + 500; t += 10) {
    PsStride s;
    if (d.update(gaitOmega(t % T, T, 300.0f) + noise((int)(t / 10)), 1000 + t, s)) got.push_back(s);
  }
  // Mid-swing peaks at 0.8 T of strides 0..19; each stride's contact dip is
  // at 0.05 T of the next stride, i.e. 1.05 T + k T.
  CHECK(got.size() == 20);
  bool timesOk = true;
  for (size_t k = 0; k < got.size(); ++k) {
    const int32_t expectIc = (int32_t)(1000 + T * (k + 1) + T / 20);
    const int32_t expectPk = (int32_t)(1000 + T * k + T * 8 / 10);
    if (abs((int32_t)got[k].tMs - expectIc) > 20 || abs((int32_t)got[k].peakMs - expectPk) > 30) timesOk = false;
  }
  CHECK(timesOk);
  CHECK(d.threshold() > 100.0f && d.threshold() < 130.0f);  // 0.4 x ~300

  // Standing: noise only, no strides.
  PsStrideDetector q;
  q.begin();
  int n = 0;
  for (int k = 0; k < 3000; ++k) {
    PsStride s;
    if (q.update(noise(k) * 2.0f, (uint32_t)(k * 10), s)) n++;
  }
  CHECK(n == 0);

  // A one-sample spike is not a swing (minAboveSamples = 2).
  PsStrideDetector sp;
  sp.begin();
  n = 0;
  for (int k = 0; k < 200; ++k) {
    PsStride s;
    const float w = (k == 50) ? 400.0f : (k > 50 && k < 60 ? -60.0f : 0.0f);
    if (sp.update(w, (uint32_t)(k * 10), s)) n++;
  }
  CHECK(n == 0);

  // Refractory: a second hump 200 ms after the first is ignored.
  PsStrideDetector r;
  r.begin();
  n = 0;
  for (int k = 0; k < 300; ++k) {
    PsStride s;
    float w = 0.0f;
    if (k >= 10 && k < 20) w = 250.0f * sinf((float)M_PI * (k - 10) / 10.0f);
    if (k >= 20 && k < 25) w = -80.0f;
    if (k >= 30 && k < 40) w = 250.0f * sinf((float)M_PI * (k - 30) / 10.0f);  // 200 ms later
    if (k >= 40 && k < 45) w = -80.0f;
    if (r.update(w, (uint32_t)(k * 10), s)) n++;
  }
  CHECK(n == 1);

  // Adaptive threshold: after 300 dps strides, a 100 dps hump is not a
  // stride; after a 3 s pause the threshold is back at the floor and an
  // 80 dps hump is.
  PsStrideDetector a;
  a.begin();
  uint32_t t = 0;
  int walked = 0;
  // Five strides, then the last contact dip, then stillness.
  for (; t < 5 * T + 200; t += 10) { PsStride s; walked += a.update(gaitOmega(t % T, T, 300.0f), t, s); }
  for (uint32_t k = 0; k < 50; ++k, t += 10) { PsStride s; walked += a.update(0.0f, t, s); }
  CHECK(walked == 5);
  n = 0;
  for (uint32_t k = 0; k < 40; ++k, t += 10) {
    PsStride s;
    const float w = (k < 20) ? 100.0f * sinf((float)M_PI * k / 20.0f) : (k < 26 ? -60.0f : 0.0f);
    if (a.update(w, t, s)) n++;
  }
  CHECK(n == 0);
  for (uint32_t k = 0; k < 350; ++k, t += 10) { PsStride s; a.update(0.0f, t, s); }  // 3.5 s pause
  CHECK(a.threshold() == 50.0f);
  n = 0;
  for (uint32_t k = 0; k < 40; ++k, t += 10) {
    PsStride s;
    const float w = (k < 20) ? 80.0f * sinf((float)M_PI * k / 20.0f) : (k < 26 ? -60.0f : 0.0f);
    if (a.update(w, t, s)) n++;
  }
  CHECK(n == 1);
}

static void testGyroBias() {
  // Still, with an offset of -13.5 deg/s plus noise: learned within 1 s.
  PsGyroBias b;
  b.reset();
  float last = 0;
  for (int k = 0; k < 100; ++k) last = b.update(-13.5f + noise(k) * 0.2f);
  CHECK(b.known() && fabsf(b.bias() + 13.5f) < 0.5f);
  CHECK(fabsf(b.update(-13.5f)) < 0.5f);
  (void)last;
  // Walking (large variance) does not move the estimate.
  const float before = b.bias();
  for (int k = 0; k < 500; ++k) b.update(gaitOmega((uint32_t)(k * 10) % 1100, 1100, 300.0f) - 13.5f);
  CHECK(b.bias() == before);
  // Strides are still found when the raw signal carries the offset.
  PsGyroBias b2;
  b2.reset();
  PsStrideDetector d;
  d.begin();
  int n = 0;
  uint32_t t = 0;
  for (; t < 2000; t += 10) { PsStride s; n += d.update(b2.update(-13.5f + noise((int)t) * 0.2f), t, s); }
  for (uint32_t k = 0; k < 10 * 1100; k += 10, t += 10) {
    PsStride s;
    n += d.update(b2.update(gaitOmega(k % 1100, 1100, 300.0f) - 13.5f), t, s);
  }
  CHECK(n == 9);  // the tenth swing's contact dip is past the end of the input
}

// ---------------------------------------------------------------- offset ---

static void testOffset() {
  PsClockOffset c;
  c.begin(600000);
  uint32_t h = 0;
  CHECK(!c.valid() && !c.toHub(100, h));
  // Insole clock = hub clock - 5000 ms. Delays 3..40 ms.
  const int delays[] = {12, 40, 7, 3, 25, 9};
  for (int i = 0; i < 6; ++i) {
    const uint32_t tx = 10000 + 1000 * i;
    c.addSample(tx + 5000 + delays[i], tx);
  }
  CHECK(c.offset() == 5003);
  CHECK(c.toHub(20000, h) && h == 25003);
  // Old samples leave the window: after 11 minutes only new ones count.
  c.addSample(10000 + 660000 + 5000 + 30, 10000 + 660000);
  CHECK(c.samples() == 1 && c.offset() == 5030);
  // Hub booted after the insole: negative offsets work, times before the
  // hub's boot do not map.
  PsClockOffset n;
  n.begin();
  n.addSample(100 + 4, 60100);  // offset -59996
  CHECK(n.offset() == -59996);
  CHECK(n.toHub(60200, h) && h == 204);
  CHECK(!n.toHub(1000, h));
  // Capacity: more than 32 samples keeps the newest 32.
  PsClockOffset cap;
  cap.begin();
  for (int i = 0; i < 40; ++i) cap.addSample((uint32_t)(1000 + i * 10 + (i == 0 ? 0 : 5)), (uint32_t)(i * 10));
  CHECK(cap.samples() == 32 && cap.offset() == 1005);  // the 0-delay first sample is gone
}

// --------------------------------------------------------------- matcher ---

static PsInsoleView validInsole(int8_t batt = 80) {
  PsInsoleView v;
  v.paired = true;
  v.heard = true;
  v.batt = batt;
  v.val = PsVal::VALID;
  return v;
}

struct MatchHarness {
  PsMatcher m;
  PsMatchOut out;
  std::vector<PsStrideResult> strides;
  std::vector<PsContactResult> contacts;
  MatchHarness() { PsMatchParams p; m.begin(p); }
  void drain() {
    for (uint8_t i = 0; i < out.n; ++i) {
      if (out.ev[i].isStride) strides.push_back(out.ev[i].s);
      else contacts.push_back(out.ev[i].c);
    }
    out.clear();
  }
  void stride(uint32_t t, bool unknown = false) { m.addStride(t, 300, 1, unknown, out); drain(); }
  void contact(uint32_t t, uint32_t now) { m.addContact(t, PsVal::VALID, now, out); drain(); }
  void poll(uint32_t now) { m.poll(now, out); drain(); }
};

static void testMatcherRules() {
  const PsMatchParams p;
  // X rules.
  CHECK(!PsMatcher::unknownAt(validInsole(), true, p));
  CHECK(PsMatcher::unknownAt(validInsole(), false, p));          // hub IMU not VALID
  PsInsoleView v = validInsole();
  v.paired = false;
  CHECK(PsMatcher::unknownAt(v, true, p));                       // no insole paired
  v = validInsole();
  v.heard = false;
  CHECK(PsMatcher::unknownAt(v, true, p));                       // no heartbeat yet
  CHECK(PsMatcher::unknownAt(validInsole(9), true, p));          // battery < 10 %
  CHECK(!PsMatcher::unknownAt(validInsole(10), true, p));        // 10 % is enough
  CHECK(!PsMatcher::unknownAt(validInsole(PS_BATT_NONE), true, p));  // no battery sense
  PsMatchParams strict;
  strict.nullBatteryOk = false;
  CHECK(PsMatcher::unknownAt(validInsole(PS_BATT_NONE), true, strict));
  v = validInsole();
  v.val = PsVal::DEGRADED;
  CHECK(PsMatcher::unknownAt(v, true, p));
  v.val = PsVal::INVALID;
  CHECK(PsMatcher::unknownAt(v, true, p));
}

static void testMatcherClassify() {
  {  // P with dt; held until settle_ms
    MatchHarness h;
    h.contact(10042, 10050);
    h.stride(10000);
    h.poll(11999);
    CHECK(h.strides.empty());
    h.poll(12000);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'P' && h.strides[0].hasDt && h.strides[0].dt == 42);
    h.poll(20000);
    CHECK(h.contacts.empty());  // consumed by the stride
  }
  {  // Window edges: 300 ms matches, 301 does not.
    MatchHarness h;
    h.stride(10000);
    h.contact(9700, 10010);
    h.poll(12000);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'P' && h.strides[0].dt == -300);
    MatchHarness g;
    g.stride(10000);
    g.contact(10301, 10310);
    g.poll(12000);
    CHECK(g.strides.size() == 1 && g.strides[0].cls == 'U' && !g.strides[0].hasDt);
    g.poll(12301 + 300);
    CHECK(g.contacts.size() == 1 && !g.contacts[0].late);  // unmatched, reported raw
  }
  {  // A contact matches only the nearest stride; ties go to the earlier one.
    MatchHarness h;
    h.stride(10000);
    h.stride(10400);
    h.contact(10250, 10260);  // 250 from the first, 150 from the second
    h.poll(13000);
    CHECK(h.strides.size() == 2 && h.strides[0].cls == 'U' && h.strides[1].cls == 'P' && h.strides[1].dt == -150);
    MatchHarness t;
    t.stride(10000);
    t.stride(10400);
    t.contact(10200, 10210);  // exactly between
    t.poll(13000);
    CHECK(t.strides.size() == 2 && t.strides[0].cls == 'P' && t.strides[0].dt == 200 && t.strides[1].cls == 'U');
  }
  {  // A stride takes the nearest of its contacts; the other is reported raw.
    MatchHarness h;
    h.stride(10000);
    h.contact(9900, 9910);
    h.contact(10050, 10060);
    h.poll(12000);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'P' && h.strides[0].dt == 50);
    h.poll(12301);
    CHECK(h.contacts.size() == 1 && h.contacts[0].tMs == 9900 && !h.contacts[0].late);
  }
  {  // X wins over a matching contact, which is still consumed.
    MatchHarness h;
    h.stride(10000, true);
    h.contact(10020, 10030);
    h.poll(12000);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'X' && !h.strides[0].hasDt);
    h.poll(20000);
    CHECK(h.contacts.empty());
  }
  {  // Late: arrives after its stride was classified. Stride stays U.
    MatchHarness h;
    h.stride(10000);
    h.poll(12000);
    h.contact(10030, 12500);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'U');
    CHECK(h.contacts.size() == 1 && h.contacts[0].late && h.contacts[0].tMs == 10030);
  }
  {  // Late and nearer to a later, still pending stride: it matches that one.
    MatchHarness h;
    h.stride(10000);
    h.stride(10500);
    h.poll(12000);                // first classified U
    h.contact(10400, 12100);      // 400 from the first (outside), 100 from the second
    h.poll(12500);
    CHECK(h.strides.size() == 2 && h.strides[1].cls == 'P' && h.strides[1].dt == -100);
    CHECK(h.contacts.empty());
  }
  {  // Retried packets can arrive out of order.
    MatchHarness h;
    h.contact(11100, 11110);
    h.contact(10010, 11120);
    h.stride(10000);
    h.stride(11100);
    h.poll(14000);
    CHECK(h.strides.size() == 2 && h.strides[0].cls == 'P' && h.strides[0].dt == 10 && h.strides[1].cls == 'P' && h.strides[1].dt == 0);
  }
  {  // Changed parameters apply.
    MatchHarness h;
    PsMatchParams p;
    p.matchMs = 100;
    p.settleMs = 500;
    h.m.setParams(p);
    h.stride(10000);
    h.contact(10150, 10160);
    h.poll(10499);
    CHECK(h.strides.empty());
    h.poll(10500);
    CHECK(h.strides.size() == 1 && h.strides[0].cls == 'U');
  }
}

// A short scripted sequence: walk in the shoe, take it off, walk barefoot,
// insole degraded, hub IMU fault.
static void testMatcherScenario() {
  MatchHarness h;
  PsInsoleView v = validInsole();
  uint32_t t = 10000;
  const PsMatchParams p;
  int P = 0, U = 0, X = 0;
  for (int k = 0; k < 40; ++k, t += 1100) {
    const bool shoe = k < 10;
    if (k == 20) v.val = PsVal::DEGRADED;
    if (k == 25) v.val = PsVal::VALID;
    const bool imuOk = !(k >= 30 && k < 33);
    if (shoe) h.contact(t + 35, t + 40);
    h.m.addStride(t, 300, 1, PsMatcher::unknownAt(v, imuOk, p), h.out);
    h.drain();
    h.poll(t + 300);
  }
  h.poll(t + 5000);
  for (const auto& s : h.strides) {
    if (s.cls == 'P') P++; else if (s.cls == 'U') U++; else X++;
  }
  CHECK(h.strides.size() == 40);
  CHECK(P == 10 && X == 8 && U == 22);
  CHECK(h.contacts.empty());
}

// --------------------------------------------------------------- records ---

static PsRecord rec(PsRecType t, uint32_t seq, uint32_t ms) {
  PsRecord r;
  r.type = t;
  r.seq = seq;
  r.boot = 0x9f3a1c2bu;
  r.ms = ms;
  return r;
}

static std::string json(const PsRecord& r) {
  char b[256];
  const size_t n = psRecordToJson(r, b, sizeof(b));
  return n ? std::string(b) : std::string("<overflow>");
}

static void testRecords() {
  // PROTOCOL.md examples.
  PsRecord s = rec(PsRecType::STRIDE, 1201, 4567890);
  s.cls = 'P'; s.home = 1; s.dt = -42; s.peakDps = 312;
  CHECK(json(s) == "{\"t\":\"stride\",\"seq\":1201,\"boot\":\"9f3a1c2b\",\"ms\":4567890,\"c\":\"P\",\"home\":1,\"dt\":-42,\"pk\":312}");
  PsRecord u = s;
  u.cls = 'U'; u.home = PS_HOME_NULL; u.dt = PS_DT_NULL;
  CHECK(json(u) == "{\"t\":\"stride\",\"seq\":1201,\"boot\":\"9f3a1c2b\",\"ms\":4567890,\"c\":\"U\",\"home\":null,\"dt\":null,\"pk\":312}");
  PsRecord y = rec(PsRecType::SYNC, 1202, 4570000);
  y.epochMs = 1793650000000ULL;
  CHECK(json(y) == "{\"t\":\"sync\",\"seq\":1202,\"boot\":\"9f3a1c2b\",\"ms\":4570000,\"epoch_ms\":1793650000000}");
  PsRecord i = rec(PsRecType::INSOLE, 1203, 4570100);
  i.batt = 71; i.val = PsVal::VALID; i.event = PsInsoleEvent::HEARTBEAT;
  CHECK(json(i) == "{\"t\":\"insole\",\"seq\":1203,\"boot\":\"9f3a1c2b\",\"ms\":4570100,\"batt\":71,\"val\":\"VALID\",\"event\":\"heartbeat\"}");
  PsRecord g = rec(PsRecType::GAP, 1204, 4580000);
  g.reason = PsGapReason::LOG_FULL;
  CHECK(json(g) == "{\"t\":\"gap\",\"seq\":1204,\"boot\":\"9f3a1c2b\",\"ms\":4580000,\"reason\":\"log_full\"}");
  g.lost = 512;
  CHECK(json(g) == "{\"t\":\"gap\",\"seq\":1204,\"boot\":\"9f3a1c2b\",\"ms\":4580000,\"reason\":\"log_full\",\"lost\":512}");
  PsRecord p = rec(PsRecType::INSOLE, 7, 8);
  p.event = PsInsoleEvent::PAIRED; p.batt = PS_BATT_NONE; p.hasId = true;
  const uint8_t id[6] = {0x0A, 0x1B, 0x2C, 0x3D, 0x4E, 0x5F};
  memcpy(p.id, id, 6);
  CHECK(json(p) == "{\"t\":\"insole\",\"seq\":7,\"boot\":\"9f3a1c2b\",\"ms\":8,\"batt\":null,\"val\":\"INVALID\",\"event\":\"paired\",\"id\":\"0A1B2C3D4E5F\"}");
  PsRecord c = rec(PsRecType::CONTACT, 9, 10);
  c.late = true; c.val = PsVal::VALID;
  CHECK(json(c) == "{\"t\":\"contact\",\"seq\":9,\"boot\":\"9f3a1c2b\",\"ms\":10,\"late\":true,\"val\":\"VALID\"}");

  // Binary round trip and torn-record detection.
  const PsRecord all[] = {s, u, y, i, g, p, c};
  for (const PsRecord& r : all) {
    uint8_t b[PS_REC_BYTES];
    psRecordPack(r, b);
    PsRecord back;
    CHECK(psRecordUnpack(b, back) && json(back) == json(r));
    b[17] ^= 0x40;
    CHECK(!psRecordUnpack(b, back));
  }
  uint8_t ff[PS_REC_BYTES];
  memset(ff, 0xFF, sizeof(ff));
  PsRecord back;
  CHECK(!psRecordUnpack(ff, back));  // erased flash

  // Worst-case lengths stay within the 240-byte BLE payload.
  PsRecord big = rec(PsRecType::INSOLE, 0xFFFFFFFFu, 0xFFFFFFFFu);
  big.batt = 100; big.val = PsVal::DEGRADED; big.event = PsInsoleEvent::BATTERY_LOW; big.hasId = true;
  CHECK(json(big).size() <= 240);
  PsRecord bs = rec(PsRecType::STRIDE, 0xFFFFFFFFu, 0xFFFFFFFFu);
  bs.cls = 'P'; bs.home = 1; bs.dt = -32767; bs.peakDps = 65535;
  CHECK(json(bs).size() <= 240);
  PsRecord by = rec(PsRecType::SYNC, 0xFFFFFFFFu, 0xFFFFFFFFu);
  by.epochMs = 0xFFFFFFFFFFFFFFFFULL;
  CHECK(json(by).size() <= 240);

  // Info, Time, Status, backlog_end and error: PROTOCOL.md examples.
  char b[260];
  const uint8_t me[6] = {0xA1, 0xB2, 0xC3, 0xD4, 0xE5, 0xF6};
  CHECK(psInfoJson(PsRole::ANKLE, 0x9f3a1c2bu, me, 87, "insole", true, id, b, sizeof(b)) > 0);
  CHECK(strcmp(b, "{\"proto\":1,\"role\":\"ankle\",\"fw\":\"ps-0.1.0\",\"boot\":\"9f3a1c2b\",\"id\":\"A1B2C3D4E5F6\",\"batt\":87,\"insole\":\"0A1B2C3D4E5F\"}") == 0);
  CHECK(psInfoJson(PsRole::ANKLE, 0x9f3a1c2bu, me, PS_BATT_NONE, "insole", false, id, b, sizeof(b)) > 0);
  CHECK(strstr(b, "\"batt\":null,\"insole\":null}") != nullptr);
  CHECK(psTimeReadJson(4567890, 0x9f3a1c2bu, b, sizeof(b)) > 0 && strcmp(b, "{\"ms\":4567890,\"boot\":\"9f3a1c2b\"}") == 0);
  PsHubStatus st;
  st.ms = 4567890; st.batt = 86; st.val = PsVal::VALID; st.home = 1; st.strides = 1520;
  st.paired = true; memcpy(st.insoleId, id, 6); st.seen = true; st.seenMs = 4566001;
  st.insoleBatt = 71; st.insoleHeard = true; st.insoleVal = PsVal::VALID;
  CHECK(psHubStatusJson(st, b, sizeof(b)) > 0);
  CHECK(strcmp(b, "{\"t\":\"status\",\"ms\":4567890,\"batt\":86,\"val\":\"VALID\",\"home\":1,\"strides_since_boot\":1520,\"insole\":{\"id\":\"0A1B2C3D4E5F\",\"seen_ms\":4566001,\"batt\":71,\"val\":\"VALID\"}}") == 0);
  st.ms = st.strides = st.seenMs = 0xFFFFFFFFu;
  st.val = PsVal::DEGRADED; st.insoleVal = PsVal::DEGRADED; st.batt = 100; st.insoleBatt = 100;
  CHECK(psHubStatusJson(st, b, sizeof(b)) > 0 && strlen(b) <= 240);
  st.paired = false;
  CHECK(psHubStatusJson(st, b, sizeof(b)) > 0 && strstr(b, "\"insole\":null}") != nullptr);
  CHECK(psBacklogEndJson(1203, b, sizeof(b)) > 0 && strcmp(b, "{\"t\":\"backlog_end\",\"last_seq\":1203}") == 0);
  CHECK(psErrorJson("frob", "unknown_cmd", b, sizeof(b)) > 0 && strcmp(b, "{\"t\":\"error\",\"cmd\":\"frob\",\"reason\":\"unknown_cmd\"}") == 0);
}

// -------------------------------------------------------------- ring log ---

class MemStorage : public PsLogStorage {
public:
  std::map<uint32_t, std::vector<uint8_t>> files;
  size_t budget = 1 << 30;  // total bytes before append fails
  uint32_t reserved = 0, acked = 0;
  int reservations = 0;

  size_t used() const {
    size_t u = 0;
    for (const auto& f : files) u += f.second.size();
    return u;
  }
  int list(uint32_t* ids, int max) override {
    int n = 0;
    for (const auto& f : files) if (n < max) ids[n++] = f.first;
    return n;
  }
  int32_t size(uint32_t id) override {
    auto it = files.find(id);
    return it == files.end() ? -1 : (int32_t)it->second.size();
  }
  bool append(uint32_t id, const uint8_t* d, size_t n) override {
    if (used() + n > budget) return false;
    auto& f = files[id];
    f.insert(f.end(), d, d + n);
    return true;
  }
  bool read(uint32_t id, size_t off, uint8_t* d, size_t n) override {
    auto it = files.find(id);
    if (it == files.end() || off + n > it->second.size()) return false;
    memcpy(d, it->second.data() + off, n);
    return true;
  }
  bool remove(uint32_t id) override { return files.erase(id) > 0; }
  void persistSeqReservation(uint32_t upto) override { reserved = upto; reservations++; }
  void persistAcked(uint32_t upto) override { acked = upto; }
};

class CountingListener : public PsLogListener {
public:
  std::vector<PsRecord> seen;
  void onLogged(const PsRecord& r) override { seen.push_back(r); }
};

static PsRecord strideRec(uint32_t ms) {
  PsRecord r;
  r.type = PsRecType::STRIDE;
  r.ms = ms;
  r.cls = 'U';
  return r;
}

static std::vector<PsRecord> readAll(PsRingLog& log, uint32_t from) {
  std::vector<PsRecord> v;
  PsLogCursor c;
  c.nextSeq = from;
  PsRecord buf[5];
  int n;
  while ((n = log.read(c, buf, 5)) > 0) for (int i = 0; i < n; ++i) v.push_back(buf[i]);
  return v;
}

static bool contiguous(const std::vector<PsRecord>& v) {
  for (size_t i = 1; i < v.size(); ++i) if (v[i].seq <= v[i - 1].seq) return false;
  return true;
}

static void testRingLog() {
  MemStorage st;
  CountingListener ls;
  {
    PsRingLog log;
    log.begin(&st, &ls, 0x11111111u, 16, 8, st.reserved, st.acked, 0);
    CHECK(st.reserved == 256 && log.lastSeq() == 0);
    for (uint32_t k = 0; k < 40; ++k) { PsRecord r = strideRec(k); log.append(r, k); }
    CHECK(ls.seen.size() == 40 && ls.seen.front().seq == 1 && ls.seen.back().seq == 40);
    // 32 flushed automatically (buffer full), 8 still in RAM: all readable.
    const auto all = readAll(log, 0);
    CHECK(all.size() == 40 && all.front().seq == 1 && all.back().seq == 40 && contiguous(all));
    CHECK(all[7].ms == 7 && all[7].boot == 0x11111111u);
    CHECK(st.used() == 32 * PS_REC_BYTES);
    const auto from = readAll(log, 35);
    CHECK(from.size() == 6 && from.front().seq == 35);
    // Flush is due PS_LOG_FLUSH_MS after the previous one (the automatic
    // flush when the buffer filled, at t = 31), not before.
    log.flushIfDue(31 + PS_LOG_FLUSH_MS - 1);
    CHECK(st.used() == 32 * PS_REC_BYTES);
    log.flushIfDue(31 + PS_LOG_FLUSH_MS);
    CHECK(st.used() == 40 * PS_REC_BYTES);
    for (uint32_t k = 0; k < 3; ++k) { PsRecord r = strideRec(100 + k); log.append(r, 100000); }
    // Power cut here: records 41-43 were never flushed.
  }
  {
    // Reboot: numbering resumes above the reservation, never reusing 41-43.
    PsRingLog log;
    log.begin(&st, &ls, 0x22222222u, 16, 8, st.reserved, st.acked, 0);
    CHECK(log.lastSeq() == 256 && log.storedRecords() == 40);
    PsRecord g;
    g.type = PsRecType::GAP;
    g.reason = PsGapReason::REBOOT;
    log.append(g, 0);
    CHECK(g.seq == 257 && g.boot == 0x22222222u);
    log.flush(1);
    const auto all = readAll(log, 0);
    CHECK(all.size() == 41 && all.back().seq == 257 && contiguous(all));
    // The new boot wrote a new segment.
    CHECK(st.files.size() == 4);  // 16 + 16 + 8 from boot 1, 1 from boot 2
    // Ack frees whole closed segments only.
    log.ack(20);
    CHECK(st.acked == 20 && st.files.size() == 3);   // segment 1..16 freed
    log.ack(10000);                                  // clamps to the last seq
    CHECK(log.ackedUpto() == 257);
    CHECK(st.files.size() == 1);                     // only the current segment stays
    CHECK(readAll(log, 0).size() == 1);
  }
  {
    // Torn tail: the last record of a segment is half-written.
    MemStorage t;
    PsRingLog log;
    log.begin(&t, nullptr, 1, 16, 8, 0, 0, 0);
    for (uint32_t k = 0; k < 5; ++k) { PsRecord r = strideRec(k); log.append(r, 0); }
    log.flush(0);
    auto& f = t.files.begin()->second;
    f[f.size() - 3] ^= 0xFF;      // corrupt record 5
    f.resize(f.size() + 10, 0);   // plus a partial record
    PsRingLog again;
    again.begin(&t, nullptr, 2, 16, 8, t.reserved, 0, 0);
    const auto all = readAll(again, 0);
    CHECK(all.size() == 4 && all.back().seq == 4);
    PsRecord r = strideRec(9);
    again.append(r, 0);
    CHECK(r.seq == 257);
  }
  {
    // Full log: the oldest unacked segment is dropped and a gap is logged.
    MemStorage f;
    CountingListener fl;
    PsRingLog log;
    log.begin(&f, &fl, 3, 4, 3, 0, 0, 0);  // 3 segments of 4 records
    for (uint32_t k = 0; k < 20; ++k) { PsRecord r = strideRec(k); log.append(r, k); log.flush(k); }
    int gaps = 0;
    uint32_t lostTotal = 0;
    for (const auto& r : fl.seen) if (r.type == PsRecType::GAP) { gaps++; lostTotal += r.lost; }
    CHECK(gaps >= 1 && f.files.size() <= 3);
    CHECK(lostTotal == log.droppedSinceBoot() && lostTotal > 0);
    const auto all = readAll(log, 0);
    CHECK(contiguous(all) && all.back().seq == fl.seen.back().seq);
    CHECK(all.size() <= 12);
    // Acked records are dropped without a gap.
    MemStorage a;
    CountingListener al;
    PsRingLog log2;
    log2.begin(&a, &al, 4, 4, 3, 0, 0, 0);
    for (uint32_t k = 0; k < 12; ++k) { PsRecord r = strideRec(k); log2.append(r, k); log2.flush(k); }
    log2.ack(12);  // frees 1-4 and 5-8; 9-12 is the current segment and stays
    CHECK(a.files.size() == 1);
    for (uint32_t k = 0; k < 9; ++k) { PsRecord r = strideRec(k); log2.append(r, k); log2.flush(k); }
    int g2 = 0;
    for (const auto& r : al.seen) if (r.type == PsRecType::GAP) g2++;
    CHECK(g2 == 0 && a.files.size() == 3);  // 9-12 went to make room, but it was acked
    for (uint32_t k = 0; k < 4; ++k) { PsRecord r = strideRec(k); log2.append(r, k); log2.flush(k); }
    g2 = 0;
    for (const auto& r : al.seen) if (r.type == PsRecType::GAP) { g2++; CHECK(r.lost == 4); }
    CHECK(g2 == 1);  // 13-16 was not acked
  }
  {
    // The file system refuses a write: free the oldest segment, keep going.
    MemStorage f;
    f.budget = 10 * PS_REC_BYTES;
    CountingListener fl;
    PsRingLog log;
    log.begin(&f, &fl, 5, 4, 100, 0, 0, 0);
    for (uint32_t k = 0; k < 30; ++k) { PsRecord r = strideRec(k); log.append(r, k); log.flush(k); }
    CHECK(f.used() <= f.budget);
    int gaps = 0;
    for (const auto& r : fl.seen) if (r.type == PsRecType::GAP) gaps++;
    CHECK(gaps >= 1);
    const auto all = readAll(log, 0);
    CHECK(!all.empty() && contiguous(all) && all.back().seq == fl.seen.back().seq);
  }
}

// --------------------------------------------------------------- packets ---

static void testPackets() {
  PsPacket p;
  p.type = PsPktType::CONTACTS;
  p.boot = 0xDEADBEEF;
  p.pktSeq = 7;
  p.txMs = 123456;
  p.val = PsVal::VALID;
  p.batt = PS_BATT_NONE;
  p.n = 3;
  for (uint8_t i = 0; i < 3; ++i) { p.c[i].seq = 100 + i; p.c[i].ms = 5000 + 1000 * i; }
  uint8_t b[PS_PKT_MAX];
  const size_t n = psPacketEncode(p, b, sizeof(b));
  CHECK(n == PS_PKT_HEADER + 4 + 24);
  psPacketStamp(b, n, 999);
  PsPacket q;
  CHECK(psPacketDecode(b, n, q) && q.type == PsPktType::CONTACTS && q.boot == 0xDEADBEEF && q.txMs == 999);
  CHECK(q.n == 3 && q.c[2].seq == 102 && q.c[2].ms == 7000 && q.batt == PS_BATT_NONE && q.val == PsVal::VALID);
  CHECK(!psPacketDecode(b, n - 1, q));
  b[0] = 'X';
  CHECK(!psPacketDecode(b, n, q));
  p.n = 0;
  CHECK(psPacketEncode(p, b, sizeof(b)) == 0);
  p.n = 17;
  CHECK(psPacketEncode(p, b, sizeof(b)) == 0);
  p.n = 16;
  CHECK(psPacketEncode(p, b, sizeof(b)) == PS_PKT_HEADER + 4 + 128);

  PsPacket h;
  h.type = PsPktType::HEARTBEAT;
  h.batt = 71;
  h.val = PsVal::DEGRADED;
  h.channel = 6;
  h.dropped = 3;
  const size_t hn = psPacketEncode(h, b, sizeof(b));
  CHECK(hn == PS_PKT_HEADER + 8 && psPacketDecode(b, hn, q) && q.batt == 71 && q.val == PsVal::DEGRADED && q.channel == 6 && q.dropped == 3);
  b[PS_PKT_HEADER + 1] = 7;  // invalid validity value
  CHECK(!psPacketDecode(b, hn, q));
  PsPacket a;
  a.type = PsPktType::PAIR_ACK;
  a.channel = 11;
  const size_t an = psPacketEncode(a, b, sizeof(b));
  CHECK(psPacketDecode(b, an, q) && q.type == PsPktType::PAIR_ACK && q.channel == 11);
  PsPacket r;
  r.type = PsPktType::PAIR_REQ;
  const size_t rn = psPacketEncode(r, b, sizeof(b));
  CHECK(rn == PS_PKT_HEADER && psPacketDecode(b, rn, q) && q.type == PsPktType::PAIR_REQ);
}

// ---------------------------------------------------------------- outbox ---

static void testOutbox() {
  PsOutbox o;
  o.reset();
  PsPacket p;
  CHECK(!o.due(0, p));
  o.push(1, 100);
  o.push(2, 200);
  CHECK(o.due(0, p) && p.n == 2 && p.c[0].seq == 1);
  CHECK(!o.due(0, p));            // one in flight
  o.push(3, 300);                 // arrives while in flight
  o.sent(false, 10);
  CHECK(o.size() == 3 && o.failStreak() == 1);
  CHECK(!o.due(29, p));           // retry after 20 ms
  CHECK(o.due(30, p) && p.n == 3);
  o.sent(false, 30);
  CHECK(!o.due(69, p) && o.due(70, p));  // then 40 ms
  o.sent(true, 75);
  CHECK(o.size() == 0 && o.failStreak() == 0);
  // Backoff caps at kRetryMaxMs.
  o.push(4, 400);
  uint32_t t = 100;
  for (int k = 0; k < 12; ++k) {
    while (!o.due(t, p)) t++;
    o.sent(false, t);
  }
  const uint32_t before = t;
  while (!o.due(t, p)) t++;
  CHECK(t - before == PsOutbox::kRetryMaxMs);
  o.sent(true, t);
  // More than 16 queued: two packets.
  for (uint32_t k = 0; k < 20; ++k) o.push(10 + k, k);
  CHECK(o.due(t, p) && p.n == 16);
  o.sent(true, t);
  CHECK(o.due(t, p) && p.n == 4 && p.c[0].seq == 26);
  o.sent(true, t);
  // Overflow drops the oldest and counts it.
  for (uint32_t k = 0; k < PsOutbox::kCapacity + 5; ++k) o.push(100 + k, k);
  CHECK(o.size() == PsOutbox::kCapacity && o.dropped() == 5);
  CHECK(o.due(t, p) && p.c[0].seq == 105);
}

// ------------------------------------------------------ home, IMU, rx -----

static void testHome() {
  PsHomeConfig cfg;
  PsScanEntry e[2];
  strcpy(e[0].ssid, "Neighbour");
  memset(e[0].bssid, 1, 6);
  e[0].rssi = -50;
  strcpy(e[1].ssid, "MyHome");
  const uint8_t bss[6] = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF};
  memcpy(e[1].bssid, bss, 6);
  e[1].rssi = -80;
  CHECK(psHomeFlag(cfg, e, 2) == PS_HOME_NULL);  // not configured
  strcpy(cfg.ssid, "MyHome");
  CHECK(psHomeFlag(cfg, e, 2) == 1);
  e[1].rssi = -85;                               // must be above -85 dBm
  CHECK(psHomeFlag(cfg, e, 2) == 0);
  e[1].rssi = -84;
  CHECK(psHomeFlag(cfg, e, 2) == 1);
  CHECK(psHomeFlag(cfg, e, 0) == 0);             // nothing seen: away
  CHECK(psHomeFlag(cfg, e, -1) == PS_HOME_NULL); // scan failed: unknown
  PsHomeConfig byBssid;
  memcpy(byBssid.bssid, bss, 6);
  strcpy(e[1].ssid, "Renamed");
  CHECK(psHomeFlag(byBssid, e, 2) == 1);
}

static void testImuValidity() {
  PsImuValidity v;
  int16_t raw[6] = {1, 2, 3, 4, 5, 6};
  v.begin(false, 0);
  CHECK(v.state() == PsVal::INVALID);
  v.begin(true, 0);
  uint32_t t = 0;
  int k = 0;
  auto step = [&](bool ok, bool sat) {
    raw[0] = (int16_t)(k++ % 7);  // live noise
    t += 10;
    return v.update(ok, sat, raw, t);
  };
  for (int i = 0; i < 150; ++i) step(true, false);
  CHECK(v.state() == PsVal::DEGRADED);  // not yet 2 s clean
  for (int i = 0; i < 150; ++i) step(true, false);
  CHECK(v.state() == PsVal::VALID);
  step(true, true);                     // one saturated sample
  CHECK(v.state() == PsVal::DEGRADED);
  for (int i = 0; i < 400; ++i) step(true, false);
  CHECK(v.state() == PsVal::VALID);
  int edges = 0;
  for (int i = 0; i < 9; ++i) edges += step(false, false);
  CHECK(v.state() == PsVal::DEGRADED && edges == 0);
  edges += step(false, false);          // 10th consecutive failure
  CHECK(v.state() == PsVal::INVALID && edges == 1);
  for (int i = 0; i < 5; ++i) edges += step(false, false);
  CHECK(edges == 1);                    // reported once
  for (int i = 0; i < 400; ++i) step(true, false);
  CHECK(v.state() == PsVal::VALID);
  // Frozen sensor: identical readings for 1 s.
  for (int i = 0; i < 100; ++i) { t += 10; v.update(true, false, raw, t); }
  CHECK(v.state() == PsVal::INVALID);
}

static void testInsoleRx() {
  PsInsoleRx rx;
  rx.clock.begin();
  PsPacket p;
  p.boot = 1;
  p.txMs = 1000;
  CHECK(!rx.onPacket(p, 6000));
  CHECK(rx.acceptContact(1) && rx.acceptContact(2) && !rx.acceptContact(2) && !rx.acceptContact(1) && rx.acceptContact(5));
  uint32_t h;
  CHECK(rx.clock.toHub(2000, h) && h == 7000);
  p.boot = 2;  // insole rebooted
  p.txMs = 10;
  CHECK(rx.onPacket(p, 9000));
  CHECK(rx.acceptContact(1));
  CHECK(rx.clock.toHub(20, h) && h == 9010);
  CHECK(!rx.checkLost(9000 + PS_INSOLE_LOST_MS - 1, 0));
  CHECK(rx.checkLost(9000 + PS_INSOLE_LOST_MS, 0));
  CHECK(!rx.checkLost(9000 + PS_INSOLE_LOST_MS + 50000, 0));  // once
  rx.onPacket(p, 200000);
  CHECK(!rx.lost);
  // The caller's clock can be read just before the reference was set
  // (seen on the board: "lost" logged at the moment of pairing).
  PsInsoleRx fresh;
  CHECK(!fresh.checkLost(9504, 9505));
  CHECK(!fresh.checkLost(9505 + PS_INSOLE_LOST_MS - 1, 9505));
  CHECK(fresh.checkLost(9505 + PS_INSOLE_LOST_MS, 9505));
  uint8_t mac[6];
  CHECK(psParseMac("28:05:a5:2f:71:ec", mac) && mac[5] == 0xEC);
  char hex[13];
  psMacToHex(mac, hex);
  CHECK(strcmp(hex, "2805A52F71EC") == 0);
  char boot[9];
  psBootToHex(0x0000abcdu, boot);
  CHECK(strcmp(boot, "0000abcd") == 0);
}

int main() {
  testJson();
  testCommands();
  testStride();
  testGyroBias();
  testOffset();
  testMatcherRules();
  testMatcherClassify();
  testMatcherScenario();
  testRecords();
  testRingLog();
  testPackets();
  testOutbox();
  testHome();
  testImuValidity();
  testInsoleRx();
  printf("ps_logic_test: %d checks, %d failed\n", checks, failures);
  return failures == 0 ? 0 : 1;
}
