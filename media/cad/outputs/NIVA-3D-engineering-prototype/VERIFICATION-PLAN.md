# NIVA verification plan — sealing, skin contact, cleaning (and the checks they depend on)

**Status: plan only. None of these tests has been run.** This file names what has to be shown before anyone
can say the pod, cartridge, dock or insole is sealed, suitable for skin contact or cleanable. It makes **no**
claims of an IP rating, biocompatibility, disinfectant compatibility or durability. The acceptance criteria
below are proposed engineering targets for a prototype programme. They are not regulatory limits. If NIVA
is ever placed on the market as a medical device, a qualified regulatory and biological-safety review must
replace this plan.

Standards are named only as test **methods** to borrow. Naming a method is not a statement that the design
conforms to it.

## 1. Materials (proposed, to confirm)

| Item | Prototype material (printed or hand-made) | Candidate for skin-contact or wet trials | Contact type |
|---|---|---|---|
| Pod rear housing, front cover, cradle | PETG or ASA, FDM | Injection-moulded PC/PBT or PA12 grade with supplier ISO 10993 data | Indirect (strap and pad between) |
| Soft cradle pad | TPU 85A–95A, FDM | Medical-grade TPU or silicone (LSR) with supplier ISO 10993-5/-10/-23 data | **Prolonged skin contact** (shin) |
| Strap | Commercial 35 mm strap | Silicone or textile strap with supplier skin-contact data; latex-free | **Prolonged skin contact** |
| Seam gasket | Die-cut 0.5 mm silicone or EPDM sheet (TPU print is for fit only) | Silicone 40–50 Shore A, compression-set data at 40 °C | None (internal) |
| Button | TPU, FDM | LSR or TPU membrane moulded or bonded to the cover | Finger |
| Light window | Clear SLA resin | PC or PMMA, bonded | Finger |
| Tail boot | TPU overmould (modelled) | TPU overmould over the cable jacket | Occasional skin (ankle) |
| Cartridge cup and lid | PETG, FDM; lid bonded | PC or PC/ABS, ultrasonically welded | Handling |
| Cartridge contacts | Brass, gold flash (to select) | Gold over nickel. Nickel release is irrelevant only if the plates never touch skin (they sit inside the bay) | None when worn |
| Insole flex | Polyimide, rolled-annealed copper, coverlay, FSR ink film on a spacer | Same, laminated between a top cover and a base foam | **Prolonged skin contact through the sock** (top cover only) |
| Insole top cover | — | Moisture-wicking polyester or PU-coated textile with supplier skin-contact data | Through sock |
| Dock | PETG, FDM | PC/ABS | Handling |

Printed PETG, ASA and TPU prototypes are **not** evaluated for skin contact. For wear trials, either use
materials that have supplier biological-evaluation data, or put a barrier (sleeve or sock) between skin and
printed parts. Record lot numbers for every skin-contact material.

## 2. Sealing

What has to stay dry: the pod's inside (PCB, IMU, ADC). The cartridge bay is open by design. What is sealed
there is the cartridge itself (bonded or welded lid, flush contact plates) and the bay ceiling, which keeps
the PCB out of reach. The dock is a desk accessory and is not sealed. The insole flex is laminated. Sweat and
wash water must not reach the electrodes or the FSR film.

| # | Test | Method (borrowed) | Sample | Proposed acceptance |
|---|---|---|---|---|
| S1 | Gasket compression and stop check | Measure the installed gap at 8 points with feeler gauges or CT; check the boss hard stops touch | 5 assembled pods | Gap 0.35 ± 0.05 mm everywhere; no gasket extrusion |
| S2 | Splash, pod worn orientation | IEC 60529 IPX4 spray/splash procedure | 5 pods, cartridge in, tail boot fitted | No water inside the pod. Moisture-indicator paper inside, 0 marked spots |
| S3 | Dust (optional, outdoor use) | IEC 60529 IP5X talcum chamber | 3 pods | No talc on the PCB side |
| S4 | Artificial sweat soak of seams | Artificial sweat (ISO 3160-2 or EN 1811 recipe), 40 °C, 8 h wet / 16 h dry, 10 cycles | 5 pods | No ingress (indicator paper); gasket compression set < 25 % |
| S5 | Cartridge seal | Submerge a bare cartridge at 0.2 m for 30 min after 50 dock insertions | 5 cartridges | No water in the cup; contact resistance change < 20 mΩ |
| S6 | Tail boot and aperture | 500 flex cycles ±30° at the boot, then S2 | 5 pods | No ingress; jacket not pulled out (pull test 20 N after cycling) |
| S7 | Insole lamination | 40 °C artificial sweat, 24 h, then 10 000 heel-strike cycles (see F2) | 5 insoles per side | No delamination; FSR baseline shift < 10 % of unloaded reading |
| S8 | Insole hand wash (if offered) | 30 °C mild detergent, 5 min, air dry 24 h, 10 cycles | 5 insoles | As S7, plus no visible blistering. If it fails, the insole is "wipe only" |

