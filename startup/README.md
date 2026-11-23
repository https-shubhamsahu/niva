# Niva startup

Niva as a product. These are the apps and the insole firmware. The other two projects use them too: SIH26213 runs on the app's Test mode, and Aavishkar runs on the firmware. See [../PROJECTS.md](../PROJECTS.md).

| Folder | Contents |
|---|---|
| `niva flutter/` | Mobile app: Today (validity and contact timing), Tests (Fit India balance tests), Trends, Device |
| `niva web/` | Web dashboard and WebSocket relay; deployed to GitHub Pages |
| `niva arduino/` | ESP32 firmware for the insole. It is shared by all three projects, so record which project each change is for. |

The rules for every project: never invent a number, and never make a diagnosis or treatment claim.

Shared photos, logos and CAD are in [../media/](../media/).
