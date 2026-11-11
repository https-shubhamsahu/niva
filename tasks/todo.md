# Niva redesign task ledger

Status key: `[ ]` pending, `[x]` acceptance and verification completed. Work in order unless HANDOFF explains a justified dependency change. Do not mark physical-device checks from browser evidence.

## T01 — Durable plan and handoff
- [x] Agreed choices, architecture, claims boundaries and prior local edits recorded.
- [x] Ordered task ledger and ready-to-use successor prompt written.
- [x] Existing incomplete plans preserved (none existed at `tasks/plan.md` or `tasks/todo.md`).
Verification: inspect all three task documents. Dependencies: none. Files: `tasks/plan.md`, `tasks/todo.md`, `tasks/HANDOFF.md`.

## T02 — Brand assets and light visual foundation
- [x] Default light theme uses teal/white/coral/lime, readable typography and visible interaction feedback.
- [x] Original sneaker mascot and Niva logo are bundled with provenance; font works offline.
- [x] Shared motion respects reduced-motion preferences and inactive tabs stop their decorative tickers.
Verification: theme/asset smoke checks, small-screen preview, `flutter analyze`, web build. Depends: T01. Files: theme, pubspec, assets, mascot/motion widgets (split asset and widget work if needed).

## T03 — Persistent role and sensory preferences
- [x] Participant/trainer role and voice/chime/haptic preferences survive restart.
- [x] Role can be switched; preference controls have accessible labels and independently toggle.
- [x] Existing settings and telemetry behavior remain compatible.
Verification: persistence tests with mock SharedPreferences. Depends: T01. Files: preference models, repository/provider, settings view, focused tests.

## T04 — Welcome and role-aware assessment home
- [x] First launch presents role choice and original animated mascot; returning users see their role-specific home.
- [x] Trainer can reach and complete the existing assessment flow; participant sees a truthful join entry point.
- [x] Logo, mascot, real recent results and primary action fit a 320px phone at 200% text without overflow.
Verification: role/navigation widget tests, complete trainer trial, screenshots. Depends: T02,T03. Files: main, shell, welcome/home, tests.

### Checkpoint A — Reviewable visual foundation
- [x] Full Flutter tests pass; web build succeeds; screenshots and HANDOFF refreshed.

Checkpoint A evidence (1 October 2026): 47 tests passed, including all previous 40; analyzer has no issues; web build succeeded. Browser verified welcome, trainer/participant home, role persistence after reload, compact viewport and truthful pairing sheet. 320px/200% text and completed 12-second hold from home verified with widget tests. Voice/chime playback and two-phone/native hardware verification remain pending under later tasks.

## T05 — Guided preparation and assessment styling
- [ ] Written pose/placement instructions, optional speech and readiness lead into trainer-confirmed start.
- [ ] Any countdown remains outside official test time; aborting preparation records no trial.
- [ ] Fixed controls, warnings, decision state and timer remain usable in landscape and large text.
Verification: fake-clock preparation tests, existing protocol/widget tests, keyboard/landscape preview. Depends: T04. Files: preparation screen, runner view, phase widgets, focused tests.

## T06 — Feedback service and sound assets
- [ ] Chimes and spoken guidance work through a testable feedback service with independent persisted preferences.
- [ ] Haptics identify selection, start, flag and completion without firing on every telemetry frame.
- [ ] Leaving a screen cancels speech/sound; reduced-motion and mute settings are respected.
Verification: fake feedback tests; native Android sound/speech/vibration checklist. Depends: T03,T05. Files: feedback service, dependency declarations, sound assets, run integration, tests.

## T07 — Result reveal and mascot state assets
- [ ] Completion celebrates real trial completion; retry-under-minimum and early termination get accurate copy.
- [ ] Actual save progress/failure is shown with retry; no result is labelled saved before persistence succeeds.
- [ ] Welcome, waiting, preparation and completion mascot states have implemented assets/animation and provenance.
Verification: delayed/failing store tests, result screenshots, reduced-motion check. Depends: T05,T06. Files: controller save state, result view, mascot assets/widget, tests.

### Checkpoint B — Single-device assessment experience
- [ ] Both assessments complete from the new home; all tests/builds pass; feedback device verification recorded.

