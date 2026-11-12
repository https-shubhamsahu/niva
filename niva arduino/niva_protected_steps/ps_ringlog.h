// ps_ringlog.h - the hub's persistent record log. Pure C++ over an abstract
// storage interface; host-tested with an in-memory store, run on LittleFS
// on the ESP32 (ps_storage_littlefs.h).
//
// Layout: the log is a sequence of append-only segment files, each holding
// up to recordsPerSegment fixed-size records (ps_record.h). Every boot
// starts a new segment, so within one segment seq rises by exactly one per
// record. Records wait in a RAM buffer and are written at least every
// PS_LOG_FLUSH_MS (30 s, design choice; PROTOCOL.md requires <= 60 s) or
// when the buffer fills.
//
// seq: hub-wide, increasing from 1, never reused. Records are notified over
// BLE before they reach flash, so a power cut could otherwise reuse the seq
// of a record the phone already has. To prevent that, seq values are
// reserved in blocks of kSeqReserve and the reservation is persisted (NVS)
// before any of them is used; after a reboot numbering resumes above the
// reservation. seq therefore has gaps across reboots, never repeats.
//
// Full log: when a new segment is needed and maxSegments exist (or the file
// system refuses a write), the oldest segment is deleted and, if it held
// records not yet acknowledged, a gap record with reason "log_full" is
// appended. Acknowledged records are freed segment by segment: a closed
// segment whose last seq is <= the acknowledged seq is deleted.

#ifndef PS_RINGLOG_H
#define PS_RINGLOG_H

#include "ps_record.h"

class PsLogStorage {
public:
  virtual ~PsLogStorage() {}
  virtual int list(uint32_t* ids, int max) = 0;                       // any order
  virtual int32_t size(uint32_t id) = 0;                              // bytes, -1 if absent
  virtual bool append(uint32_t id, const uint8_t* d, size_t n) = 0;   // creates if absent
  virtual bool read(uint32_t id, size_t off, uint8_t* d, size_t n) = 0;
  virtual bool remove(uint32_t id) = 0;
  virtual void persistSeqReservation(uint32_t upto) = 0;
  virtual void persistAcked(uint32_t upto) = 0;
};

class PsLogListener {
public:
  virtual ~PsLogListener() {}
  virtual void onLogged(const PsRecord& r) = 0;  // every record, as it gets its seq
};

struct PsLogCursor {
  uint32_t nextSeq = 0;
};

class PsRingLog {
public:
  static const uint16_t kMaxSegments = 128;
  static const uint8_t kBufRecords = 32;     // design choice
  static const uint32_t kSeqReserve = 256;   // design choice

  // reservedUpto / ackedUpto come from NVS (0 on a fresh device).
  bool begin(PsLogStorage* st, PsLogListener* listener, uint32_t bootId,
             uint32_t recordsPerSegment, uint16_t maxSegments,
             uint32_t reservedUpto, uint32_t ackedUpto, uint32_t nowMs) {
    _st = st;
    _listener = listener;
    _boot = bootId;
    _perSeg = recordsPerSegment > 0 ? recordsPerSegment : 1;
    _maxSeg = maxSegments < 2 ? 2 : (maxSegments > kMaxSegments ? kMaxSegments : maxSegments);
    _acked = ackedUpto;
    _nbuf = 0;
    _nseg = 0;
    _curOpen = false;
    _lastFlushMs = nowMs;
    _droppedSinceBoot = 0;

    uint32_t ids[kMaxSegments];
    int n = _st->list(ids, kMaxSegments);
    if (n < 0) n = 0;
    // Insertion sort by id.
    for (int i = 1; i < n; ++i) {
      const uint32_t v = ids[i];
      int j = i - 1;
      while (j >= 0 && ids[j] > v) { ids[j + 1] = ids[j]; --j; }
      ids[j + 1] = v;
    }
    uint32_t lastSeq = 0;
    uint32_t maxId = 0;
    for (int i = 0; i < n; ++i) {
      if (ids[i] > maxId) maxId = ids[i];
      const int32_t bytes = _st->size(ids[i]);
      uint32_t count = bytes > 0 ? (uint32_t)bytes / PS_REC_BYTES : 0;
      PsRecord first, last;
      // A power cut can only tear the tail: trim invalid records from the end.
      while (count > 0 && !readAt(ids[i], count - 1, last)) count--;
      if (count == 0 || !readAt(ids[i], 0, first)) {
        _st->remove(ids[i]);
        continue;
      }
      Seg& s = _seg[_nseg++];
      s.id = ids[i];
      s.firstSeq = first.seq;
      s.count = count;
      if (last.seq > lastSeq) lastSeq = last.seq;
    }
    _curId = maxId + 1;
    _next = (lastSeq > reservedUpto ? lastSeq : reservedUpto) + 1;
    _reserved = _next - 1;
    reserve();
    return true;
  }

