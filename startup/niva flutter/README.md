# Niva Flutter

Mobile app for the Niva insole. It shows what the insole measures and nothing else:
- the instrument's validity state;
- contact timing (cadence, contact time, heel-first share) from edges the firmware timestamps at 100 Hz;
- a relative-load view of the one connected insole;
- the Fit India Flamingo balance and Vrikshasana tests (Tests tab), run by a tester with the insole flagging events.

There is no simulator, no score, no risk flag and no diagnosis. Timing values stay hidden until 12 foot contacts have been seen. The FSR readings are relative load indices, never force or pressure.

It is not a WebView wrapper. It speaks the same ESP32 telemetry contract over Wi-Fi WebSocket or direct BLE.

## Redesign checkpoint — 1 October 2026

The app now opens in a light Niva theme with an original animated sneaker mascot. First launch lets you choose participant or trainer; the choice survives restart and can be changed from the profile button. The trainer home leads into the existing Flamingo and Vrikshasana assessments and shows actual recent trials on this phone. Live insole readings remain available from home, with trend and device tabs retained.

Participant home is a preview: local/internet trainer pairing is planned but not connected yet. Voice and chime preferences are saved for the upcoming feedback service; they do not play audio yet. Vibration preferences control existing haptic calls on supported platforms. Reduce motion stops decorative animation and simplifies transitions, alongside the device accessibility setting.

The complete roadmap, task acceptance criteria and successor prompt are in the repository's `tasks/plan.md`, `tasks/todo.md` and `tasks/HANDOFF.md`. Current verification: 47 tests pass, analyzer reports no issues, web release build succeeds. Physical Android/insole/audio checks remain pending.

## Removed in the October 2026 cleanup

These were removed so that nothing on screen can pass for a measurement when it is not one:
- the disease-mode gait simulator (Parkinson, stroke, neuropathy and similar) and its selector;
- the Health tab with its "clinical summary", "ischemic risk" and rule-based "AI coach";
- the stability score, impact-safety ring and anomaly flags;
- the centre-of-pressure dot and the mirrored second foot;
- the `diseaseLabel` column in exported CSVs.

Rows recorded by older builds still load. Their `mode` column still says `simulation` where it did.

## Technology stack

- Flutter / Dart 3.3+
- Riverpod
- Hive + `shared_preferences`
- `web_socket_channel`, `flutter_blue_plus`
- `fl_chart`, `share_plus`, `http`; bundled Inter font (offline)

Platform folders already in this project: `android/`, `ios/`, `windows/`, `web/`.

## Directory structure

```text
lib/
  core/
    models/            Telemetry sample and gait metric types
    engine/            GaitTimingEngine: firmware contact events to timing
    fitness/           Fit India test rules, Flamingo and Vrikshasana sessions, trial record
    time/              Monotonic clock and insole-to-phone clock mapping
    connectivity/      Wi-Fi WebSocket and BLE telemetry services
    data/              Hive dataset store, settings, optional CSV upload
    experience/        Persisted roles, feedback and reduced-motion preferences
    providers/         TelemetryController is the source of truth
  features/
    experience/        Role choice, assessment-first home, preferences
    dashboard/         Live readings: validity, contact timing, relative-load view
    tests/             Tests: setup sheet, full-screen test runner, saved trials
    trends/            One point per stride (cadence) or contact (contact time)
    device/            Connection, tare, session metadata, export/upload
    shell/             Bottom tab shell
  theme/
  shared/widgets/
test/
  gait_timing_engine_test.dart
  fitness_sessions_test.dart     protocol rules, clock mapping, trial record
  test_mode_widget_test.dart     full trials, small phone at 200% text, landscape
assets/
  images/feet.png
  brand/               Existing Niva identity
  mascot/              Original transparent sneaker illustration
  fonts/               Inter variable font and SIL OFL license
  PROVENANCE.md        Sources and mascot generation prompt
  icon/
```

## Setup

```bash
cd "niva flutter"
flutter pub get
flutter analyze
flutter test
flutter run
```

Android and iOS platform declarations cover local Wi-Fi and BLE. On Android, approve the Bluetooth permission request; on iOS, approve the Bluetooth and local-network requests when the platform asks.

## Configuration

There is no `.env` file. WebSocket URL, optional relay URL, session/trial IDs, and upload endpoint are runtime settings on the Device tab, persisted with `shared_preferences`.

## Connection to other Niva components

- Firmware: `niva arduino/niva_hardware/niva_hardware.ino` is the active BLE + Wi-Fi firmware. The Bluetooth service reassembles the firmware's framed notifications into the same JSON packet used by Wi-Fi.
- Web: `niva web` is the clinician dashboard with USB Serial plus extra visualization pages that were not ported here (3D foot views, clinician PDF).
- USB-OTG is not implemented in this app. BLE and Wi-Fi are both supported transports.

## Fitness tests

The Tests tab runs two items of the Fit India protocol for ages 18 to 65:
- **Flamingo balance (p. 24).** It counts falls during 60 s of balancing. The clock pauses at each fall and resumes when the instructor lets go. More than 15 falls in the first 30 s ends the test.
- **Vrikshasana (p. 23).** It records the hold time from the final position, up to 60 s. A hold under 10 s is flagged for a restart, as the protocol asks.

The tester runs every trial, and the insole only flags events. It goes on the raised foot:
- In the Flamingo test it flags that foot touching the ground.
- In Vrikshasana it flags that foot's sole letting go of the thigh.

When the insole flags something, the test stops for the tester to count it or dismiss it. Both the flag and the decision are saved. Each trial therefore records how far the insole agreed with the tester, which is the data checks F1 and F2 of the SIH26213 plan need.

Without a connected, tared insole the tests still run, with the tester timing and counting alone. The trial record says so.

Neither test has a published Fit India benchmark, so no level or rating is shown.

The setup sheet explains the standing leg and raised-foot placement before
opening the keyboard. Saved trials can be searched by participant ID and
filtered by test. The list shows up to 30 matching results; **Export all**
includes every saved trial, regardless of the current filters.

Trials are stored on the phone and exported from the Tests tab as `niva-fitness-trials-*.csv`. The `losses` column lists each Flamingo event as `source@balanceMs`:
- `C`: insole flagged, tester counted;
- `D`: insole flagged, tester dismissed;
- `T`: tester only.

## Exported CSV

The columns are `timestampMs` (phone clock), `source`, `sessionId`, `trialId`, `mode`, `heel`, `inner`, `outer`, `toe`, `impact`, `pitch`, `roll` and `accZ`. Then come three insole columns:
- `deviceTimestampMs`: the insole's clock;
- `contact`: a bit mask (1 heel, 2 inner, 4 outer, 8 toe);
- `events`: the frame's contact events separated by spaces, for example `h+@1100 F+h@1100`.

The event codes are defined in `niva arduino/README.md`. They use the same clock as `deviceTimestampMs`, so a session can be lined up against video afterwards.

## Additional docs in this folder

These describe the earlier GaitGuard Nexus port, before the cleanup above. Read them as history:
- `DESIGN.md` — visual language;
- `BACKEND_LOGIC.md` — data contract and storage;
- `SIMULATION_LOGIC.md` — the removed disease-mode simulator;
- `BETTERMENTS.md` — follow-up ideas.
