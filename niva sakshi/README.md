# Niva Sakshi

A Flamingo balance-test station for the SIH26213 project. Sensors flag observations, the teacher confirms or dismisses them, and the record preserves both. The existing insole and app work are distinct from the proposed beam/hub hardware, which still needs physical construction and validation.

This folder is a local working copy of the Niva app and firmware. Sakshi work stays here, separate from `startup/` and `aavishkar/`. It is not a remote GitHub fork.

- `app/`: Flutter app, compact Summary/Tests/Live/Device experience, role choice, test runner, trial history/export, roster, practice and Witness record.
- `firmware/`: copied insole firmware and beam detector work; physical beam transport is still pending.
- `docs/`: final submission PDF, portal text, research dossier, UI design screens (`ui-design/`), brand assets, app previews and the task checklist. The deck-building tooling was removed on 3 Oct 2026 after the final deck was made.

**Web version:** https://niva-sakshi.vercel.app (PC and phone; insole sessions run in the Android app). A clearly labelled demo mode plays a simulated walk on the Live tab; it is never saved or used in assessments.

[Complete remaining tasks](docs/REMAINING-TASKS.md) · [Design and verification](docs/UI-REDESIGN.md) · [Earlier task history](TASKS.md)

Never invent measurements or clinical claims. Label rendered UI previews separately from real-device evidence. Physical phone/insole testing and agreement measurements remain pending.