  uint32_t lastSeq() const { return _next - 1; }
  uint32_t ackedUpto() const { return _acked; }
  uint32_t droppedSinceBoot() const { return _droppedSinceBoot; }
  uint16_t segments() const { return _nseg; }

  uint32_t storedRecords() const {
    uint32_t t = _nbuf;
    for (uint16_t i = 0; i < _nseg; ++i) t += _seg[i].count;
    return t;
  }

  uint32_t oldestSeq() const {
    if (_nseg > 0) return _seg[0].firstSeq;
    if (_nbuf > 0) return _buf[0].seq;
    return 0;
  }

  // Assigns boot and seq, buffers the record, tells the listener, and
  // flushes if the buffer is full. `r` returns with its seq.
  bool append(PsRecord& r, uint32_t nowMs) {
    r.boot = _boot;
    r.seq = _next++;
    reserve();
    if (_nbuf >= kBufRecords + kHeadroom) return false;  // flush kept failing
    _buf[_nbuf++] = r;
    if (_listener) _listener->onLogged(r);
    if (_nbuf >= kBufRecords) flush(nowMs);
    return true;
  }

  bool flushIfDue(uint32_t nowMs) {
    if (_nbuf == 0) { _lastFlushMs = nowMs; return true; }
    if ((uint32_t)(nowMs - _lastFlushMs) < PS_LOG_FLUSH_MS) return true;
    return flush(nowMs);
  }

  bool flush(uint32_t nowMs) {
    _lastFlushMs = nowMs;
    uint8_t i = 0;
    uint8_t guard = 0;
    while (i < _nbuf) {
      if (!_curOpen || _seg[_nseg - 1].count >= _perSeg) {
        if (!openSegment(nowMs)) break;
      }
      Seg& s = _seg[_nseg - 1];
      uint8_t packed[PS_REC_BYTES * 8];
      uint8_t k = 0;
      while (k < 8 && i + k < _nbuf && s.count + k < _perSeg) {
        psRecordPack(_buf[i + k], packed + PS_REC_BYTES * k);
        ++k;
      }
      if (_st->append(s.id, packed, PS_REC_BYTES * k)) {
        if (s.count == 0) s.firstSeq = _buf[i].seq;
        s.count += k;
        i += k;
        guard = 0;
      } else {
        // Most likely the file system is full: free the oldest segment and
        // try again, a bounded number of times.
        if (++guard > 3 || !dropOldest(nowMs, true)) break;
      }
    }
    // Keep whatever could not be written.
    const uint8_t left = (uint8_t)(_nbuf - i);
    for (uint8_t k = 0; k < left; ++k) _buf[k] = _buf[i + k];
    _nbuf = left;
    return left == 0;
  }

  // Frees acknowledged segments. Never deletes the segment being written.
  void ack(uint32_t upto) {
    if (upto > lastSeq()) upto = lastSeq();
    if (upto <= _acked) return;
    _acked = upto;
    _st->persistAcked(_acked);
    while (_nseg > 0 && !(_curOpen && _nseg == 1)) {
      const Seg& s = _seg[0];
      if (s.firstSeq + s.count - 1 > _acked) break;
      _st->remove(s.id);
      removeSeg0();
    }
  }

