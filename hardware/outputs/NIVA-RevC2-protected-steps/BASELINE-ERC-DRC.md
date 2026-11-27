# Baseline ERC and DRC, all boards (Rev C.1 as committed), 3 November 2026

**Tool:** kicad-cli 10.0.7. ERC was run with `--severity-all`; DRC with `--severity-all --schematic-parity`. The board files were only read, never saved.

**Library setup:**
- The stock KiCad global symbol and footprint tables were supplied through a temporary `KICAD_CONFIG_HOME` (copied from `/usr/share/kicad/template/`), which matches the "default global libraries" condition in `STATUS.txt`.
- Without that, this machine has no global library tables. ERC/DRC then add 50–200 "library not in configuration" warnings per board, but still 0 errors.

The reports are in `baseline-erc-drc/` (`.rpt` and `.json` per board).

| Board | ERC errors / warnings | DRC errors | Unconnected | DRC warnings | What the warnings are |
|---|---|---|---|---|---|
| Pod (`NIVA-pod`) | 0 / 1 | 0 | 0 | 13 | ERC: U3 SDx (bidirectional) tied to GND with a PWR_FLAG, reviewed in ELECTRICAL-REVIEW §2. DRC: 3 silk clipped at the antenna edge (module outline), 1 LGA-14 footprint differs from the library copy, 9 MPN/description fields not copied to footprints. **Matches STATUS.txt.** |
| Cartridge strip | 0 / 0 | 0 | 0 | 4 | field mismatches only (F1 MPN; J1–J3 descriptions) |
| Dock | 0 / 1 | 0 | 0 | 4 | USB-C symbol and footprint differ from the KiCad 10 library copies; field mismatches (J1, U1 MPN; J2 description) |
| Insole flex R | 0 / 0 | 0 | 0 | 1 | R1 MPN field not in the footprint |
| Insole flex L | 0 / 0 | 0 | 0 | 1 | same as R |

**Rev C.2 working copy of the pod** (`electronics-C2-working/reports/`), after the J2 and U6 land patterns and the antenna notch:

| ERC errors / warnings | DRC errors | Unconnected | DRC warnings |
|---|---|---|---|
| 0 / 1 (same as C.1) | 0 | 0 | 12: 2 silk-at-edge, 1 LGA-14 library copy, 9 field mismatches |

Passing ERC and DRC is an automated check, not a design review.
