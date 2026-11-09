export type ContactState = 'STANCE' | 'SWING';
export type GaitPhase = 'HEEL_STRIKE' | 'MID_STANCE' | 'TOE_OFF' | 'SWING';
export type StabilityBand = 'stable' | 'moderate' | 'unstable';

/**
 * Full scale of the ESP32's 12-bit ADC. The firmware (`niva_hardware.ino`) sends
 * each FSR channel as ADC counts above its boot tare, 0-4095, and the simulator
 * packets use the same unit, so every pressure input is divided by this one constant.
 */
export const ADC_FULL_SCALE_COUNTS = 4095;

/** Pressure fields are ADC counts above tare; `impact` is raw piezo counts; `timestampMs` is receive time. */
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
  isCalibrated: boolean;
  /** True only when the app captured a clean no-load baseline; false means the device's own zero is used. */
  tareApplied: boolean;
  /** Per channel, percent of ADC full scale after tare and smoothing. Uncalibrated: not force or pressure units. */
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
  /** Estimate: 2 x detected heel strikes (one insole sees one per stride). */
  stepCount: number;
  /** Estimate in steps/min: 120 / time between heel strikes of this foot. */
  cadenceSpm: number;
  stancePct: number;
  swingPct: number;
  stabilityMagnitude: number;
  stabilityBand: StabilityBand;
  stabilityScore: number;
  impactLevel: number;
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
  pressureDeadband: number;
  angleDeadband: number;
  calibrationSamples: number;
  calibrationMaxSamples: number;
  calibrationRange: number;
  calibrationTotalCeiling: number;
  calibrationMotionCeiling: number;
  calibrationImpactCeiling: number;
}

const SENSOR_COORDS = {
  heel: { x: 0, y: 0 },
  inner: { x: 0.3, y: 0.5 },
  outer: { x: 0.7, y: 0.5 },
  toe: { x: 0.5, y: 1 },
};

const clamp = (value: number, min: number, max: number) => Math.min(max, Math.max(min, value));

// ADC counts above tare -> percent of ADC full scale. One linear mapping for every
// input: units are never guessed from the magnitude of the value.
const normalizeRawPressureInput = (value: number) => {
  if (!Number.isFinite(value)) return 0;
  return clamp((value / ADC_FULL_SCALE_COUNTS) * 100, 0, 100);
};

const ema = (current: number, previous: number, alpha: number) => {
  return alpha * current + (1 - alpha) * previous;
};

const deadband = (value: number, threshold: number) => {
  return Math.abs(value) < threshold ? 0 : value;
};

export class BiomechanicsEngine {
  private options: BiomechanicsEngineOptions;
  private filtered = { heel: 0, inner: 0, outer: 0, toe: 0 };
  private baselinePressure = { heel: 0, inner: 0, outer: 0, toe: 0 };
  private baselinePitch = 0;
  private baselineRoll = 0;
  private isCalibrated = false;
  private tareApplied = false;
  private calibrationCount = 0;
  private calibrationAccum = { heel: 0, inner: 0, outer: 0, toe: 0, total: 0, impact: 0, pitch: 0, roll: 0 };
  private calibrationTotalMin = Number.POSITIVE_INFINITY;
  private calibrationTotalMax = 0;
  private calibrationMotionMax = 0;
  private lastContact = false;
  private lastHeel = 0;
  private lastHeelStrikeAt: number | null = null;
  private strideCount = 0;
  private cadenceSpm = 0;
  private stanceStartMs = 0;
  private swingStartMs = 0;
  private lastStanceMs = 600;
  private lastSwingMs = 400;
  private heelDominantStreak = 0;
  private history: ProcessedBiomechanicsMetrics[] = [];

