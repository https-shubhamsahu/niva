# Niva: three projects, one insole

This repository holds three separate projects built on the same insole hardware. Each has its own folder, goal and rules. Do not carry claims, framing or materials from one into another unless this page says they are shared.

```text
niva/
├── startup/      Niva as a product: mobile app, web dashboard, insole firmware
├── aavishkar/    Aavishkar 2026–27 research entry (brief: aavishkar/AGENTS.md)
├── sih-26213/    SIH 2026, problem statement 26213 (Fit India balance tests)
└── media/        Shared visual material for all three: photos, logos, 3D CAD and renders, video scripts
```

| | [Startup](startup/README.md) | [Aavishkar 2026–27](aavishkar/README.md) | [SIH 2026, PS 26213](sih-26213/README.md) |
|---|---|---|---|
| **What it is** | Niva as a product and company | Research entry, Engineering & Technology, UG | Hackathon idea, AICTE MIC Student Innovation, Hardware, Fitness & Sports |
| **Question** | What do people need from the insole, and what can we ship? | What can a cheap sparse sensor array observe, how fast does it degrade, and can it report its own loss of validity? | Can the insole measure the Fit India balance tests that are scored by stopwatch and eye today? |
| **Rules** | No clinical claims; numbers need a source | [aavishkar/AGENTS.md](aavishkar/AGENTS.md), unchanged | [sih-26213/README.md](sih-26213/README.md) |

## Shared by all three

- **Hardware:** four FSR402 sensors (heel, inner forefoot, outer forefoot, toe), an MPU6050 IMU, a 27 mm heel piezo disc and an ESP32.
- **Firmware:** `startup/niva arduino/`. A change there reaches all three projects, so record which project asked for it. The contact-event detector added on 1 October 2026 was for SIH26213 and the app. It adds fields and leaves existing ones unchanged.
- **Visual media:** `media/`. Nothing in it is deleted. Builds keep their own resized copies.
- **Rules that hold everywhere:**
  - never invent a number;
  - never make a diagnosis or treatment claim;
  - label real photos, CAD renders and concept images as what they are.

The Aavishkar-only rules (no added sensors, no ML classifier, sensor count as the independent variable) bind Aavishkar only. The startup and SIH decide those questions for themselves.

`_Active_Projects/` holds unrelated projects that happen to sit inside this folder. It is not part of Niva.