## T08 — Versioned shared-session contract
- [ ] Snapshot contains authoritative trainer state, revision, trial/session identity and final result; malformed messages rejected.
- [ ] Observer cannot alter trainer clock/decisions; new trials and stale revisions handled explicitly.
- [ ] Disconnect state, resume semantics and data ownership documented.
Verification: pure-Dart serialization/state tests. Depends: T05. Files: shared session model, protocol document, snapshot adapter, tests.

## T09 — Local trainer-hosted room
- [ ] Android trainer hosts an ephemeral room over local Wi-Fi/hotspot; observer subscribes with a room credential.
- [ ] Late join/rejoin receives latest snapshot; malformed/unauthorized observer requests cannot change results.
- [ ] Conditional web fallback explains native local hosting availability without pretending pairing succeeded.
Verification: loopback integration tests, two physical Android phones/hotspot; host clean shutdown. Depends: T08. Files: conditional host transport, provider/controller, tests (max ~5 files per slice).

## T10 — Participant join and live observer experience
- [ ] Participant can join a local room using address/credential and view pose, canonical state and final result.
- [ ] Disconnected/stale session is visible; retry resumes latest trainer state; authoritative results stay trainer-owned.
- [ ] Trainer/participant screens expose correct role-specific actions and no forbidden controls.
Verification: paired fake transports, bad-code/error/rejoin widget checks, two-phone walkthrough. Depends: T09. Files: join screen, observer runner, connection controller, tests.

## T11 — Internet room broker
- [ ] Broker creates expiring rooms, uses separate owner/observer credentials and enforces role permissions.
- [ ] Size/rate/revision checks, bounded memory and clean closure prevent malformed/stale packets from corrupting rooms.
- [ ] Broker has local integration tests and launch/deployment instructions; real hosting status is explicit.
Verification: Node/ws two-client integration tests; bad credentials/observer writes/reconnect/expiry. Depends: T08. Files: `startup/niva sessions/` server/package/tests/docs. Separate from ESP32 relay.

## T12 — Internet transport and session controls
- [ ] Runtime broker endpoint and local/internet selection; no hardcoded private URL or credentials in source.
- [ ] Trainer create/participant join works against the locally verified broker; transport errors are actionable.
- [ ] Internet rejoin and result recovery match local semantics; external endpoint/device validation separately recorded.
Verification: end-to-end two clients; restart/reconnect; native two-phone test against deployed TLS endpoint. Depends: T10,T11. Files: internet transport, session UI/preferences, tests.

### Checkpoint C — Shared assessment
- [ ] Local AND internet paths pass integration checks; physical-device/hosting gaps accurately listed.

## T13 — Actual assessment progress
- [ ] Progress uses saved trials and like-for-like test/leg comparisons; empty states contain no fake numbers.
- [ ] Participant search/filter/export remain correct; trainer and participant ownership clearly indicated.
- [ ] Accessible charts and meaningful result transitions fit small/large text screens.
Verification: seeded real-shaped trial fixtures, comparison/filter tests, light-theme screenshots. Depends: T07,T10. Files: progress screen, trial queries, charts, tests.

## T14 — QR pairing convenience
- [ ] Trainer shows a scannable join payload with version/transport/expiry; manual entry remains available.
- [ ] Participant camera permission, wrong/expired QR and unsupported payloads have recovery paths.
- [ ] Pairing secrets never leak into analytics/log output; internet observer credentials cannot grant control.
Verification: payload validation tests, Android camera walkthrough. Depends: T12. Files: QR widgets/parser, dependencies/platform config, tests.

## T15 — Android delivery and final handoff
- [ ] Android APK builds; install/launch/both roles/two transports tested on actual available phones.
- [ ] Voice/chime/haptic/mute/reduced-motion settings, connection loss and sensor tare checked on devices.
- [ ] All task statuses reflect evidence; README, screenshots, remaining deployment steps and successor prompt updated.
Verification: full tests/analyze, release/debug APK build, signed physical-device checklist; no unsupported production-ready claim. Depends: all previous tasks. Files: Android config as needed, documentation/checklist.
