// ps_json.h - a small parser for flat JSON objects, and output helpers.
//
// Commands in PROTOCOL.md are flat objects whose values are strings,
// integers, booleans or null. This parser accepts exactly that and rejects
// anything else (nested objects, arrays, fractions, \u escapes), so a
// malformed command produces an error record instead of a guess.
// Pure C++; unit-tested on the host.

#ifndef PS_JSON_H
#define PS_JSON_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>

enum class PsJsonType : uint8_t { STRING, INT, BOOL, NUL };

struct PsJsonField {
  const char* key;  // points into the source text; not NUL-terminated
  size_t keyLen;
  PsJsonType type;
  const char* str;  // raw string body (escapes still encoded)
  size_t strLen;
  int64_t num;
  bool b;
};

struct PsJsonObject {
  static const int kMaxFields = 12;
  PsJsonField f[kMaxFields];
  int n = 0;

  const PsJsonField* find(const char* key) const {
    const size_t kl = strlen(key);
    for (int i = 0; i < n; ++i) {
      if (f[i].keyLen == kl && memcmp(f[i].key, key, kl) == 0) return &f[i];
    }
    return nullptr;
  }

  // Copies a decoded string value. Returns false if absent, not a string,
  // or too long for the buffer.
  bool getString(const char* key, char* out, size_t cap) const {
    const PsJsonField* p = find(key);
    if (p == nullptr || p->type != PsJsonType::STRING) return false;
    size_t o = 0;
    for (size_t i = 0; i < p->strLen; ++i) {
      char c = p->str[i];
      if (c == '\\') {
        ++i;  // the parser guarantees a valid escape follows
        switch (p->str[i]) {
          case 'n': c = '\n'; break;
          case 't': c = '\t'; break;
          case 'r': c = '\r'; break;
          case 'b': c = '\b'; break;
          case 'f': c = '\f'; break;
          default: c = p->str[i]; break;  // \" \\ \/
        }
      }
      if (o + 1 >= cap) return false;
      out[o++] = c;
    }
    out[o] = '\0';
    return true;
  }

  bool getInt(const char* key, int64_t& out) const {
    const PsJsonField* p = find(key);
    if (p == nullptr || p->type != PsJsonType::INT) return false;
    out = p->num;
    return true;
  }

  bool isNull(const char* key) const {
    const PsJsonField* p = find(key);
    return p != nullptr && p->type == PsJsonType::NUL;
  }
};

namespace psjson_detail {
inline void skipWs(const char*& p, const char* e) {
  while (p < e && (*p == ' ' || *p == '\t' || *p == '\n' || *p == '\r')) ++p;
}
inline bool parseString(const char*& p, const char* e, const char*& s, size_t& len) {
  if (p >= e || *p != '"') return false;
  ++p;
  s = p;
  while (p < e && *p != '"') {
    if ((unsigned char)*p < 0x20) return false;
    if (*p == '\\') {
      ++p;
      if (p >= e) return false;
      if (strchr("\"\\/bfnrt", *p) == nullptr || *p == '\0') return false;  // no \u
    }
    ++p;
  }
  if (p >= e) return false;
  len = (size_t)(p - s);
  ++p;  // closing quote
  return true;
}
}  // namespace psjson_detail

