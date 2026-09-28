# NIVA — vector industrial-design blueprints

Revision A · 28 September 2026

This package translates the user-supplied Claude engineering brief into a dimensioned industrial-design concept. It preserves the bilateral passive insole, shin IMU, protected interconnect, detachable battery, offline phone workflow and bench-first development sequence. NIVA follows the spelling in the supplied engineering document.

## Files

- **NIVA-vector-blueprints-Rev-A.pdf:** six A3 landscape sheets, entirely vector linework and text.
- **01-shin-pod.svg:** front, side, rear and exploded section, proposed envelope and assembly stack.
- **02-insole-sensor-stack.svg:** anatomical sensing map, soft layer section, seal and routing intent.
- **03-footwear-integration.svg:** chappal, sandal and shoe attachment diagrams; barefoot/gumboot fallback.
- **04-battery-and-side-keys.svg:** cartridge removal, charging exclusion, battery envelope and connector keys.
- **05-electronics-and-packaging.svg:** signal architecture, preliminary connector functions and board zoning.
- **06-camp-kit-and-roadmap.svg:** case plan, service parts and development gates.
- **07-full-size-fit-template.svg:** supplementary left/right medium outline at 1:1 on A3.
- **index.html:** local gallery for viewing the drawings. Open alongside the SVG files.

SVG shapes and text remain editable in vector-design applications. These are 2D drawings, not STEP solids, native mechanical CAD, schematics, Gerbers, laser-cut files or mould tooling. Fonts use Helvetica/Arial fallbacks. PDF pages preserve vector content and can be zoomed without raster loss.

## Reading and printing

All dimensions are millimetres. **P** denotes a proposed design target; **V** denotes a limited component dimension checked against the named source. No general manufacturing tolerance is assigned. Views show scales individually; conceptual sections and mechanisms marked NTS must not be measured from the page.

Print A3 at 100%, without “fit to page.” The supplemental outline includes a 100 mm check bar. It is for geometry and fitting discussions only; do not cut production sensor sheets from it. The anatomical positions are explicit design seeds, not measurements from North East Indian users. Small and large sizes must be developed using measured feet rather than uniformly scaling the medium sensing map.

## Deliberate changes and open decisions

1. **Pod envelope:** the original 48 × 34 × 13 mm visual target is replaced by a provisional 60 × 42 × 20 mm custom-PCB target. This reserves space for a rear battery bay and serviceable enclosure; it does not prove component fit. The breakout-board prototype needs its own enclosure sized after actual parts are selected and measured.

2. **Tail reach — hold H1:** the standard A201 is approximately 190.5 mm overall, not 191 mm of usable tail beyond its sensing element. In the proposed medium template the big-toe region is over 200 mm from the heel even before margin routing and an above-collar junction. Stock A201 parts cannot implement the illustrated common-heel topology as assumed in the supplied brief. The dashed paths express design intent. Use stock sensors for bench experiments; a wearable requires a supplier-approved longer/custom flexible sensing assembly or a separately validated routing redesign. No rigid extension joints are permitted underfoot. Custom force sensors are an available supplier category, but no specific custom part has been sourced or qualified.

3. **Rigid junction placement:** move sensor terminations and the insole ID resistor into the protected assembly above the shoe collar, rather than placing a resistor or hard sensor pins inside the insole. Longer passive tails and their resulting noise remain an unresolved development item. The sensor, tail and encoded connector are a paired service assembly.

4. **Battery:** cartridge envelope 28 × 34 × 8 mm is provisional, including protection electronics, recessed contacts and shell. The proposed internal cell envelope is not a sourced cell. The brief's 300 mAh capacity is therefore not guaranteed. Select the cell, allow for swelling and tolerances, and then revise the cartridge and pod together. Runtime is not claimed in these drawings.

5. **Charging exclusion:** the proposed cradle covers the cartridge release; the whole pod cannot enter the charger. This is an intended mechanical exclusion, not an established safety result. Rear access, latches, dock apertures, contacts and thermal faults require physical and electrical testing. Test foreseeable attempts to defeat the arrangement, not only the normal use sequence.

6. **Left/right:** distinct connector and cradle keys prevent crossed assembly. They cannot alone prevent a complete matched assembly being placed on the wrong leg. Retain an anatomical fitting check and an explicit side confirmation in the phone workflow.

7. **Analog electronics:** manufacturer A201 performance is specified with an op-amp circuit. The divider approach in the supplied brief remains a bench option rather than a validated equivalent. The drawing consequently reserves a force analog-front-end zone without freezing resistor values or the final drive topology. Review ADC settling, boot-strapping pins, battery sag/regulator dropout, simultaneous radio use and timing accuracy before schematic release.

8. **Insole construction:** the proposed skin is continuously sealed TPU-faced material; no exposed knit at edges. The 2.8 mm target depends on adhesive, recessed tails and the independent PVDF pocket. Active sensor diameter is not the full sensor footprint. Obtain actual supplier outlines before pocket cutting. No hard load-spreading puck is specified underfoot.

9. **Case:** a proposed 400 × 330 × 115 mm case accommodates the medium insert without folding it across sensors. The insert bay provides about 294 mm in length in this layout. Check the final largest size, oversoles, cable storage and lid depth before tray tooling.

## Sources and provenance

**User source:** “Niva prototype blueprint: from bench insole to health-camp kit,” Claude draft v0.1, dated 28 September 2026, supplied as pasted text. Its unpublished StepUP/R2 results, prices, literature accuracy figures and proposed electrical pin assignments have not been independently verified and are not adopted as proven performance in these drawings.

**S1 — Tekscan, FlexiForce A201:** [manufacturer product specifications](https://www.tekscan.com/products-solutions/force-sensors/a201). Checked 28 September 2026. The drawing uses the published 0.203 mm thickness, 0.375 in / 9.53 mm active diameter and 7.50 in / 190.5 mm standard overall length. The manufacturer recommends an op-amp readout and describes performance under that circuit condition.

**S1a — Tekscan, standard and custom force sensors:** [manufacturer sensor range](https://www.tekscan.com/force-sensors). Supports the availability of custom sensing development in general, not the availability or approval of the proposed long-tail assembly.

**S2 — Espressif, ESP32-C3-MINI-1 / MINI-1U datasheet v2.2:** [manufacturer datasheet](https://documentation.espressif.com/esp32-c3-mini-1_datasheet_en.pdf). Checked 28 September 2026. The module dimension used is 13.2 × 16.6 × 2.4 mm. The shaded RF zone is a reservation, not a validated antenna keepout or RF layout.

## What the engineering team should resolve next

1. Bench-select the force sensor and characterize the assembled soft stack.
2. Obtain full sensor/tail drawings and resolve H1 without hard plantar joints.
3. Select the battery and components; perform a full 3D tolerance and interference check.
4. Validate foot alignment, retention, collar pressure and local pressure distribution using fit models and a suitable test protocol.
5. Test the charging exclusion, cleaning durability, ingress, strain relief and side checks.
6. Only then release detailed CAD, schematic, PCB and manufacturing drawings.

The artwork intentionally does not assert a medical diagnosis, validated knee-load estimate, ingress rating, skin-contact certification, cleaning compatibility, runtime or production cost.
