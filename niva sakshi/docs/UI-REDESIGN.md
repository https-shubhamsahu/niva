# Niva Sakshi — UI redesign and verification

Updated **2 October 2026**. All app changes belong to the local `niva sakshi/app/` copy. The original Niva app remains a separate project.

## Intent

Make the app feel calm, readable and immediate, with Apple Health as a reference for information hierarchy: clear page titles, grouped white cards, restrained colour, large measured values and details available on demand. The user should see the main page and its primary action without the small, unnecessary scroll required by the previous layout.

This is an original Flutter design using the app's bundled Inter font and Material interactions. It does not reproduce Apple assets, invent a fitness score or imply that Apple endorses the product.

## Navigation and page decisions

| Area | Current experience | Details remain available through |
| --- | --- | --- |
| Summary | Role, connection status, start assessment, two test choices, practice/roster and latest saved assessment | Profile, individual test setup and saved result |
| Tests | Readiness, Flamingo and Tree pose, three station tools and assessment history | Readiness help, setup sheet, separate saved-trials screen |
| Live | Cadence hero, contact time, heel-first contacts and one insole's four sensing points | Session details sheet and session trends |
| Device | Compact connection/configuration and feedback preferences | Existing connection and preference controls |
| Assessment | Actual elapsed clock, count/phase and visible controls at the bottom | Protocol help, counted-loss details and full result record |
| Practice | Actual elapsed time, concise instructions and bottom controls | Instruction help |
| Roster | Queue and student list; editor collapses after class setup | Edit action |

The four main tabs are **Summary / Tests / Live / Device**. Trends is a detail route from telemetry. Saved-trial search/filter/export is a separate screen so a long history does not expand the Tests overview.

## Screen fit

- The four main screens have regression checks at **360 × 800** and **390 × 844** logical pixels, including reserved system insets and the bottom navigation bar. At default text size their content has no vertical scroll extent.
- Welcome, practice, witness agreement and the ready assessment screen also have a compact-phone fit check.
- Core assessment flows retain checks for landscape and **200% text size**. Readability takes precedence over forcing every detail into a fixed height: enlarged text, smaller screens, lists and detail sheets may scroll.
- Shared pages have a maximum content width of 720 logical pixels. Main actions on run/practice screens sit outside their scrolling content.
- Full records, long histories and class rosters intentionally remain scrollable. The fit guarantee applies to the tested overview states, not every future dataset or screen configuration.

## Visual language

- Background: `#F2F2F7`; primary cards: white; neutral dark text.
- Primary blue: `#0066CC`; warning/accent coral: `#C94C3A`; success green: `#217A35`. Normal text using these colours on white meets a 4.5:1 contrast target.
- Large, clear titles; compact supporting text; aligned values and units; restrained rounded corners.
- Primary buttons use a minimum height of 48 logical pixels. Navigation rows provide a full-row touch target.
- Cards communicate actual product functions. Colours and icons supplement labels; they do not replace status text.
- The Live tab's foot map reuses the original Niva `feet.png` illustration, clipped to the one measured foot. Four heat zones, contact rings and relative-load bars correspond to its actual sensor channels; contact rings enclose the image's printed zone labels so the labels stay readable. Details: [BRAND-AND-IMAGERY.md](BRAND-AND-IMAGERY.md).

## Launch experience

Launch is one continuous sequence across the native and Flutter splash:

1. **Android 12+ system splash (900 ms, `drawable-v31/sakshi_splash_animated.xml`):** the beam extends, the witness eye traces itself and the observation dot pops in. The icon is `drawable/sakshi_splash_icon.xml`: a 288dp canvas with the mark at 0.75 scale in the centre, so it sits inside the 192dp circle Android crops splash icons to. The first phone test (2 Oct) showed the previous icon cut off at both sides of the eye and through the beam because it filled its whole canvas.
2. **Flutter launch (1,500 ms, `launch_screen.dart`):** it opens on the native splash's final frame (same 144dp mark, same centre), the eye blinks, a halo ripples out, the mark rises as the wordmark and tagline arrive, and the launch layer dissolves into the app, which is already mounted underneath and is not rebuilt. Frame sheet: `previews/launch-sequence.png`.

Android before 12 shows the same 144dp mark on the launch window background. When the system or the in-app setting requests reduced motion, the Flutter sequence is skipped. The launch never waits for hardware. The identity itself is described in [BRAND-AND-IMAGERY.md](BRAND-AND-IMAGERY.md).