  // Reads up to `max` stored records with seq >= c.nextSeq, oldest first,
  // including records still in the RAM buffer. Advances the cursor.
  int read(PsLogCursor& c, PsRecord* out, int max) {
    int n = 0;
    for (uint16_t si = 0; si < _nseg && n < max; ++si) {
      const Seg& s = _seg[si];
      const uint32_t lastInSeg = s.firstSeq + s.count - 1;
      if (lastInSeg < c.nextSeq) continue;
      uint32_t idx = c.nextSeq > s.firstSeq ? c.nextSeq - s.firstSeq : 0;
      while (idx < s.count && n < max) {
        PsRecord r;
        if (readAt(s.id, idx, r) && r.seq >= c.nextSeq) {
          out[n++] = r;
          c.nextSeq = r.seq + 1;
        }
        ++idx;
      }
      if (idx >= s.count && c.nextSeq <= lastInSeg) c.nextSeq = lastInSeg + 1;  // skip torn
    }
    for (uint8_t k = 0; k < _nbuf && n < max; ++k) {
      if (_buf[k].seq >= c.nextSeq) {
        out[n++] = _buf[k];
        c.nextSeq = _buf[k].seq + 1;
      }
    }
    return n;
  }

private:
  static const uint8_t kHeadroom = 8;  // room for gap records written during a flush

  struct Seg { uint32_t id; uint32_t firstSeq; uint32_t count; };

  void reserve() {
    if (_next > _reserved) {
      _reserved = _next + kSeqReserve - 1;
      _st->persistSeqReservation(_reserved);
    }
  }

  bool readAt(uint32_t id, uint32_t idx, PsRecord& r) {
    uint8_t b[PS_REC_BYTES];
    if (!_st->read(id, (size_t)idx * PS_REC_BYTES, b, PS_REC_BYTES)) return false;
    return psRecordUnpack(b, r);
  }

  void removeSeg0() {
    for (uint16_t k = 1; k < _nseg; ++k) _seg[k - 1] = _seg[k];
    _nseg--;
  }

  bool openSegment(uint32_t nowMs) {
    while (_nseg >= _maxSeg) {
      if (!dropOldest(nowMs, false)) return false;
    }
    Seg& s = _seg[_nseg++];
    s.id = _curId++;
    s.firstSeq = 0;
    s.count = 0;
    _curOpen = true;
    return true;
  }

  // Deletes the oldest closed segment. A gap record is appended if any of
  // its records were unacknowledged.
  bool dropOldest(uint32_t nowMs, bool allowCurrent) {
    if (_nseg == 0) return false;
    if (_curOpen && _nseg == 1 && !allowCurrent) return false;
    if (_curOpen && _nseg == 1 && _seg[0].count == 0) return false;
    const Seg s = _seg[0];
    _st->remove(s.id);
    removeSeg0();
    if (_nseg == 0) _curOpen = false;
    const uint32_t last = s.firstSeq + s.count - 1;
    uint32_t lost = 0;
    if (s.count > 0 && last > _acked) {
      lost = (s.firstSeq > _acked) ? s.count : last - _acked;
    }
    if (lost > 0 && _nbuf < kBufRecords + kHeadroom) {
      _droppedSinceBoot += lost;
      PsRecord g;
      g.type = PsRecType::GAP;
      g.reason = PsGapReason::LOG_FULL;
      g.lost = lost;
      g.ms = nowMs;
      g.boot = _boot;
      g.seq = _next++;
      reserve();
      _buf[_nbuf++] = g;
      if (_listener) _listener->onLogged(g);
    }
    return true;
  }

  PsLogStorage* _st = nullptr;
  PsLogListener* _listener = nullptr;
  uint32_t _boot = 0;
  uint32_t _perSeg = 512;
  uint16_t _maxSeg = 2;
  uint32_t _acked = 0, _next = 1, _reserved = 0, _curId = 1;
  uint32_t _lastFlushMs = 0, _droppedSinceBoot = 0;
  Seg _seg[kMaxSegments];
  uint16_t _nseg = 0;
  bool _curOpen = false;
  PsRecord _buf[kBufRecords + kHeadroom];
  uint8_t _nbuf = 0;
};

#endif  // PS_RINGLOG_H
