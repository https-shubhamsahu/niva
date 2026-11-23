# Aavishkar 2026–27

Niva's research entry to the 21st Aavishkar Research Convention (Engineering & Technology, UG). It is a measurement project: the insole is the research instrument, not the result.

**Start with [AGENTS.md](AGENTS.md).** It is the brief and its hard rules, and it governs this folder only. It was moved here on 1 October 2026 without changes.

| Folder | Contents |
|---|---|
| `AGENTS.md` | Agent brief: framing, hard rules, firmware state, design system, figure rules, what is done and what is not |
| `docs/` | Research framework, work package, CDSCO letter, 121-source evidence base, R2 sampling plan and run (`docs/r2/`), approved poster and presentation (`docs/aavishkar/`) |
| `src-visuals/` | Poster and deck sources and renderers |
| `tools/` | R2 study scripts and the sensor-placement study |
| `data/` | StepUP-P150 subset and local Python packages (git-ignored) |
| `convention/` | Aavishkar 2026 poster and presentation templates and guidelines. `WhatsApp Image 2026-09-10 …jpeg` is another team's poster (DermaSense), kept as a format reference only. |

The R2 scripts and the poster renderers find their files relative to this folder, so run them from here, for example `python tools/r2_study.py run`.

## Paths that moved

`AGENTS.md` itself was not edited, so three of its paths still use the old layout:

| `AGENTS.md` says | Now at |
|---|---|
| `niva arduino/niva_hardware/` | `../startup/niva arduino/niva_hardware/` |
| `docs/brand/niva_logo_assets` | `../media/brand/niva_logo_assets` |
| `src-visuals/aavishkar/` | unchanged, relative to this folder |

`src-visuals/aavishkar/README.md` also mentions `docs/brand/niva_logo_assets`, which is now `../media/brand/niva_logo_assets`.

Shared photos, logos and CAD for all three projects are in [../media/](../media/). The firmware is shared with the other two projects and lives in `../startup/niva arduino/`.