The Flutter animation starts after repository/service initialization. Native startup duration and the transition between native and Flutter splash still need measurement on a physical phone.

## Motion

Shared in `lib/shared/widgets/motion.dart`, after the way Apple Health moves:

- **Entrance:** every `HealthPage` section fades and rises 18px into place, staggered 45 ms apart (capped at eight). A tab's sections wait until that tab is first shown. The result screen uses the same cascade.
- **Press:** tappable cards shrink to 97% under a finger and spring back.
- **Rolling values:** cadence, contact time, heel-first and the balance-break count roll upward when they change. Only the old and new real values are ever on screen; no in-between numbers are invented.
- **Live pulse:** a green dot radiates a soft ring while the insole stream is valid (Live and Summary). It stops when the stream is not valid, in hidden tabs, and with reduced motion.
- **Foot map:** heat zones and bars glide to each new reading over 360 ms. The printed percentages always show the exact current value.
- **Assessment:** the clock ring's colour eases between running and review; the ring itself follows the real clock. The saved check mark pops in on the result.
- **Navigation:** iOS-style page pushes with parallax and edge-swipe back on Android too; tab changes fade up from 98.5% scale.

All of it is skipped when Android's *Remove animations* (or animator duration scale 0) or the app's own *Reduce motion* preference is on. If the app looks completely static on a phone, check those two settings first. Tests: `test/motion_test.dart`.

## Web version (PC and phone)

Live at **https://niva-sakshi.vercel.app** (Vercel project `niva-sakshi`, team https-shubhamsahus-projects). Same Flutter app, built with `flutter build web`; redeploy with `bash app/tool/deploy_web.sh`.

- **Below 900px** (phones, narrow windows): the phone layout, unchanged.
- **900px and wider:** a sidebar (brand, Summary/Tests/Live/Device, live insole status) replaces the tab bar. `HealthPage` keeps everything above the first section full width and flows each section into the shorter of two columns, up to 1,180px. Welcome becomes a landing page: photo hero beside "Sensors flag / The teacher decides / The record keeps both" and the role choice. The Summary hero gets a desktop layout; the Live foot map uses its large size; the assessment screen stays a 680px column.
- **Loading:** `web/index.html` shows the mark drawing itself in HTML/CSS while the app downloads, at the same size and centre the Flutter launch continues from, removed on `flutter-first-frame`.
- **Sharing:** Open Graph/Twitter tags with `web/og-image.png` (1200 × 630) for link previews.
- **Exports:** trial and telemetry CSVs are built in memory (`lib/shared/csv_share.dart`): Android shares them, a browser downloads them.
- **Honest limits shown in the web build:** tester-only assessments work in any browser. The insole is not claimed to work on the web: Web Bluetooth is included but untried with the insole, and https pages block `ws://` Wi-Fi links. The sidebar and Device screen say so.

Desktop previews (1440 × 900): `previews/desktop-welcome.png`, `desktop-summary.png`, `desktop-tests.png`, `desktop-device.png`, `desktop-live-scripted.png` (scripted values, labelled), `desktop-test-ready.png`.

## Demo mode

Added 2 Oct 2026 at the user's request so judges on the website can see live readings without hardware. It is the one deliberate exception to "no simulator", with these rules:

- **Opt-in.** Start it from the Live tab: on phones the status card itself reads "No insole connected · Try demo" (no extra height); on wide screens a "No insole? Watch a demo" card. Stop it from the Live status line or the Device tab's main button ("Stop demo"). Connecting a real insole stops it.
- **Real engine, scripted input.** `lib/core/demo/demo_walk.dart` writes seeded firmware-format frames (50 ms frames, 10 ms edge grid, cadence drifting about 100–112 steps/min, mostly heel-first contacts). They run through the unchanged `GaitTimingEngine`. The first 15 s are pre-processed instantly so values appear past the 12-contact gate. A foot in the air reads zero.
- **Always labelled.** Live subtitle "Demo data · nothing is saved", status "Simulated walk" with an orange DEMO badge and orange pulse, sidebar "Demo insole · simulated", Summary "Demo insole · simulated readings", Device "Demo walk · simulated, not an insole", foot-map sheet and Trends badges, a Session details note. "Live · instrument valid" never appears for demo data.
- **Never evidence.** Demo frames are not written to the telemetry dataset, not exported, not published to the contact-event stream, and assessments see no insole (tests stay tester-only). Saved trials are therefore unaffected.
- Tests: `test/demo_test.dart` (frame format and engine output; labelled on screen; dataset untouched; no events published; stop restores the idle state). Previews: `previews/demo-live.png`, `previews/desktop-demo-live.png`.

