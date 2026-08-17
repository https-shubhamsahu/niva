# Simulation Logic

Covers `src/utils/simulationEngine.ts` and how `src/pages/MainDashboard.tsx` drives it. This is the "no hardware needed" path — it lets the dashboard demo six gait conditions with plausible, explainable pressure traces instead of random noise.

## 1. What it produces

`generateGaitFrame(mode, timeMs)` returns one synthetic sensor frame:

```ts
interface GaitFrame {
  heel: number;
  mt1: number;            // 1st metatarsal (inner forefoot)
  mt5: number;             // 5th metatarsal (outer forefoot)
  toe: number;
  impact: number;
  stanceRatio: number;
  imuRollVariance: number;
  explanation: string;     // plain-English rationale, shown in the UI banner
}
```

This is the same shape of data a real ESP32 packet would produce, so downstream code (the `BiomechanicsEngine`) can't tell the difference between live and simulated frames.

## 2. The six modes and their signature values

`GaitMode = 'Normal' | 'Parkinson' | 'Stroke' | 'Neuropathy' | 'Foot Drop' | 'Ataxia'`

Each mode sets a **base value** for every sensor plus a walking-cycle duration (`cycleTime`), chosen to be clinically suggestive rather than arbitrary:

| Mode | Cycle (ms) | Heel | MT1 | MT5 | Toe | Impact | Stance ratio | Roll variance | Rationale (`getDiseaseExplanation`) |
|---|---|---|---|---|---|---|---|---|---|
| Normal | 1000 | 80 | 60 | 55 | 70 | 80 | 0.60 | 0.5 | Balanced pressure progression and stable temporal parameters. |
| Parkinson | 1200 | 30 | 50 | 48 | 40 | 20 | 0.75 | 0.3 | Low heel impact + longer stance duration = shuffling gait. |
| Stroke | 1000 | 60 | 90 | 20 | 75 | 60 | 0.65 | 1.2 | Medial-lateral asymmetry (MT1 vs MT5) = hemiplegic imbalance. |
| Neuropathy | 1000 | 35 | 95 | 85 | 50 | 50 | 0.60 | 0.6 | Sustained forefoot pressure = diabetic ulceration risk. |
| Foot Drop | 1100 | 5 | 70 | 60 | 80 | 90 | 0.55 | 0.8 | Near-absent heel strike + forefoot slap = dorsiflexion weakness. |
| Ataxia | 1300 | random 40–80 | random 30–90 | random 20–70 | random 30–80 | random 40–90 | random 0.50–0.80 | random 2.0–5.0 | High randomness + high IMU roll variance = cerebellar ataxia. |

Ataxia is the only mode that re-randomizes its base values on every call (`Math.random()` per field) rather than using fixed constants — that's what makes its trace look erratic instead of just noisy-but-periodic like the others.

## 3. Turning a base value into a walking waveform

A single `timeMs` value is turned into a repeating gait cycle:

```ts
const phase = (timeMs % cycleTime) / cycleTime;   // 0 → 1, one value per stride
```

Two sine-based scale factors shape *when in the stride* each zone peaks:

```ts
const heelScale = mode === 'Foot Drop' ? 0.2 : Math.max(0, Math.sin(phase * Math.PI));
const toeScale  = Math.max(0, Math.sin((phase - 0.5) * Math.PI));
```

- `heelScale` peaks at `phase ≈ 0.5` (heel strike happens partway through the visible sine hump) and is clamped to never go negative (`Math.max(0, ...)`), so heel pressure is zero for roughly half the cycle (the swing phase).
- `toeScale` is the same sine shape but shifted half a cycle later, so toe-off pressure peaks opposite the heel.
- **Foot Drop is special-cased**: `heelScale` is hardcoded to a flat `0.2` instead of the sine wave, because a foot-drop gait doesn't have a normal heel-strike rhythm to model — the forefoot slaps down almost immediately instead. Foot Drop also reuses `heelScale` (not `toeScale`) to drive its forefoot pressure (`mtScale = mode === 'Foot Drop' ? heelScale : toeScale`), producing the "slap" timing described in its explanation.

Each output value blends 30% base value + 70% scaled value, then adds noise:

