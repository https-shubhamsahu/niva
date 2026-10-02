# Niva Sakshi — identity, imagery and live foot map

Updated 2 October 2026. This update belongs to the separate `niva sakshi/` app copy.

## Identity: balance witnessed

The mark has three elements: an eye for **Sakshi, the witness**; a warm central dot for an observation; and a stable horizontal beam for balance. The idea is visible even in a small launcher icon. The teacher still decides whether an observation counts.

The new identity replaces the thin insole outline on the splash and welcome screen. It uses original editable vector geometry, rather than a stock logo or an official SIH/Government mark.

The primary palette is deep navy `#173B59`, blue `#0066CC` and warm coral `#F47758`. Dark surfaces use pale blue `#A9D4FF`, warm coral `#FF9577` and pale ink `#EAF3FF`. The observation dot is a graphic accent, not a text colour or clinical status.

## Asset family

All source/export files live in [brand/](brand/). Open [brand/brand-board.png](brand/brand-board.png) for a visual overview.

| Deliverable | Files | Use |
| --- | --- | --- |
| Standalone mark | `mark-light`, `mark-dark`, `mark-mono`, `mark-white` · SVG and PNG | App, presentation and small branding |
| Horizontal wordmark | `wordmark-light`, `wordmark-dark`, `wordmark-mono`, `wordmark-white` · SVG and PNG | Headers, reports, deck |
| Stacked wordmark | `stacked-light` · SVG and PNG | Portrait placements |
| App icon | `app-icon-light`, `app-icon-dark`, `app-icon-tinted` · SVG and 1024px PNG | Opaque native icon tiles |
| Android adaptive foreground | `adaptive-foreground` · SVG and transparent PNG | Foreground inside adaptive safe area |
| Android themed icon | Native `sakshi_monochrome.xml` | System-tinted launcher |
| Favicon | 16/32/48px PNG and theme-aware SVG in `app/web/` | Browser tabs |
| Windows icon | `app-icon-windows.ico` | Seven resolutions, 16–256px |
| Brand overview | `brand-board` · SVG and PNG | Review/handoff |

The Flutter mark painter, native vector, and exported images share the same geometry. Rebuild exports using `app/tool/build_brand.mjs` with Node and `sharp` available. Keep the wordmark editable; vector text references Segoe UI/Arial while the app continues to use its bundled Inter font.

Minimum suggested mark size: 24px for general UI; the favicon uses its dedicated raster exports below that size. Preserve approximately one observation-dot diameter of clear space around the mark. Use monochrome/white variants where colour reproduction is restricted. Keep proportions and the dot/beam relationship intact.

## Where the brand is applied

- **Flutter:** new finite launch animation and welcome mark. System light/dark preference selects the existing app themes, with corresponding mark colours and readable dark accents.
- **Launch animation:** the beam settles, the eye draws and the observation dot appears. It finishes after 1,400ms; reduced motion skips it. It never waits for an insole connection.
- **Android:** all launcher densities, adaptive foreground/background, dedicated monochrome vector, pre-Android-12 splash and Android-12+ splash, including dark launch resources.
- **iOS:** existing launcher sizes plus dark/tinted 1024px variants; light/dark launch images and background colour asset.
- **Web:** name, description, favicon, normal and maskable PWA icons.
- **Windows:** launcher/resource ICO.

iOS and Windows assets are supplied and referenced, but those platform builds are not verified by the Android/web build checks on this laptop. Check their appearance on the actual target platforms before distribution. No Liquid Glass/Icon Composer asset is claimed.

## Real photographs

Two real internet photographs are bundled locally. They illustrate practising balance; they do not depict our prototype, a school pilot, an official assessor or a verified trial. They remain available without internet access during a demonstration.

| Local file | Creator and source | App placement |
| --- | --- | --- |
| `app/assets/photos/balance-park.jpg` | RDNE Stock project, [Man In Tree Pose](https://www.pexels.com/photo/man-in-tree-pose-8173505/) | Summary action card |
| `app/assets/photos/tree-pose.jpg` | RAY LEI, [Woman Doing a Yoga Tree Pose in a Park](https://www.pexels.com/photo/woman-doing-a-yoga-tree-pose-in-a-park-13849259/) | Welcome card |

Source: [Pexels licence](https://www.pexels.com/license/), checked for these photo uses. Images are delivered through Pexels' image service at a bundled 900px width; crops are performed by Flutter's display layout. Credit links are preserved here. No photographed person is presented as endorsing Niva Sakshi.

## Live foot-map behaviour

The view restores `assets/images/feet.png`, the reference illustration already used by the earliest Niva Flutter dashboard. Although it is an image asset, it is an illustration rather than a photograph. Its existing provenance is inherited from that project.

- The compact view displays only the measured left outline by clipping the source image in the UI. It never copies measurements onto the other foot.
- Four heat zones retain the original source coordinates: toe `(0.34, 0.11)`, inner forefoot `(0.34, 0.33)`, outer forefoot `(0.14, 0.37)`, heel `(0.34, 0.80)`.
- Each zone's colour and intensity follow its current sensor share. The scale runs blue → cyan → yellow → coral. The labelled percentages remain readable alongside the image.
- Firmware contact bits draw rings at the corresponding sensor positions.
- Only a connected, valid stream shows heat or percentages. Disconnected/invalid states show the reference image and dashes without active heat.
- Tapping the map opens a larger view. It subscribes to the same telemetry provider, so changing readings and loss of validity continue to update while the sheet is open.
- These are relative FSR readings. They do not establish force, calibrated pressure or a dense pressure field between the four sensor locations. The detail view explains that distinction.

The live map does not require the timing metric's 12-contact gate; relative sensor readings retain their existing connected/valid gate. Cadence/contact timing still require firmware events and the contact-count gate.

## UI previews and evidence

Refreshed previews live in `docs/previews/`. `heatmap-scripted.png`, `heatmap-dark-scripted.png` and `heatmap-expanded-scripted.png` are rendered with explicitly labelled scripted sensor values for UI review. They are not live hardware evidence. The product itself gains no simulator or fabricated measurements.

Tests cover default-phone fit and the expanded map continuing to respond to validity/connection changes. Final release-check results are recorded in [UI-REDESIGN.md](UI-REDESIGN.md). Real phone/insole testing, native launcher checks and filmed physical evidence remain open in [REMAINING-TASKS.md](REMAINING-TASKS.md).

## Platform references

- [Apple app-icon asset catalog guidance](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
- [Apple app-icon design guidance](https://developer.apple.com/design/human-interface-guidelines/app-icons/)
- [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
