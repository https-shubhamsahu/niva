# ESP32 Connectivity — Fix & Flow

## Context

The niva (GaitGuard Nexus) Flutter app was ported from a web app and, until this session, had never been run against real hardware or even compiled (no Flutter SDK was available while it was written). Earlier this session we scaffolded the platform folders, got it building/testing clean, and fixed two crash bugs discovered by actually running it on an emulator (an unhandled `WebSocketChannelException` on connection refusal, and a lazily-initialized `AnimationController` crashing on dispose).

The user is now moving to a real ESP32 dev kit and wants the connectivity layer made reliable before anything else, prioritizing **connect/reconnect UX** over a broader onboarding flow. The ESP32's WiFi mode (station joining the LAN vs. hosting its own AP at the classic `192.168.4.1` default) is not yet decided, so nothing here should hardcode an assumption about it — from the app's side, both modes are identical: a `ws://` URL the user types in, dialed the same way either way.

Exploration (this session) confirmed the connection code already has most of the right shape (a broadcast `Esp32ConnectionState` stream, a `TelemetryController` single source of truth, an existing relay-URL indirection) but has several concrete gaps that will make a real device frustrating to use:
- Platform manifests are still stock `flutter create` output — **a real device literally cannot connect yet** (no Android `INTERNET`/cleartext permission, no iOS local-network/ATS exception).
- Reconnect is a flat, uncapped 1.5s timer forever — fine for a demo, annoying for a real device that might be powered off for a while.
- The Device screen shows only Connected/Disconnected + a raw error string — no "Connecting…", no retry action, no visibility into what URL it's actually dialing or when data last arrived, no input validation (garbage URLs only fail at the socket layer).
- A confirmed lifecycle bug: switching into simulation mode doesn't disconnect a real socket (and switching back to live doesn't stop the simulation timer), so simulated and real data/reconnect-loops can run concurrently and confuse both the UI and the recorded dataset.

## Approach

Four independent, sequentially-safe changes. Each is separately testable and none blocks on a decision about AP-vs-station mode.

### 1. Platform manifests (prerequisite — unlocks real-device testing)

**`android/app/src/main/AndroidManifest.xml`**
- Add `<uses-permission android:name="android.permission.INTERNET"/>` as a child of `<manifest>` (sibling of `<application>` and `<queries>`).
- Add `android:usesCleartextTraffic="true"` to the existing `<application ...>` tag — the default endpoint is plaintext `ws://`, not `wss://`.

**`ios/Runner/Info.plist`**
- Add `NSLocalNetworkUsageDescription` (a user-facing string explaining the local-network prompt) and an `NSAppTransportSecurity` dict with `NSAllowsLocalNetworking = true` — this permits cleartext `ws://` to local-network hosts (RFC1918/`.local`/link-local) without a blanket arbitrary-loads exception, and covers both `192.168.4.1` (AP) and a router-assigned LAN IP (station) since both are "local network" to iOS.
- No `NSBonjourServices` — mDNS discovery is explicitly out of scope.

### 2. `lib/core/connectivity/esp32_socket_service.dart` — backoff + error clearing

- Replace the flat `Timer(const Duration(milliseconds: 1500), connect)` in `_scheduleReconnect()` with capped exponential backoff + jitter: track `int _reconnectAttempt = 0`, delay = `min(1500ms * 2^attempt, 30000ms)` jittered ±15%, incrementing each scheduled attempt. Reset the counter to 0 on a successful connect (add a success branch alongside the existing `channel.ready.catchError(...)`, i.e. `channel.ready.then((_) => _reconnectAttempt = 0)`) and in `disconnect()`. No max-attempt give-up — the failure could be "ESP32 not powered on yet" (resolves in seconds) or "phone roamed off this WiFi" (could be hours); infinite capped retry plus the new manual "Retry now" button (step 4) covers both without ever leaving the user stuck.
- Fix the malformed-JSON handler so a single bad frame doesn't leave a stale error banner forever: if `_state.isConnected` is already true when a decode fails, treat it as a transient blip and clear any error (`_emit(_state.copyWith(clearError: true))`) instead of setting one; only surface the malformed-JSON error string when the link isn't already known-good.