```ts
const applyNoise = (val, amp = 3) => val + (Math.random() - 0.5) * amp;
const heel = applyNoise(baseHeel * (0.3 + 0.7 * heelScale));
```

The `0.3 + 0.7 * scale` blend means a sensor is never fully at zero even at the "quiet" point in the cycle — it dips to 30% of its base value, never all the way off. `impact`, `stanceRatio`, and `imuRollVariance` get noise applied directly to their base value (no sine shaping — they're treated as roughly constant per-stride, just jittered).

All four pressure outputs are clamped to `[0, 100]` before being returned; `impact`/`stanceRatio`/`imuRollVariance` are not clamped.

## 4. How MainDashboard drives the simulator

The simulation isn't just "call `generateGaitFrame` once" — it's an interval-driven loop in `MainDashboard.tsx`:

```ts
const interval = setInterval(() => {
  if (isSimulating) {
    // ...demo-mode auto-cycle logic (see below)...
    const frame = generateGaitFrame(simMode, Date.now());
    const simPitch = (Math.random() - 0.5) * frame.imuRollVariance * 10;
    const simRoll  = (Math.random() - 0.5) * frame.imuRollVariance * 20;

    const simulationPacket: RawSensorPacket = {
      heel: frame.heel, inner: frame.mt1, outer: frame.mt5, toe: frame.toe,
      impact: frame.impact, pitch: simPitch, roll: simRoll, accZ: 9.81,
      timestampMs: Date.now(),
    };

    applyBiomechanicsPacket(simulationPacket);         // feeds the SAME engine live data uses
    enqueueDatasetSample(simulationPacket, 'sim', 'simulation', simModeRef.current);
    setSimExplanation(frame.explanation);
  }
}, 100); // 10 Hz
```

Key details:

- **10 Hz tick** (`100ms` interval) — this is the simulator's sample rate, independent of `cycleTime` (which just controls how many ticks make up one stride).
- **`imuRollVariance` is reused, not passed through directly.** The frame's `imuRollVariance` scales two *independently randomized* pitch/roll values (`×10` for pitch, `×20` for roll) rather than being written straight into the packet — this is a second layer of randomness on top of the one already inside `generateGaitFrame`.
- **`accZ` is hardcoded to `9.81`** (gravity, i.e. "foot roughly level") for every simulated frame — there is no simulated vertical acceleration signal.
- **Simulated frames go through the exact same `BiomechanicsEngine.process()` call as live packets** (`applyBiomechanicsPacket`), and are tagged and queued into the same IndexedDB dataset store with `source: 'sim'`, `mode: 'simulation'`, and the current `GaitMode` as the `diseaseLabel` — see `BACKEND_LOGIC.md`.
- **Explanation banner**: `frame.explanation` is written to `simExplanation` on every tick, which is what renders the "○ Gait Detected — <reasoning>" banner in the UI.

### Demo mode (auto-cycle)

"Run Clinical Demo" (`isDemoMode`, toggled from `DiseaseSelector.tsx`) locks manual mode selection and instead auto-advances through all six modes on a fixed clock, so someone can watch every condition hands-free:

```ts
let demoTimer = 0;
const modes: GaitMode[] = ['Normal', 'Parkinson', 'Stroke', 'Neuropathy', 'Foot Drop', 'Ataxia'];

// inside the same 100ms interval:
if (isDemoMode) {
  demoTimer += 100;
  if (demoTimer >= 8000) {                 // every 8 seconds
    setSimMode(prev => modes[(modes.indexOf(prev) + 1) % modes.length]);
    demoTimer = 0;
  }
}
```

- `demoTimer` is a plain closure variable reset each time the effect re-runs (i.e. whenever `isDemoMode`/`isSimulating`/`simMode` etc. change), **not** persisted across renders — so toggling demo mode off and back on restarts the 8-second countdown from zero.
- Mode order is fixed and always advances forward, wrapping from `Ataxia` back to `Normal`.
- While `isDemoMode` is on, `DiseaseSelector` disables manual chip selection (`onSelect` is a no-op) except visually showing the currently active mode.

### What happens when neither live nor simulated data is flowing

The same interval has a fallback branch: if not simulating and not connected (serial or WebSocket), it pushes zeroed points into the sway/impact chart buffers every tick so the charts visibly settle back to baseline rather than freezing on stale data.