// Parses `text` (length n) as one flat JSON object. Returns false on any
// syntax error, duplicate key, or more than kMaxFields fields.
inline bool psJsonParse(const char* text, size_t n, PsJsonObject& out) {
  using namespace psjson_detail;
  out.n = 0;
  const char* p = text;
  const char* e = text + n;
  skipWs(p, e);
  if (p >= e || *p != '{') return false;
  ++p;
  skipWs(p, e);
  if (p < e && *p == '}') {
    ++p;
    skipWs(p, e);
    return p == e;
  }
  for (;;) {
    if (out.n >= PsJsonObject::kMaxFields) return false;
    PsJsonField& f = out.f[out.n];
    skipWs(p, e);
    if (!parseString(p, e, f.key, f.keyLen)) return false;
    for (int i = 0; i < out.n; ++i) {
      if (out.f[i].keyLen == f.keyLen && memcmp(out.f[i].key, f.key, f.keyLen) == 0) return false;
    }
    skipWs(p, e);
    if (p >= e || *p != ':') return false;
    ++p;
    skipWs(p, e);
    if (p >= e) return false;
    f.str = nullptr;
    f.strLen = 0;
    f.num = 0;
    f.b = false;
    if (*p == '"') {
      f.type = PsJsonType::STRING;
      if (!parseString(p, e, f.str, f.strLen)) return false;
    } else if (*p == '-' || (*p >= '0' && *p <= '9')) {
      bool neg = false;
      if (*p == '-') { neg = true; ++p; }
      if (p >= e || *p < '0' || *p > '9') return false;
      if (*p == '0' && p + 1 < e && p[1] >= '0' && p[1] <= '9') return false;  // leading zero
      uint64_t v = 0;
      int digits = 0;
      while (p < e && *p >= '0' && *p <= '9') {
        if (++digits > 18) return false;  // keeps v well inside int64
        v = v * 10 + (uint64_t)(*p - '0');
        ++p;
      }
      if (p < e && (*p == '.' || *p == 'e' || *p == 'E')) return false;  // integers only
      f.type = PsJsonType::INT;
      f.num = neg ? -(int64_t)v : (int64_t)v;
    } else if (e - p >= 4 && memcmp(p, "true", 4) == 0) {
      f.type = PsJsonType::BOOL; f.b = true; p += 4;
    } else if (e - p >= 5 && memcmp(p, "false", 5) == 0) {
      f.type = PsJsonType::BOOL; f.b = false; p += 5;
    } else if (e - p >= 4 && memcmp(p, "null", 4) == 0) {
      f.type = PsJsonType::NUL; p += 4;
    } else {
      return false;  // objects, arrays and anything else
    }
    out.n++;
    skipWs(p, e);
    if (p >= e) return false;
    if (*p == ',') { ++p; continue; }
    if (*p == '}') { ++p; break; }
    return false;
  }
  skipWs(p, e);
  return p == e;
}

// Writes s as a JSON string literal (with quotes) into buf. Control
// characters become \u00XX. Returns bytes written, or 0 if it did not fit.
inline size_t psJsonQuote(char* buf, size_t cap, const char* s) {
  size_t o = 0;
  auto put = [&](char c) -> bool {
    if (o + 1 >= cap) return false;
    buf[o++] = c;
    return true;
  };
  if (!put('"')) return 0;
  for (const char* p = s; *p; ++p) {
    const unsigned char c = (unsigned char)*p;
    if (c == '"' || c == '\\') {
      if (!put('\\') || !put((char)c)) return 0;
    } else if (c < 0x20) {
      char tmp[7];
      snprintf(tmp, sizeof(tmp), "\\u%04x", c);
      for (int i = 0; i < 6; ++i) if (!put(tmp[i])) return 0;
    } else {
      if (!put((char)c)) return 0;
    }
  }
  if (!put('"')) return 0;
  buf[o] = '\0';
  return o;
}

// Bounded appender used by every encoder: keeps track of the length and
// remembers whether anything was truncated.
struct PsOut {
  char* buf;
  size_t cap;
  size_t len = 0;
  bool overflow = false;

  PsOut(char* b, size_t c) : buf(b), cap(c) {
    if (cap > 0) buf[0] = '\0';
  }

  void raw(const char* s) {
    const size_t n = strlen(s);
    if (overflow || len + n + 1 > cap) { overflow = true; return; }
    memcpy(buf + len, s, n + 1);
    len += n;
  }
  void i64(int64_t v) {
    char tmp[24];
    snprintf(tmp, sizeof(tmp), "%lld", (long long)v);
    raw(tmp);
  }
  void u64(uint64_t v) {
    char tmp[24];
    snprintf(tmp, sizeof(tmp), "%llu", (unsigned long long)v);
    raw(tmp);
  }
  void str(const char* s) {
    if (overflow) return;
    const size_t n = psJsonQuote(buf + len, cap - len, s);
    if (n == 0) { overflow = true; buf[len] = '\0'; return; }
    len += n;
  }
  bool ok() const { return !overflow; }
};

#endif  // PS_JSON_H