### 3. `lib/core/providers/telemetry_controller.dart` — simulation/live lifecycle

Two one-line fixes, same class of bug on both sides of the live↔simulation seam:
- `startSimulation()`: call `socket.disconnect()` first. Running a real reconnect loop silently in the background while simulated data drives the UI is confusing and wastes battery/network.
- `connectLive()`: cancel and null out `_simulationTimer` (mirroring what `stopSimulation()` already does). Currently going live from simulation leaves the simulation `Timer.periodic` still ticking every 50ms, interleaving simulated and real samples into `copTrail` and the recorded dataset.

### 4. `lib/features/device/device_screen.dart` — connect/reconnect UX

Reuse existing patterns (`RoundedCard`, `_LabeledField`, `AppColors`); no new screens or wizard steps.

- **Four visual states** driven entirely by fields `TelemetryState` already exposes (`isConnected`, `isConnecting`, `connectionError`) — nothing new needed in state:
  - Disconnected: "Connect" button, brand color.
  - Connecting (`isConnecting`, currently unused in this screen): button disabled with a small `CircularProgressIndicator`, matching the existing upload-button spinner pattern at line ~232.
  - Connected: "Disconnect" button (unchanged), plus a new small status line showing `state.activeUrl` and last-update time.
  - Error (`connectionError != null`): show the message in `AppColors.danger` (currently `AppColors.warning` — bump severity) plus a new **"Retry now"** `TextButton` calling `controller.connectLive()` directly, bypassing the backoff wait.
- **Status line**: new small private widget/inline `Column` showing `Connected to <activeUrl>` and `Last update: <absolute HH:mm:ss>` (absolute time, not relative, to avoid needing a new periodic-rebuild timer on a settings screen).
- **Inline validation** on the `wsUrl` and `relayUrl` fields: a small pure function checking non-empty (wsUrl only), parses as a `Uri`, and scheme is `ws`/`wss`. Wire it through a new optional `errorText` parameter on `_LabeledField` (backward-compatible — existing call sites omit it) rendered via `InputDecoration.errorText`. The Connect button's `onPressed` short-circuits to just showing the validation error (no `connectLive()` call) if the current `wsUrl` text fails validation — catching garbage input before it ever reaches the socket layer and burns a doomed connect+backoff cycle.

**Explicitly out of scope** (named, not designed): BLE transport, mDNS/Bonjour auto-discovery, QR pairing, multi-step onboarding wizard — all noted in `BETTERMENTS.md` as future work; no code for any of them exists today.

## Critical files

- `android/app/src/main/AndroidManifest.xml`
- `ios/Runner/Info.plist`
- `lib/core/connectivity/esp32_socket_service.dart`
- `lib/core/providers/telemetry_controller.dart`
- `lib/features/device/device_screen.dart`

## Verification

1. `flutter analyze` and `flutter test` stay clean (already passing baseline from earlier this session).
2. Manual test against the real ESP32 once it's on WiFi (either mode): point `wsUrl` at its IP, confirm the app builds/runs on Android (manifest fix required for this to even connect) and shows Connecting → Connected, with `activeUrl` and a last-update time visible.
3. Simulate failure paths without hardware: set `wsUrl` to an unreachable address (e.g. `ws://192.0.2.1:81`, a TEST-NET address guaranteed to fail) and confirm: Connecting → Error state, "Retry now" works immediately, and automatic retries visibly space out (1.5s, 3s, 6s...) rather than hammering every 1.5s.
4. Enter an obviously-invalid URL (empty, no scheme, `http://` instead of `ws://`) and confirm the error shows inline on the field and no connect attempt fires.
5. Toggle Connect (live) → Simulate → back to Connect (live) and confirm via logging/breakpoints (or just dataset sample source field) that only one of the two timers/sockets is ever active at a time.
