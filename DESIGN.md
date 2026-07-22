# GaitGuard Nexus — UI/UX Design Reference

This documents the app's actual, current design system and screen-by-screen UI/UX as implemented in `lib/`. It reflects the real code, not aspirational design — see `BETTERMENTS.md` for proposed-but-not-built ideas and `CONNECTIVITY_PLAN.md` for the connectivity-specific implementation history.

## Design philosophy

The app is a from-scratch Flutter rebuild of a React/ESP32 gait-monitoring dashboard, redesigned around **Apple Health's visual language** rather than the original web app's indigo/slate theme. Three ideas drive every screen:

1. **Grouped, layered backgrounds.** A muted `systemGroupedBackground`-style page background with white (light) / near-black (dark) cards floating on top — never one flat page surface.
2. **A small set of vivid ring colors, reserved for headline metrics only.** Everything else stays muted (grays, brand indigo) so the three saturated colors stay meaningful at a glance instead of being diluted across the whole UI.
3. **Confident, heavy display type for hero numbers, dropping straight to quiet uppercase micro-labels for context.** No mid-weight type in between — a big stat is either the hero number or a label, never something in-between competing for attention.

Every score and flag in the app traces to an explicit, published threshold in `lib/core/engine/biomechanics_engine.dart` — there is no ML/black-box model. The UI is designed to make that explainability visible (e.g. the Insights screen's "Why These Alerts Fire" card spells out the exact thresholds).

## Design tokens (`lib/theme/app_theme.dart`)

### Color

| Token | Light | Dark | Used for |
|---|---|---|---|
| `stability` | `#FF375F` | same | Outer activity ring, Stability legend/value |
| `cadence` | `#9AE22B` | same | Middle activity ring, Cadence legend/value |
| `safety` | `#00E5FF` | same | Inner activity ring, Impact-safety legend/value |
| `warning` | `#FF9F0A` | same | Warning banners, moderate stability band |
| `danger` | `#FF453A` | same | Errors, disconnect button, unstable band, anomaly labels |
| `success` | `#32D74B` | same | Connected/live pulse dot |
| `brand` | `#415AEE` | same | Primary buttons, active tab, COP marker, segmented-toggle active state (carried over from the original GaitGuard Nexus branding — the one color that isn't Apple Health-native) |
| `background` | `#F2F2F7` | `#000000` | Scaffold background |
| `card` | `#FFFFFF` | `#1C1C1E` | `RoundedCard`, tab bar, all card surfaces |
| `label/secondary` | `#8E8E93` | `#98989F` | Micro-labels, secondary text, inactive tab icons |
| `divider` | `#E5E5EA` | `#2C2C2E` | Tab bar top border |

Ring/status colors are **identical in both themes** — only backgrounds, cards, and secondary text invert. This matches the real Dart source (`AppColors` doesn't branch these on brightness).

### Typography

Google Fonts **Inter**, five-step ramp, no mid-weights:

| Style | Size | Weight | Letter-spacing | Where |
|---|---|---|---|---|
| Display Large | 40 | 800 (Extra Bold) | -0.5 | Hero numbers (ring center value, "82") |
| Headline Medium | 22 | 800 | -0.3 | Screen titles ("GaitGuard Nexus", "Trends", "Health Insights", "Device") |
| Title Medium | 15 | 700 (Bold) | 0 | Metric values, legend values |
| Body Medium | 14 | 500 (Medium) | 0 | Paragraph copy, explanatory text |
| Label Small | 11 | 700 | 0.6 | Uppercase micro-labels, always the same secondary color |

### Motion (`AppMotion`)

- `springCurve` = `Curves.easeOutCubic` — the one curve used everywhere, standing in for a native spring feel.
- `medium` = 420ms — card-level transitions, chip toggles.
- `fast` = 220ms — small state flips (demo toggle, chip selection).
- Ring fills animate **independently per ring** via `TweenAnimationBuilder` (700ms, `easeOutCubic`) — updating one metric doesn't restart the others.
- The connection badge's pulse ring loops continuously (1400ms) behind the status dot whenever a live/simulated stream is flowing.
- The COP marker eases to its new position over 260ms (`easeOutCubic`) whenever a new sample arrives; a 12-point fading trail follows it.
- `RoundedCard` uses an `AnimatedContainer` (200ms) so radius/color changes never snap.

### Shape & spacing

- One card primitive everywhere: `RoundedCard` (`lib/shared/widgets/rounded_card.dart`), radius varies per context (18 for small metric tiles, 20–22 for compact cards, 26–28 for standard cards, 32 for the hero rings card) but the *shape language* — flat color, no border, no shadow — never varies.
- Standard screen padding: `20` horizontal, `12` top, `32` bottom.
- Standard inter-card gap: `16`.

## Navigation (`lib/features/shell/app_shell.dart`)

Bottom tab bar, 4 tabs, built on `IndexedStack` (not named routes) so all four screens stay mounted simultaneously — switching tabs never tears down the telemetry stream or resets scroll position:

| Tab | Icon | Screen |
|---|---|---|
| Today | `grid_view_rounded` | Dashboard |
| Trends | `trending_up_rounded` | Sparkline history |
| Health | `favorite_rounded` | Plain-English insights |
| Device | `settings_rounded` | Connection + data management |

Active tab: brand indigo icon+label. Inactive: secondary gray. Tab bar sits on a `card`-colored surface with a hairline top divider (0.6px), slightly translucent (92% opacity) so content can be glimpsed scrolling underneath.

## Screen 1 — Today (`dashboard_screen.dart`)

The flagship screen; everything reads from `TelemetryController` (Riverpod), never touches a socket or timer directly.

1. **Header** — app title (Headline Medium) + `ConnectionBadge`: a pulsing colored dot + uppercase label reading `LIVE TELEMETRY` / `SIMULATION RUNNING` / `NOT CONNECTED` depending on state.
2. **Connection error banner** (conditional) — only shown when a connection error exists *and* the app isn't simulating, so a stale error from a previous session doesn't obscure a working demo.
3. **Live/Simulation segmented toggle** — pill-shaped `SegmentedToggle`, slides between "LIVE SENSOR" and "SIMULATION" with a 260ms `AnimatedContainer`.
4. **Gait explanation card** (simulation mode only) — plain-English one-liner naming the active `GaitMode` and why it looks the way it does (e.g. "Low heel impact combined with increased stance duration suggests Parkinsonian shuffling gait").
5. **Activity rings card** — the signature element. Three concentric rings (`HealthRings`, hand-drawn with `CustomPainter`, no chart library), each sweeping clockwise from 12 o'clock: outer=Stability (red-pink), middle=Cadence (green), inner=Safety (cyan). Center shows the hero Stability number. A legend column to the right repeats each ring's color dot + label + live value.
6. **Metrics grid** — 2×3 grid of `MetricTile`s: Gait Phase, Steps, Stance/Swing ratio, Stability Band (color-coded green/orange/red), MLPI, Impact %.
7. **Plantar Pressure Map card** — see dedicated section below; this is the most recently redesigned part of the app.
8. **Anomaly card** (conditional) — only rendered when `anomalyFlags` is non-empty; red label + bulleted list.
9. **Disease selector** (simulation mode only) — chip row of all `GaitMode`s plus a "RUN DEMO"/"STOP DEMO" auto-cycle toggle that rotates through every mode every ~4s hands-free.
10. **Dataset strip** — small storage icon + running sample count + last save status, always visible at the bottom.

### Plantar Pressure Map (redesigned)

Replaced a procedurally-drawn single-foot outline with the real FSR reference diagram (`assets/images/feet.png`, sourced from the original web app), showing **both feet** side by side:

- **Header row**: "PLANTAR PRESSURE MAP" label, a **"12-BIT ADC" badge** (lavender/indigo pill — not decorative; the ESP32's ADC really is 12-bit, matching the `/4095` normalization in `biomechanics_engine.dart`), and a "COP" legend dot.
- **Four glow zones per foot** — Toe, 1st MT (medial forefoot), 5th MT (lateral forefoot), Heel — rendered as soft `RadialGradient` blurs in indigo/violet (forefoot zones) and cyan (heel), positioned at screen-space coordinates measured directly against the reference image (not guessed). Size and opacity both scale with the live 0–1 pressure reading for that zone (`0.22 → 0.82` opacity, `0.7× → 1.2×` size), so a resting foot looks faint and a loaded zone glows visibly.
- **Data mapping**: since the physical insole is a single sensor, both feet mirror the *same* live reading — `toe`→Toe, `inner`→1st MT, `outer`→5th MT, `heel`→Heel. This is a visual-completeness choice (matching the two-foot reference diagram), not a claim of bilateral instrumentation.
- **Static "+" crosshairs** on both feet — decorative reference marks matching the source diagram's own styling.
- **Live COP marker + fading trail** — shown only on the **left** foot, since that's the one actually carrying real x/y data; a white-filled, brand-indigo-ringed dot eases to each new position with a soft trailing glow behind it.
- Fades to 25% opacity when disconnected (crosshairs and the base photo stay fully visible; only the live glow layer dims).

## Screen 2 — Trends (`trends_screen.dart`)

Built directly from the shared `BiomechanicsEngine`'s rolling history buffer (no separate trend-tracking data structure).

- Header: "Trends" + "Last N processed samples this session".
- Empty state: icon + explanatory copy when no history exists yet.
- Four `_TrendCard`s, each a label + current value (colored to match its metric) over a 90px `fl_chart` line chart — curved line, gradient area fill fading to transparent, no axes/grid/touch interaction (pure sparkline):
  - Stability Index (red-pink, 0–100)
  - Cadence (green, 0–160 spm)
  - Impact Severity (orange, 0–100%)
  - Ischemic Pressure Integral (red, 0–100%)

## Screen 3 — Health (`insights_screen.dart`)

The plain-English read of what the engine currently sees — consolidates several web-app variants (3D view, heatmap legend, anatomy legend) into one card-based screen.

- **Clinical Summary card** — one dynamically-generated sentence (`_summarySentence`) that branches on connection state → calibration state → active anomaly flags → stability band, always in that priority order.
- **MLPI / Ischemic Risk stat pair** — two side-by-side cards, each: micro-label, Headline-Medium value, one-line plain-English caption underneath.
- **Automated Observations card** — either "No anomalies in the current rolling buffer" or a bulleted list of active flags with a red warning icon each.
- **"Why These Alerts Fire" card** — a paragraph spelling out the exact numeric thresholds behind every possible flag (e.g. ">8° corrected roll with lateral-dominant pressure" for ankle instability), reinforcing the "explainable, not black-box" promise directly in the UI.

## Screen 4 — Device (`device_screen.dart`)

Connection settings, dataset management, and session metadata — the only screen that isn't purely a read-only telemetry view.

- **ESP32 WebSocket Stream card**:
  - Endpoint + optional relay-endpoint fields with **inline validation** (non-empty + `ws://`/`wss://` scheme check) surfaced via `errorText`, not just a later runtime socket error.
  - **Four-state Connect button**: Disconnected (brand, "Connect") / Connecting (disabled, spinner, "Connecting…") / Connected (danger red, "Disconnect") / Error.
  - **Status row** (connected only): "Connected to \<url\>" + "Last update: HH:MM:SS" — data that previously existed in state but was never surfaced in the UI.
  - **Error state**: message in danger-red + an inline "Retry now" button that bypasses the exponential-backoff wait.
- **Session Metadata card** — Session ID + Trial ID fields.
- **Research Dataset card** — running sample count + save status, "Export CSV" (via `share_plus`) and "Clear" (with a confirmation dialog) buttons.
- **Backend Upload card** — upload endpoint + obscured bearer-token field, "Upload dataset" button with an inline spinner and a result/error message below.

## Shared components (`lib/shared/widgets/`)

- **`RoundedCard`** — the only card shape in the app; optional `onTap` wraps it in `Material`/`InkWell` for a ripple.
- **`MetricTile`** — label + value inside a small `RoundedCard`, optional value color override (used for the color-coded Stability Band).
- **`ConnectionBadge`** — pulsing dot (continuous 1400ms loop when live) + uppercase label. (The pulse `AnimationController` is built eagerly in `initState`, not lazily, after a dispose-time crash bug was found and fixed this project — see git history.)
- **`SegmentedToggle`** — pill-shaped, animated (260ms) live/simulation switch.

## Connectivity states → visual states

The Device screen's Connect button and the Today screen's `ConnectionBadge` are the two places connection state surfaces. As of the connectivity refactor (`CONNECTIVITY_PLAN.md`):

- Reconnect uses **capped exponential backoff with jitter** (1.5s → 30s ceiling) rather than a fixed 1.5s retry, so a genuinely offline device doesn't get hammered.
- A single malformed JSON frame on an otherwise-healthy link no longer shows a stale error banner — it's treated as a transient blip, not a disconnect.
- Entering simulation mode now actually disconnects any live socket (and vice versa) — previously both could run in the background simultaneously, silently corrupting the recorded dataset with interleaved live+simulated samples.

## Light / dark mode

Every screen and component is theme-aware via `Theme.of(context)` — there is no screen-specific light/dark branching outside `app_theme.dart` and the two or three spots (`FootPressureView`, `DiseaseSelector`) that need a literal color not expressible through `ThemeData` (e.g. the foot-map's background wash, the disease-chip inactive fill). `ThemeMode.system` is used app-wide — the app follows the OS setting, no in-app theme toggle exists.

## What's intentionally not built yet

See `BETTERMENTS.md` for the full list; the headline items relevant to UI/UX:

- No onboarding flow / first-run wizard (Device screen's Connect card *is* the entire setup flow, by design — see `CONNECTIVITY_PLAN.md`'s explicit scoping decision).
- No BLE transport or mDNS auto-discovery UI (manual `ws://ip:port` entry only).
- No dark-mode-specific asset for the plantar pressure photo — `feet.png` has a baked-in white canvas background, so a white rectangle is visible behind the foot silhouette in dark mode (a limitation of the source asset, not the code).
- No animated tab-switch transition (`IndexedStack` swaps instantly) or ring "breathing" idle animation — both are named as proposed additions in the companion Figma design file, not implemented in the app.
