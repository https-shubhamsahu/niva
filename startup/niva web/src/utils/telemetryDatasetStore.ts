export type TelemetrySource = 'usb' | 'ws' | 'sim';

export type DiseaseLabel =
  | 'Unknown'
  | 'Normal'
  | 'Parkinson'
  | 'Stroke'
  | 'Neuropathy'
  | 'Foot Drop'
  | 'Ataxia';

export type TelemetryMode = 'live' | 'simulation';

export interface TelemetrySample {
  id?: number;
  timestampMs: number;
  source: TelemetrySource;
  sessionId: string;
  trialId: string;
  diseaseLabel: DiseaseLabel;
  mode: TelemetryMode;
  heel: number;
  inner: number;
  outer: number;
  toe: number;
  impact: number;
  pitch: number;
  roll: number;
  accZ: number;
}

const DB_NAME = 'gaitguard-nexus-datasets';
const DB_VERSION = 2;
const STORE_NAME = 'esp32_samples';

let dbPromise: Promise<IDBDatabase> | null = null;

const openDatabase = (): Promise<IDBDatabase> => {
  if (dbPromise) return dbPromise;

  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, DB_VERSION);

    request.onupgradeneeded = () => {
      const db = request.result;
      const store = db.objectStoreNames.contains(STORE_NAME)
        ? request.transaction?.objectStore(STORE_NAME)
        : db.createObjectStore(STORE_NAME, { keyPath: 'id', autoIncrement: true });

      if (!store) return;

      if (!store.indexNames.contains('timestampMs')) {
        store.createIndex('timestampMs', 'timestampMs', { unique: false });
      }
      if (!store.indexNames.contains('source')) {
        store.createIndex('source', 'source', { unique: false });
      }
      if (!store.indexNames.contains('sessionId')) {
        store.createIndex('sessionId', 'sessionId', { unique: false });
      }
      if (!store.indexNames.contains('diseaseLabel')) {
        store.createIndex('diseaseLabel', 'diseaseLabel', { unique: false });
      }
      if (!store.indexNames.contains('mode')) {
        store.createIndex('mode', 'mode', { unique: false });
      }
    };

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error('Failed to open dataset database.'));
  });

  return dbPromise;
};

export const insertTelemetrySamples = async (samples: TelemetrySample[]): Promise<void> => {
  if (samples.length === 0) return;

  const db = await openDatabase();
  const normalizedSamples = samples.map((sample) => ({
    ...sample,
    sessionId: sample.sessionId?.trim() || 'session-unassigned',
    trialId: sample.trialId?.trim() || 'trial-001',
    diseaseLabel: sample.diseaseLabel || 'Unknown',
    mode: sample.mode || 'live',
  }));

  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);

    for (const sample of normalizedSamples) {
      store.add(sample);
    }

    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error ?? new Error('Failed to insert telemetry samples.'));
  });
};

export const getTelemetrySampleCount = async (): Promise<number> => {
  const db = await openDatabase();

  return new Promise<number>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const request = store.count();

    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error ?? new Error('Failed to count telemetry samples.'));
  });
};

export const getLatestTelemetrySamples = async (limit: number): Promise<TelemetrySample[]> => {
  const db = await openDatabase();

  return new Promise<TelemetrySample[]>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readonly');
    const store = tx.objectStore(STORE_NAME);
    const index = store.index('timestampMs');
    const direction: IDBCursorDirection = 'prev';
    const request = index.openCursor(null, direction);

    const rows: TelemetrySample[] = [];

    request.onsuccess = () => {
      const cursor = request.result;
      if (!cursor || rows.length >= limit) {
        resolve(rows.reverse());
        return;
      }

      rows.push(cursor.value as TelemetrySample);
      cursor.continue();
    };

    request.onerror = () => reject(request.error ?? new Error('Failed to read telemetry samples.'));
  });
};

export const clearTelemetryDataset = async (): Promise<void> => {
  const db = await openDatabase();

  await new Promise<void>((resolve, reject) => {
    const tx = db.transaction(STORE_NAME, 'readwrite');
    const store = tx.objectStore(STORE_NAME);
    store.clear();

    tx.oncomplete = () => resolve();
    tx.onerror = () => reject(tx.error ?? new Error('Failed to clear telemetry dataset.'));
  });
};

const escapeCsv = (value: string | number) => {
  const text = String(value);
  if (text.includes(',') || text.includes('"') || text.includes('\n')) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
};

export const exportTelemetryCsv = async (): Promise<string> => {
  const rows = await getLatestTelemetrySamples(1000000);

  const header = [
    'timestampMs',
    'source',
    'sessionId',
    'trialId',
    'diseaseLabel',
    'mode',
    'heel',
    'inner',
    'outer',
    'toe',
    'impact',
    'pitch',
    'roll',
    'accZ',
  ];

  const lines = [header.join(',')];

  for (const row of rows) {
    lines.push([
      escapeCsv(row.timestampMs),
      escapeCsv(row.source),
      escapeCsv(row.sessionId || 'session-unassigned'),
      escapeCsv(row.trialId || 'trial-001'),
      escapeCsv(row.diseaseLabel || 'Unknown'),
      escapeCsv(row.mode || 'live'),
      escapeCsv(row.heel),
      escapeCsv(row.inner),
      escapeCsv(row.outer),
      escapeCsv(row.toe),
      escapeCsv(row.impact),
      escapeCsv(row.pitch),
      escapeCsv(row.roll),
      escapeCsv(row.accZ),
    ].join(','));
  }

  return lines.join('\n');
};