**No IP code may be written on labels, the app or documents until S2 (and S3 if claimed) pass on production-intent parts.**

## 3. Skin contact

| # | Test | Method (borrowed) | Applies to | Proposed acceptance |
|---|---|---|---|---|
| B1 | Biological evaluation plan | ISO 10993-1 categorisation: surface device, intact skin, contact duration (prolonged, > 24 h cumulative, for daily wear) | Pad, strap, insole top cover, tail boot | Plan written and signed off by a qualified person before any wear trial beyond the team |
| B2 | Cytotoxicity | ISO 10993-5 | Each skin-contact material, finished state (after printing, moulding or lamination) | Supplier or lab data showing a non-cytotoxic result on the actual grade |
| B3 | Sensitisation | ISO 10993-10 | As B2 | Supplier or lab data: no sensitisation |
| B4 | Irritation | ISO 10993-23 | As B2 | Supplier or lab data: non-irritant |
| B5 | Nickel release | EN 1811 | Any metal that can touch skin (strap buckles, screws visible from the leg side) | Below the EN 1811 limit, or no skin-contact metal (preferred) |
| B6 | Pressure under cradle and strap | Thin-film pressure mapping on 10 adult shins at the recommended strap tension, 30 min seated plus 10 min walking | Pod on cradle | Record peak and mean pressure. No marks persisting > 30 min after removal. Target to be set with a clinician before trials |
| B7 | Heat and sweat | Skin temperature under the pad, 30 min walking at 22 °C | Pod | Skin temperature rise < 2 °C over contralateral (proposed) |
| B8 | Insole local pressure | Pressure mapping insole-on-insole with and without the flex, same shoe | Insole | No local pressure peak added over the lanes or tail tab. The flex must not be felt as a ridge (questionnaire) |

Wear trials with people outside the development team need ethics or institutional review as applicable.
This plan does not authorise them.

## 4. Cleaning

Candidate agents (confirm what users and clinics actually use): 70 % isopropyl alcohol wipes, quaternary
ammonium wipes, 0.1 % (1000 ppm) sodium hypochlorite, and mild soap and water.

| # | Test | Method | Sample | Proposed acceptance |
|---|---|---|---|---|
| C1 | Wipe cycles, rigid parts | 500 wipe cycles per agent, 1 min wet contact, dry, repeat. Inspect at 100, 250, 500 | Printed and production-intent coupons plus 3 pods | No crazing, cracking, tackiness or colour change beyond ΔE 3; markings still legible |
| C2 | Soft parts | As C1 on pad, strap, button, tail boot | 3 each | Shore A change < 5; no swelling > 2 % mass |
| C3 | Environmental stress cracking | Agent applied to screw bosses and the latch at assembly strain, 72 h | 3 cradles, 3 rear housings | No cracks (dye penetrant) |
| C4 | Seal after cleaning | Repeat S2 after C1 | 3 pods | As S2 |
| C5 | Insole top cover | 100 wipe cycles per agent, then S7 electrical baseline | 3 insoles | No delamination; baseline shift < 10 % |
| C6 | Dock and cartridge contacts | IPA wipe of the gold pads, 200 cycles | 3 cartridges | Contact resistance change < 20 mΩ; no exposed nickel |
| C7 | Instructions | Draft cleaning instructions from C1–C6 results only | — | Every step traceable to a passed test |

## 5. Checks the above depend on

| # | Check | Why it matters |
|---|---|---|
| F1 | Snap and latch life: cradle latch 1000 cycles, dock latch 2000 cycles, force at 0 / 500 / 1000 | Retention, cracking under cleaning agents (C3) |
| F2 | Insole flex durability: 100 000 heel-strike cycles at 1.5× body-weight pressure on P5, 10 000 90° folds at the heel tab (tail), 5 mm radius | Copper cracking; FSR drift |
| F3 | FSR characterisation: force-resistance curve, hysteresis, drift at 10 min static load, temperature 20–40 °C, per region | **No force or clinical value may be derived from the insole until this exists** |
| F4 | Cell and charger: cell supplier's IEC 62133-2 and UN 38.3 evidence for the exact part; dock charge termination at 4.20 V ± 1 %; NTC window trips measured at 0 °C and 45 °C | Battery safety. The dock's hardware NTC window is designed, not verified |
| F5 | Radio: the ESP32-C3-MINI-1 module certification covers the module only. The finished pod needs its own radiated and EMC assessment (for example ETSI EN 300 328, FCC Part 15) | Antenna next to the shin and battery |
| F6 | Insert ID: every insole reads its code (R-M 0.320, L-M 0.825 of VEXC ± 3 %). The app refuses a mismatched side | L/R safety net behind the mechanical keys |

## 6. Records

Record for each test: sample IDs, material lots, firmware version, date, operator, raw data, photos and
pass/fail against the criteria above. Do not change a criterion after seeing results without writing down
the reason.
