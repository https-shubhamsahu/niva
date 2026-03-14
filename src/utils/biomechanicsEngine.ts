export type ContactState = 'STANCE' | 'SWING';
export type GaitPhase = 'HEEL_STRIKE' | 'MID_STANCE' | 'TOE_OFF' | 'SWING';
export type StabilityBand = 'stable' | 'moderate' | 'unstable';

export interface RawSensorPacket {
  heel: number;
  inner: number;
  outer: number;
  toe: number;
  impact: number;
  pitch: number;
  roll: number;
  accZ: number;
  timestampMs: number;
}

export interface CopPoint {
  x: number;
  y: number;
}

export interface ProcessedBiomechanicsMetrics {
  timestampMs: number;
  filteredPressure: {
    heel: number;
    inner: number;
    outer: number;
    toe: number;
  };
  normalizedPressure: {
    heel: number;
    inner: number;
    outer: number;
    toe: number;
  };
  totalPressure: number;
  contactState: ContactState;
  heelStrikeDetected: boolean;
  gaitPhase: GaitPhase;
  cop: CopPoint;
  mlpi: number;
  stepCount: number;
  cadenceSpm: number;
  stancePct: number;
  swingPct: number;
  stabilityMagnitude: number;
  stabilityBand: StabilityBand;
  stabilityScore: number;
  impactLevel: number;
  ischemicIntegralPct: number;
  anomalyFlags: string[];
  bufferLength: number;
}

interface BiomechanicsEngineOptions {
  alpha: number;
  contactThreshold: number;
  impactThreshold: number;
  heelThreshold: number;
  maxImpact: number;
  bufferSize: number;
  staticSwayThreshold: number;
}