  constructor(overrides?: Partial<BiomechanicsEngineOptions>) {
    this.options = {
      alpha: 0.1,
      contactThreshold: 45,
      impactThreshold: 200,
      heelThreshold: 80,
      maxImpact: 800,
      bufferSize: 50,
      pressureDeadband: 2.5,
      angleDeadband: 0.8,
      calibrationSamples: 30,
      calibrationMaxSamples: 60,
      calibrationRange: 8,
      // Sum of the four channels in % of full scale. The firmware already subtracted its
      // own boot tare, so an unloaded insole reads close to 0; 8 allows ADC noise but
      // rejects a foot standing on it.
      calibrationTotalCeiling: 8,
      calibrationMotionCeiling: 7,
      calibrationImpactCeiling: 60,
      ...overrides,
    };
  }

  reset() {
    this.filtered = { heel: 0, inner: 0, outer: 0, toe: 0 };
    this.baselinePressure = { heel: 0, inner: 0, outer: 0, toe: 0 };
    this.baselinePitch = 0;
    this.baselineRoll = 0;
    this.isCalibrated = false;
    this.tareApplied = false;
    this.calibrationCount = 0;
    this.calibrationAccum = { heel: 0, inner: 0, outer: 0, toe: 0, total: 0, impact: 0, pitch: 0, roll: 0 };
    this.calibrationTotalMin = Number.POSITIVE_INFINITY;
    this.calibrationTotalMax = 0;
    this.calibrationMotionMax = 0;
    this.lastContact = false;
    this.lastHeel = 0;
    this.lastHeelStrikeAt = null;
    this.strideCount = 0;
    this.cadenceSpm = 0;
    this.stanceStartMs = 0;
    this.swingStartMs = 0;
    this.lastStanceMs = 600;
    this.lastSwingMs = 400;
    this.heelDominantStreak = 0;
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
    const rawInput = {
      heel: normalizeRawPressureInput(packet.heel),
      inner: normalizeRawPressureInput(packet.inner),
      outer: normalizeRawPressureInput(packet.outer),
      toe: normalizeRawPressureInput(packet.toe),
    };

    if (!this.isCalibrated) {
      const rawTotal = rawInput.heel + rawInput.inner + rawInput.outer + rawInput.toe;
      const rawMotion = Math.sqrt(packet.pitch * packet.pitch + packet.roll * packet.roll);

      this.calibrationCount += 1;
      this.calibrationAccum.heel += rawInput.heel;
      this.calibrationAccum.inner += rawInput.inner;
      this.calibrationAccum.outer += rawInput.outer;
      this.calibrationAccum.toe += rawInput.toe;
      this.calibrationAccum.total += rawTotal;
      this.calibrationAccum.impact += packet.impact;
      this.calibrationAccum.pitch += packet.pitch;
      this.calibrationAccum.roll += packet.roll;
      this.calibrationTotalMin = Math.min(this.calibrationTotalMin, rawTotal);
      this.calibrationTotalMax = Math.max(this.calibrationTotalMax, rawTotal);
      this.calibrationMotionMax = Math.max(this.calibrationMotionMax, rawMotion);

      if (this.calibrationCount >= this.options.calibrationSamples) {
        const meanTotal = this.calibrationAccum.total / this.calibrationCount;
        const meanImpact = this.calibrationAccum.impact / this.calibrationCount;
        const stableRange = this.calibrationTotalMax - this.calibrationTotalMin;

        const noLoadStable =
          stableRange <= this.options.calibrationRange &&
          meanTotal <= this.options.calibrationTotalCeiling &&
          this.calibrationMotionMax <= this.options.calibrationMotionCeiling &&
          meanImpact <= this.options.calibrationImpactCeiling;

        if (noLoadStable) {
          this.baselinePressure = {
            heel: this.calibrationAccum.heel / this.calibrationCount,
            inner: this.calibrationAccum.inner / this.calibrationCount,
            outer: this.calibrationAccum.outer / this.calibrationCount,
            toe: this.calibrationAccum.toe / this.calibrationCount,
          };
          this.baselinePitch = this.calibrationAccum.pitch / this.calibrationCount;
          this.baselineRoll = this.calibrationAccum.roll / this.calibrationCount;
          this.isCalibrated = true;
          this.tareApplied = true;
        } else if (this.calibrationCount >= this.options.calibrationMaxSamples) {
          // No clean no-load window (insole loaded or moving): do not tare a loaded foot to
          // zero. Keep the device's own zero and report `tareApplied: false`.
          this.isCalibrated = true;
        }
      }
    }

    const input = this.isCalibrated
      ? {
          heel: deadband(Math.max(0, rawInput.heel - this.baselinePressure.heel), this.options.pressureDeadband),
          inner: deadband(Math.max(0, rawInput.inner - this.baselinePressure.inner), this.options.pressureDeadband),
          outer: deadband(Math.max(0, rawInput.outer - this.baselinePressure.outer), this.options.pressureDeadband),
          toe: deadband(Math.max(0, rawInput.toe - this.baselinePressure.toe), this.options.pressureDeadband),
        }
      : {
          heel: 0,
          inner: 0,
          outer: 0,
          toe: 0,
        };

    const correctedPitch = deadband(packet.pitch - this.baselinePitch, this.options.angleDeadband);
    const correctedRoll = deadband(packet.roll - this.baselineRoll, this.options.angleDeadband);

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

    // Heel strike is an impact transient, so it is gated on the unsmoothed (deadbanded)
    // reading, as in biomechanics_engine.dart. Gating on the EMA-filtered heel could never
    // fire: the filter only passes the threshold after contact has already flipped.
    const heelRise = input.heel - this.lastHeel;
    const heelStrikeDetected =
      packet.impact > this.options.impactThreshold &&
      input.heel > this.options.heelThreshold &&
      heelRise > 8 &&
      !this.lastContact;

    // One insole sees one heel strike per stride, i.e. per two steps. Steps and cadence
    // are therefore estimates: 2 steps per detected stride.
    if (heelStrikeDetected) {
      this.strideCount += 1;
      if (this.lastHeelStrikeAt !== null) {
        const strideIntervalSec = (packet.timestampMs - this.lastHeelStrikeAt) / 1000;
        if (strideIntervalSec > 0.4 && strideIntervalSec < 3) {
          this.cadenceSpm = 120 / strideIntervalSec;
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

    const stabilityMagnitude = Math.sqrt(correctedPitch * correctedPitch + correctedRoll * correctedRoll);
    const stabilityBand: StabilityBand = stabilityMagnitude < 3 ? 'stable' : stabilityMagnitude < 6 ? 'moderate' : 'unstable';

    const impactLevel = clamp(packet.impact / this.options.maxImpact, 0, 1);
    const stabilityScore = Math.round(clamp(100 - stabilityMagnitude * 9 - impactLevel * 30, 0, 100));
    const mlpi = Math.abs(this.filtered.inner - this.filtered.outer);

    if (normalizedPressure.heel > 0.7) {
      this.heelDominantStreak += 1;
    } else {
      this.heelDominantStreak = 0;
    }

    // Plain description of the raw distribution, not a clinical finding. The former sway
    // "instability", supination and ischemic rules were removed: nothing validates them,
    // and normal walking pitch tripped them.
    const anomalyFlags: string[] = [];

    if (this.heelDominantStreak >= 5) {
      anomalyFlags.push('Heel sensor carrying over 70% of measured load');
    }

    this.lastHeel = input.heel;

    const metrics: ProcessedBiomechanicsMetrics = {
      timestampMs: packet.timestampMs,
      isCalibrated: this.isCalibrated,
      tareApplied: this.tareApplied,
      filteredPressure: { ...this.filtered },
      normalizedPressure,
      totalPressure,
      contactState,
      heelStrikeDetected,
      gaitPhase,
      cop,
      mlpi,
      stepCount: this.strideCount * 2,
      cadenceSpm: this.cadenceSpm,
      stancePct,
      swingPct,
      stabilityMagnitude,
      stabilityBand,
      stabilityScore,
      impactLevel,
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
