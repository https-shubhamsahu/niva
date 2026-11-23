export interface Esp32TelemetryFrame {
  heelRaw: number;
  mt1Raw: number;
  mt5Raw: number;
  toeRaw: number;
  piezoPeak: number;
  pitchDeg: number;
  rollDeg: number;
  accZ: number;
  timestampMs: number;
}

export interface NormalizedPressures {
  heel: number;
  mt1: number;
  mt5: number;
  toe: number;
}

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

// Firmware lines that should not be parsed as telemetry.
const NON_DATA_PREFIXES = ['CALIBRATING', 'SYSTEM_', 'H,I,O,T'];

export const parseEsp32CsvLine = (line: string): Esp32TelemetryFrame | null => {
  const trimmed = line.trim();
  if (!trimmed) return null;

  const isNonData = NON_DATA_PREFIXES.some((prefix) => trimmed.startsWith(prefix));
  if (isNonData) return null;

  const parts = trimmed.split(',').map((part) => Number(part.trim()));
  if (parts.length < 8 || parts.some((value) => Number.isNaN(value))) {
    return null;
  }

  const [heelRaw, mt1Raw, mt5Raw, toeRaw, piezoPeak, pitchDeg, rollDeg, accZ] = parts;

  return {
    heelRaw,
    mt1Raw,
    mt5Raw,
    toeRaw,
    piezoPeak,
    pitchDeg,
    rollDeg,
    accZ,
    timestampMs: Date.now(),
  };
};

export const normalizePressures = (
  frame: Esp32TelemetryFrame,
  adcMax: number = 4095
): NormalizedPressures => {
  const toPercent = (raw: number) => clamp((raw / adcMax) * 100, 0, 100);

  return {
    heel: toPercent(frame.heelRaw),
    mt1: toPercent(frame.mt1Raw),
    mt5: toPercent(frame.mt5Raw),
    toe: toPercent(frame.toeRaw),
  };
};

export const computeStabilityFromFrame = (frame: Esp32TelemetryFrame): number => {
  // Deterministic score: high sway + high impact reduces stability.
  const swayMagnitude = Math.abs(frame.rollDeg) + Math.abs(frame.pitchDeg) * 0.6;
  const impactPenalty = Math.min(35, frame.piezoPeak / 20);
  const rawScore = 100 - (swayMagnitude * 2.2 + impactPenalty);
  return Math.round(clamp(rawScore, 0, 100));
};