const SENSOR_COORDS = {
  heel: { x: 0, y: 0 },
  inner: { x: 0.3, y: 0.5 },
  outer: { x: 0.7, y: 0.5 },
  toe: { x: 0.5, y: 1 },
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

const normalizeRawPressureInput = (value: number) => {
  if (!Number.isFinite(value)) return 0;
  const clamped = Math.max(0, value);
  if (clamped > 100) {
    return clamp((clamped / 4095) * 100, 0, 100);
  }
  return clamp(clamped, 0, 100);
};

const ema = (current: number, previous: number, alpha: number) => {
  return alpha * current + (1 - alpha) * previous;
};

export class BiomechanicsEngine {
  private options: BiomechanicsEngineOptions;
  private filtered = { heel: 0, inner: 0, outer: 0, toe: 0 };
  private lastContact = false;
  private lastHeel = 0;
  private lastHeelStrikeAt: number | null = null;
  private stepCount = 0;
  private cadenceSpm = 0;
  private stanceStartMs = 0;
  private swingStartMs = 0;
  private lastStanceMs = 600;
  private lastSwingMs = 400;
  private heelDominantStreak = 0;
  private ischemicIntegralPct = 0;
  private history: ProcessedBiomechanicsMetrics[] = [];

  constructor(overrides?: Partial<BiomechanicsEngineOptions>) {
    this.options = {
      alpha: 0.15,
      contactThreshold: 40,
      impactThreshold: 200,
      heelThreshold: 80,
      maxImpact: 800,
      bufferSize: 50,
      staticSwayThreshold: 6,
      ...overrides,
    };
  }

  reset() {
    this.filtered = { heel: 0, inner: 0, outer: 0, toe: 0 };
    this.lastContact = false;
    this.lastHeel = 0;
    this.lastHeelStrikeAt = null;
    this.stepCount = 0;
    this.cadenceSpm = 0;
    this.stanceStartMs = 0;
    this.swingStartMs = 0;
    this.lastStanceMs = 600;
    this.lastSwingMs = 400;
    this.heelDominantStreak = 0;
    this.ischemicIntegralPct = 0;
    this.history = [];
  }

  private detectPhase(filtered: { heel: number; inner: number; outer: number; toe: number }, totalPressure: number): GaitPhase {
    if (totalPressure < 20) return 'SWING';
    if (filtered.heel > 80 && filtered.toe < 40) return 'HEEL_STRIKE';
    if (filtered.heel > 50 && filtered.inner > 50 && filtered.outer > 50) return 'MID_STANCE';
    if (filtered.toe > 80 && filtered.heel < 30) return 'TOE_OFF';
    return totalPressure >= this.options.contactThreshold ? 'MID_STANCE' : 'SWING';
  }

  private computeCop(filtered: { heel: number; inner: number; outer: number; toe: number }, totalPressure: number): CopPoint {
    if (totalPressure <= 0) return { x: 0.5, y: 0 };

    const copX = (
      filtered.heel * SENSOR_COORDS.heel.x +
      filtered.inner * SENSOR_COORDS.inner.x +
      filtered.outer * SENSOR_COORDS.outer.x +
      filtered.toe * SENSOR_COORDS.toe.x
    ) / totalPressure;

    const copY = (
      filtered.heel * SENSOR_COORDS.heel.y +
      filtered.inner * SENSOR_COORDS.inner.y +
      filtered.outer * SENSOR_COORDS.outer.y +
      filtered.toe * SENSOR_COORDS.toe.y
    ) / totalPressure;

    return {
      x: clamp(copX, 0, 1),
      y: clamp(copY, 0, 1),
    };
  }

  process(packet: RawSensorPacket): ProcessedBiomechanicsMetrics {
    const input = {
      heel: normalizeRawPressureInput(packet.heel),
      inner: normalizeRawPressureInput(packet.inner),
      outer: normalizeRawPressureInput(packet.outer),
      toe: normalizeRawPressureInput(packet.toe),
    };

    this.filtered = {
      heel: ema(input.heel, this.filtered.heel, this.options.alpha),
      inner: ema(input.inner, this.filtered.inner, this.options.alpha),
      outer: ema(input.outer, this.filtered.outer, this.options.alpha),
      toe: ema(input.toe, this.filtered.toe, this.options.alpha),
    };

    const totalPressure = this.filtered.heel + this.filtered.inner + this.filtered.outer + this.filtered.toe;

    const normalizedPressure = totalPressure > 0
      ? {
          heel: this.filtered.heel / totalPressure,
          inner: this.filtered.inner / totalPressure,
          outer: this.filtered.outer / totalPressure,
          toe: this.filtered.toe / totalPressure,
        }
      : { heel: 0, inner: 0, outer: 0, toe: 0 };

    const contactState: ContactState = totalPressure > this.options.contactThreshold ? 'STANCE' : 'SWING';

    const heelRise = this.filtered.heel - this.lastHeel;
    const heelStrikeDetected =
      packet.impact > this.options.impactThreshold &&
      this.filtered.heel > this.options.heelThreshold &&
      heelRise > 8 &&
      !this.lastContact;

    if (heelStrikeDetected) {
      this.stepCount += 1;
      if (this.lastHeelStrikeAt) {
        const stepIntervalSec = (packet.timestampMs - this.lastHeelStrikeAt) / 1000;
        if (stepIntervalSec > 0.2 && stepIntervalSec < 3) {
          this.cadenceSpm = 60 / stepIntervalSec;
        }
      }
      this.lastHeelStrikeAt = packet.timestampMs;
    }

    if (contactState === 'STANCE' && !this.lastContact) {
      if (this.swingStartMs > 0) this.lastSwingMs = packet.timestampMs - this.swingStartMs;
      this.stanceStartMs = packet.timestampMs;
    }

    if (contactState === 'SWING' && this.lastContact) {
      if (this.stanceStartMs > 0) this.lastStanceMs = packet.timestampMs - this.stanceStartMs;
      this.swingStartMs = packet.timestampMs;
    }

    this.lastContact = contactState === 'STANCE';

    const cycleMs = this.lastStanceMs + this.lastSwingMs;
    const stancePct = cycleMs > 0 ? Math.round((this.lastStanceMs / cycleMs) * 100) : 60;
    const swingPct = 100 - stancePct;

    const gaitPhase = this.detectPhase(this.filtered, totalPressure);
    const cop = this.computeCop(this.filtered, totalPressure);

    const stabilityMagnitude = Math.sqrt(packet.pitch * packet.pitch + packet.roll * packet.roll);
    const stabilityBand: StabilityBand = stabilityMagnitude < 3 ? 'stable' : stabilityMagnitude < 6 ? 'moderate' : 'unstable';

    const impactLevel = clamp(packet.impact / this.options.maxImpact, 0, 1);
    const stabilityScore = Math.round(clamp(100 - stabilityMagnitude * 9 - impactLevel * 30, 0, 100));
    const mlpi = Math.abs(this.filtered.inner - this.filtered.outer);

    if (normalizedPressure.heel > 0.7) {
      this.heelDominantStreak += 1;
    } else {
      this.heelDominantStreak = 0;
    }

    const staticMode = Math.abs(packet.roll) < this.options.staticSwayThreshold && Math.abs(packet.pitch) < this.options.staticSwayThreshold;
    const highMedialLateral = Math.max(this.filtered.inner, this.filtered.outer) > 50;

    if (highMedialLateral && staticMode) {
      this.ischemicIntegralPct = clamp(this.ischemicIntegralPct + 0.35, 0, 100);
    } else {
      this.ischemicIntegralPct = clamp(this.ischemicIntegralPct - 0.08, 0, 100);
    }

    const anomalyFlags: string[] = [];

    if (Math.abs(packet.roll) > 8 && this.filtered.outer > this.filtered.inner) {
      anomalyFlags.push('Ankle instability / supination risk');
    }

    if (this.heelDominantStreak >= 5) {
      anomalyFlags.push('Heel-dominant gait trend');
    }

    if (stabilityBand === 'unstable') {
      anomalyFlags.push('High sway instability');
    }

    if (this.ischemicIntegralPct > 50) {
      anomalyFlags.push('Ischemic pressure risk');
    }

    this.lastHeel = this.filtered.heel;

    const metrics: ProcessedBiomechanicsMetrics = {
      timestampMs: packet.timestampMs,
      filteredPressure: { ...this.filtered },
      normalizedPressure,
      totalPressure,
      contactState,
      heelStrikeDetected,
      gaitPhase,
      cop,
      mlpi,
      stepCount: this.stepCount,
      cadenceSpm: this.cadenceSpm,
      stancePct,
      swingPct,
      stabilityMagnitude,
      stabilityBand,
      stabilityScore,
      impactLevel,
      ischemicIntegralPct: this.ischemicIntegralPct,
      anomalyFlags,
      bufferLength: 0,
    };

    this.history.push(metrics);
    if (this.history.length > this.options.bufferSize) {
      this.history.shift();
    }

    metrics.bufferLength = this.history.length;
    return metrics;
  }
}
