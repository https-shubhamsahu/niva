// ps_storage_littlefs.h - PsLogStorage on LittleFS (ESP32 only).
//
// Segments are files /log/XXXXXXXX.bin (hex segment id). LittleFS is
// copy-on-write with wear levelling and the log only ever appends whole
// records, then deletes whole files, so there is no in-place rewriting.

#ifndef PS_STORAGE_LITTLEFS_H
#define PS_STORAGE_LITTLEFS_H

#include <FS.h>
#include <LittleFS.h>

#include "ps_device.h"
#include "ps_ringlog.h"

class PsLittleFsStorage : public PsLogStorage {
public:
  bool begin() {
    // Formats the partition if it does not hold a LittleFS (first flash).
    if (!LittleFS.begin(true)) return false;
    if (!LittleFS.exists("/log")) LittleFS.mkdir("/log");
    return true;
  }

  size_t totalBytes() { return LittleFS.totalBytes(); }
  size_t usedBytes() { return LittleFS.usedBytes(); }

  int list(uint32_t* ids, int max) override {
    File dir = LittleFS.open("/log");
    if (!dir || !dir.isDirectory()) return 0;
    int n = 0;
    for (File f = dir.openNextFile(); f && n < max; f = dir.openNextFile()) {
      uint32_t id;
      if (parseName(f.name(), id)) ids[n++] = id;
      f.close();
    }
    dir.close();
    return n;
  }

  int32_t size(uint32_t id) override {
    char p[24];
    path(id, p);
    File f = LittleFS.open(p, "r");
    if (!f) return -1;
    const int32_t s = (int32_t)f.size();
    f.close();
    return s;
  }

  bool append(uint32_t id, const uint8_t* d, size_t n) override {
    closeReader(id);
    char p[24];
    path(id, p);
    File f = LittleFS.open(p, "a");
    if (!f) return false;
    const size_t w = f.write(d, n);
    f.close();
    return w == n;
  }

  bool read(uint32_t id, size_t off, uint8_t* d, size_t n) override {
    if (!_reader || _readerId != id) {
      closeReader(_readerId);
      char p[24];
      path(id, p);
      _reader = LittleFS.open(p, "r");
      _readerId = id;
      if (!_reader) return false;
    }
    if (!_reader.seek(off)) return false;
    return _reader.read(d, n) == n;
  }

  bool remove(uint32_t id) override {
    closeReader(id);
    char p[24];
    path(id, p);
    return LittleFS.remove(p);
  }

  void persistSeqReservation(uint32_t upto) override {
    psCfg.seqReserved = upto;
    psSaveSeqReserved();
  }

  void persistAcked(uint32_t upto) override {
    psCfg.acked = upto;
    psSaveAcked();
  }

private:
  static void path(uint32_t id, char out[24]) { snprintf(out, 24, "/log/%08lx.bin", (unsigned long)id); }

  static bool parseName(const char* name, uint32_t& id) {
    const char* base = strrchr(name, '/');
    base = base ? base + 1 : name;
    if (strlen(base) != 12 || strcmp(base + 8, ".bin") != 0) return false;
    uint32_t v = 0;
    for (int i = 0; i < 8; ++i) {
      const int h = psHexNibble(base[i]);
      if (h < 0) return false;
      v = (v << 4) | (uint32_t)h;
    }
    id = v;
    return true;
  }

  void closeReader(uint32_t id) {
    if (_reader && _readerId == id) _reader.close();
  }

  File _reader;
  uint32_t _readerId = 0;
};

#endif  // PS_STORAGE_LITTLEFS_H
