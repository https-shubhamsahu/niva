# GaitGuard Nexus: Algorithm and Data Walkthrough

## 1) Data Contract (Input Packet)

All pipeline logic is built around one packet shape:

- heel
- inner
- outer
- toe
- impact
- pitch
- roll
- accZ
- timestampMs

Primary type definitions:

- src/utils/biomechanicsEngine.ts

Transport-specific parsing:

- USB CSV parsing: src/utils/esp32Telemetry.ts
- WiFi JSON parsing and reconnect: src/hooks/useSensorData.ts

## 2) End-to-End Processing Path

Per packet flow:

1. transport ingest
2. packet normalization and validation
3. biomechanics engine processing
4. metrics to dashboard state
5. dataset persistence
6. export or backend upload

Coordinator file:

- src/pages/MainDashboard.tsx

## 3) Algorithm Map by File

### A) Transport and Parsing

File: src/utils/esp32Telemetry.ts

- CSV line parser from ESP32 serial stream
- filters firmware non-data lines
- numeric validation and frame construction

File: src/hooks/useSensorData.ts

- WebSocket ingest from ESP32 WiFi endpoint
- JSON parse with malformed-frame handling
- automatic reconnect loop

### B) Core Biomechanics Engine

File: src/utils/biomechanicsEngine.ts

Algorithms implemented:

1. Noise filtering
- EMA on heel, inner, outer, toe
- alpha defaults in engine options

2. Pressure normalization
- raw pressure transformed to bounded percent domain
- normalized pressure ratios computed from total pressure

3. Contact detection
- stance versus swing using total pressure threshold

4. Heel strike detection
- impact threshold + heel threshold + heel-rise rule + state transition guard

5. Gait phase classification
- HEEL_STRIKE, MID_STANCE, TOE_OFF, SWING decision rules

6. Center of pressure estimation
- weighted coordinate average of four sensor positions
- normalized x,y output in foot plane

7. Step segmentation and cadence
- step count increments on heel strike events
- cadence computed from heel strike interval

8. Stability and impact scoring
- sway magnitude from pitch and roll
- stability band classification
- stability score from sway plus impact penalty
- impact severity normalization

9. Risk and anomaly detection
- heel-dominant gait trend
- ankle instability and supination risk condition
- high sway instability condition
- ischemic pressure risk integral with decay/growth logic

10. Rolling sample memory
- internal history buffer capped at 50 samples

### C) Visualization Mapping

File: src/pages/MainDashboard.tsx

Mappings from processed metrics:

- filteredPressure -> heatmap and pressure cards
- mlpi -> MLPI card
- gaitPhase -> phase card
- cadenceSpm and stepCount -> cadence and steps cards
- cop -> COP dot and trail
- stabilityScore and stabilityBand -> stability gauge and label
- impactLevel -> impact severity bar
- ischemicIntegralPct and anomalyFlags -> risk panel and alerts

### D) Dataset Storage and Retrieval

File: src/utils/telemetryDatasetStore.ts

Data operations:

- IndexedDB initialization
- batched sample inserts
- sample count
- latest sample read
- clear dataset
- CSV export generation

Data schema per stored row:

- timestampMs, source, sessionId, trialId, diseaseLabel, mode, heel, inner, outer, toe, impact, pitch, roll, accZ

### E) Backend Research Upload

File: src/utils/researchUpload.ts

Upload algorithm:

- read upload endpoint and token from environment
- build multipart payload with CSV and metadata fields
- post to backend endpoint
- parse response and expose status and location

Runtime trigger:

- one-click upload action in src/pages/MainDashboard.tsx

### F) Simulation Data (for controlled demo)

File: src/utils/simulationEngine.ts

Algorithms:

- synthetic gait frame generation by mode
- phase progression and temporal modulation
- controlled noise injection for demonstration

Consumption point:

- src/pages/MainDashboard.tsx in simulation mode

## 4) Exact File-to-Algorithm Index

Use this section during judging to answer where each algorithm lives.

1. EMA filtering
- src/utils/biomechanicsEngine.ts

2. Pressure normalization
- src/utils/biomechanicsEngine.ts

3. Contact detection
- src/utils/biomechanicsEngine.ts

4. Heel strike detection
- src/utils/biomechanicsEngine.ts

5. Gait phase detection
- src/utils/biomechanicsEngine.ts

6. COP estimation
- src/utils/biomechanicsEngine.ts

7. Cadence and step segmentation
- src/utils/biomechanicsEngine.ts

8. Stability and impact scoring
- src/utils/biomechanicsEngine.ts

9. Anomaly detection rules
- src/utils/biomechanicsEngine.ts

10. USB data parse
- src/utils/esp32Telemetry.ts

11. WiFi stream parse and reconnect
- src/hooks/useSensorData.ts

12. Visualization binding of metrics
- src/pages/MainDashboard.tsx

13. Dataset persistence and CSV export
- src/utils/telemetryDatasetStore.ts

14. One-click backend upload
- src/utils/researchUpload.ts
- src/pages/MainDashboard.tsx

15. Synthetic test stream
- src/utils/simulationEngine.ts

## 5) Data Lifecycle (One Sentence)

ESP32 packet -> parsing -> biomechanics engine -> dashboard metrics -> local dataset store -> CSV export or backend upload.

## 6) Disease Dataset Labeling Rules

How class labels are assigned in stored data:

1. Live stream packets (USB/WiFi)
- `diseaseLabel` is taken from operator selection in the dataset panel.
- `mode` is stored as `live`.

2. Simulation packets
- `diseaseLabel` is automatically set from the active simulation mode (`Normal`, `Parkinson`, `Stroke`, `Neuropathy`, `Foot Drop`, `Ataxia`).
- `mode` is stored as `simulation`.

3. Session grouping
- `sessionId` groups one acquisition session.
- `trialId` separates repeated trials inside a session.

Primary implementation:

- src/pages/MainDashboard.tsx
- src/utils/telemetryDatasetStore.ts
- src/utils/simulationEngine.ts

## 7) References and Clinical Basis

The implementation uses deterministic heuristic rules inspired by plantar pressure and gait analysis literature plus insole prior art. Core references used in project framing:

1. Abbott et al., The Lancet Digital Health (2019)
- Digital foot monitoring and ulcer-prevention context for high-risk diabetic feet.

2. Orpyx insole pressure-monitoring patents
- US10004428
- US11781930

3. General gait biomechanics conventions
- phase segmentation (heel-strike, mid-stance, toe-off, swing)
- cadence from heel-strike intervals
- center-of-pressure trajectory from weighted plantar sensors

Reference-to-code mapping:

- Time-pressure risk integral and alert threshold logic: src/utils/biomechanicsEngine.ts
- Phase and cadence logic: src/utils/biomechanicsEngine.ts
- COP computation and trail: src/utils/biomechanicsEngine.ts and src/pages/MainDashboard.tsx
- Dataset-level disease/session labeling for research export: src/pages/MainDashboard.tsx and src/utils/telemetryDatasetStore.ts
Primary implementation files referenced in walkthrough

biomechanicsEngine.ts
esp32Telemetry.ts
useSensorData.ts
MainDashboard.tsx
telemetryDatasetStore.ts
researchUpload.ts
simulationEngine.ts