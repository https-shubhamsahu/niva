# R2b: full-cohort extension of R2, analysis plan

Protocol v2, 21 November 2026. Commit this file and the runner before any file of
participants 014 to 150 is downloaded or opened. It extends
[R2_sampling_plan.md](R2_sampling_plan.md) (protocol v1, 12 September 2026), which stays
in force wherever this file does not say otherwise.

## What is already known, stated plainly

- The v1 cohort (participants 002 to 013) was run on 12 September 2026. Its outcomes are
  known and are in `docs/r2/run_20260912T161228Z/`.
- On 21 November 2026 two additions were made on those 12 participants after their
  outcomes were known: scale descriptors, and a re-run with 14.7 mm discs.
- This extension was decided on 21 November 2026, after those outcomes were seen and
  after reading that the target journal asks for a sample-size justification and rejects
  studies it judges too small. The reason for the extension is the sample size.
- The method was fixed before any of this. The metric code is used unchanged.
- At the time of writing, no pressure file and no metadata file of participants 014 to
  150 has been downloaded or opened. Of `participant_metadata.csv`, only the header row
  has been read.

## Question and scope

Unchanged: describe how much recorded contact area and load the repository's five fixed
sparse layout models observe on StepUP pressure fields, how often a disc contains the
pressure peak, and how far the sparse centre of pressure lies from the full-map centre of
pressure. The study is descriptive. No hardware change and no clinical inference follows.

## Cohort

- All participants in the dataset except participant 001: IDs 002 to 150, which is 149
  people. Participant 001 remains reserved for setup, as in v1.
- No participant is excluded for any characteristic, including the injury, assistive
  device, musculoskeletal and other-condition fields. v1 took everyone, and so does v2.
- No participant is excluded because of an outcome.
- Conditions BF and ST at speed W1, Pipeline 1 files, the eligibility rules, and the
  first 12 eligible footsteps per side are exactly as in v1.
- A trial whose file is missing, fails its published checksum, or fails the loader's
  shape, step-ID or identity checks is recorded with the reason and left out. It is never
  repaired.
- A participant and condition with fewer than 12 eligible steps on either side is left
  out of that condition's summaries and logged, as in v1.
- The number of contributing participants can therefore differ between BF and ST. Both
  numbers are reported.

## Sets reported

1. **All (primary):** every contributing participant from 002 to 150.
2. **New:** contributing participants from 014 to 150. None of them was analysed before.
3. **First:** participants 002 to 013, the v1 cohort.

"New" and "First" are shown side by side. No test is made between them.

## Frozen method

`tools/r2_study.py` and `tools/r2_data.py` must have the SHA-256 values recorded in the
v1 provenance file. The v2 runner uses only these v1 functions: `load_trial`, `select`,
`bounds`, `centres`, `discs` and `measure`. Layout coordinates, the 5 mm pitch, the
12.7 mm disc, the 32 by 32 subgrid, the 2 % contact threshold and all eight step-level
outcomes are those of v1.

Aggregation is as in v1: mean of the 12 steps of a side, then mean of the two sides,
giving one value per participant, condition and layout. The v2 runner has its own
aggregation code, because the v1 code is tied to the v1 participant list. It is covered
by fixture tests and by the consistency checks below.

## Additions in v2, all declared here before the new data are opened

1. **Spread and precision.** For each set, condition and layout: number of participants,
   mean, standard deviation, minimum, maximum, and a 95 % confidence interval for the
   mean from the t distribution with participants as units. The interval describes the
   precision of the mean for volunteers like those in this dataset. It is not a claim
   about any other population. No hypothesis test is made.
2. **Disc size sensitivity.** Every outcome is also computed with 14.7 mm discs. The
   12.7 mm result is primary.
3. **Scale descriptors.** Per participant and condition: mean loaded contact area per
   stance sample, and bounding-box length and width.
4. **Participant characteristics.** From `participant_metadata.csv`, for contributing
   participants: counts by the `Sex` field and by the `BFType` field, and mean, standard
   deviation and range of `Age`, `Weight (Kg)` and `Height (cm)`. Missing values are
   counted, not filled in.
5. **Description by sex.** Area observed and load observed with 12.7 mm discs are also
   given separately for each value of the `Sex` field, with the number of participants.
   This is description only, with no test, added because the journal asks authors to
   address sex in studies of people.
6. **Automatic orientation check**, described below.

Nothing else is added. No outcome, layout, threshold or exclusion is changed.

## Checks before any outcome is computed

**Inputs.** Every downloaded file must match the SHA-256 value in the repository's
publication-level `checksum_info.json`.

**Automatic orientation check.** For every selected footstep, take the row coordinate of
the full-map centre of pressure, averaged over stance samples 5 to 15 and over stance
samples 85 to 95, and subtract the second from the first. In an upright footstep the
load moves from heel (high row index) to toe (low row index), so the difference is
positive. The pass threshold is a difference above 5 cells. It was set on participants
001 to 013 only, whose 600 selected steps ranged from 15.05 to 48.41 cells. A failing
step is flagged and listed. It is not removed, because selection is fixed above. If the
flags show a structural orientation or labelling failure, the run stops and the failure
is documented. The method is not tuned.

**Contact sheets.** Mean pressure maps of the selected steps, per participant, condition
and side, are drawn before outcomes are computed, at a size where the big-toe side is
legible without shoes. They are inspected for upright orientation and for agreement of
the left and right labels. The inspection is recorded with the hashes of the sheets, of
the selection audit and of the orientation check. The record states who or what looked.

## Consistency checks at run time

The run stops, and writes no results, unless:

- every 12.7 mm step record of participants 002 to 013 equals the stored v1 record in
  `docs/r2/run_20260912T161228Z/steps.json` to within 1e-9;
- the 14.7 mm summary of participants 002 to 013 equals
  `docs/r2b/reference/sens147_first12.json` to within 1e-9;
- the scale descriptors of participants 002 to 013 equal
  `docs/r2b/reference/posthoc_first12.json` to within 1e-9.

## Reporting rules

- Report the counts actually retained and every trial or participant left out, with the
  reason.
- Results are written to a new timestamped folder under `docs/r2b/`. Nothing under
  `docs/r2/` is changed.
- Any change made after the outcomes of the new participants are seen is labelled as a
  deviation, with the original results kept.
- The interpretation boundaries of v1 hold: walkway pressure is not in-shoe pressure,
  the layouts are assumed coordinates, count and placement change together, and BF is
  not a lower bound for in-shoe coverage.
- The poster and deck result frames stay untouched.

## Commands

```bash
python3 tools/test_r2b_study.py
python3 tools/r2b_study.py download
python3 tools/r2b_study.py qa
# inspect the sheets, then record the review in docs/r2b/qa_review.json
python3 tools/r2b_study.py run
```

`run` requires this plan and the runner to be committed and unchanged, the v1 code to be
unchanged, the inputs to match their checksums, and a reviewed quality-check record that
matches the current inputs and selection.

## Sources

- Dataset and licence: https://doi.org/10.20383/103.01285 (CC BY 4.0).
- Data descriptor: https://doi.org/10.1038/s41597-025-05792-1
- Protocol v1 and its run: `docs/R2_sampling_plan.md`, `docs/r2/README.md`.