Use demo screenshots only with a "simulated demo" caption; they are not hardware evidence.

## Telemetry rules

- Missing measurements display an em dash or an explicit empty state, rather than a plausible placeholder number.
- Timing metrics require a connected, valid stream, firmware event support and the existing minimum accepted-contact gate of 12.
- Relative load is displayed only while the connected stream is valid.
- Cadence sparklines and trend plots use the engine's actual session history. With no observations, the UI says so.
- Disconnects and invalid data hide timing values instead of presenting stale values as current.
- Diagnostic counters remain available in Session details, including dropped/tied events and IMU clipping.
- No simulated second foot, daily health score, population benchmark or long-term health trend is added.
- In an assessment, beam and insole flags retain their distinct source wording. The tester's confirmation and rejection remain authoritative in the existing workflow.

## Verification recorded

| Check | Result | Limit |
| --- | --- | --- |
| Flutter tests, sequential run | **72 passed** (incl. 5 motion, 2 demo tests) | Synthetic/widget verification |
| Compact phone overview fit | Passed at 360 × 800 and 390 × 844 | Tested states and default text size |
| Large text / landscape assessment tests | Passed | Still needs physical accessibility review |
| Timing validity / disconnected display | Passed | Injected controller data |
| Finite launch / reduced motion | Passed | Widget-level check |
| Release web build | Passed | Local browser preview; no physical BLE proof |
| Android release build | **Passed · ARM64 APK, 21.4 MB** | Debug signing for team sideloading; not physically tested |
| Static analysis | **No issues found** | Flutter analyzer |

The screenshot capture run passed and produced eleven actual Flutter-rendered UI previews, plus a launch frame sheet. These illustrate the interface; they are not photographs, real sensor readings or evidence of a tested physical station. Browser review also confirmed the rebuilt Summary and Live navigation.

The rebuilt binary is `../app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`, package `com.shubhamsahu.niva.sakshi`. It retains the separate Sakshi identity and can be installed alongside the main Niva app. Release checks are saved under `../app/build/verification/`.

Builds and tests run sequentially on this laptop to limit memory use. Run the suite as `flutter test --concurrency=1`: a parallel run on 2 Oct crashed the test shell after four minutes and reported 15 tests as "did not complete", while the same code passed 65/65 sequentially in 26 s. Android retains one Gradle worker and a 1,536 MB heap limit; its reserved code cache was increased from 128 MB to 256 MB after the release lint step exhausted the smaller cache. No checks were disabled to bypass that failure.

## Preview files

Previews are stored in `previews/`: `summary.png`, `tests.png`, `live.png`, `device.png`, `test-ready.png`, `welcome.png`, `launch.png`, `launch-dark.png`, and the foot map in `heatmap-scripted.png`, `heatmap-dark-scripted.png` and `heatmap-expanded-scripted.png`. They were rendered at 390 × 844 logical pixels with a 2× pixel ratio by `app/tool/capture_redesign.dart`. The launch images are frames of the animation, not recordings. The three `-scripted` heat-map images use explicitly scripted sensor values and carry a visible "UI PREVIEW · SCRIPTED SENSOR DATA" label; they are not live hardware readings.

For a running local web preview, open `http://127.0.0.1:5192/`. This works only while the local preview server is running.

## Physical work still required

- Install the rebuilt APK on the intended phone; review system insets, keyboard, font scaling and touch targets on that device.
- Review TalkBack reading order and descriptions of chart/sensor values with an actual screen reader.
- Check the native launch transition and frame pacing on a cold start, including reduced motion.
- Run real insole connectivity, readiness, timing, disconnect, assessment, saving and export flows.
- Capture a real device demonstration separately from these rendered previews.
- Refresh the deck and submission images to match this interface and the evidence actually available.

These tasks and all remaining firmware, hardware, reliability, study, submission and demonstration work are enumerated with priorities, dependencies and completion evidence in [REMAINING-TASKS.md](REMAINING-TASKS.md).

## References

The layout reference is Apple's [Health data overview](https://support.apple.com/guide/iphone/view-your-health-data-iphe3d379c32/ios). The animation follows the principle of purposeful motion and respecting accessibility preferences in Apple's [motion guidance](https://developer.apple.com/design/human-interface-guidelines/motion).
