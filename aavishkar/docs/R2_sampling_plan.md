# R2 sampling and analysis plan

Protocol v1, 12 September 2026. Commit this file before running the analysis
cohort. This is a prospective analysis plan following a disclosed setup run,
not an untouched-data preregistration: participant 001 BF/W1 already produced
an invalid execution-check table in the previous session. Those values are
superseded and must not be used as findings. Participant 001 is reserved for
orientation and implementation checks and excluded from the analysis cohort.

## Question and scope

Describe how much recorded contact area and load the repository's fixed sparse
layout models observe on StepUP pressure fields. This initial study uses a
fixed, modest subset; it is not a powered population study or the full P150
cohort. The physical Niva sensor centre coordinates remain **to be measured**.
The model coordinates below are existing design assumptions, not measured
anatomical landmarks or verified reproductions of published layouts. Claims
must say "modelled layout" rather than claiming these are measured Niva
performance. No hardware change or clinical inference follows from this run.

## Sampling fixed before the cohort run

- Participants: IDs 002 through 013 inclusive, in ascending ID order. This
  consecutive administrative subset is chosen for a bounded first study,
  without looking at its coverage outcomes or screening demographics. No
  substitution of subjects based on outcome, missingness or appearance.
- Conditions: BF (barefoot/sockfoot) and ST (standard sneaker), kept separate.
- Speed: W1, preferred walking speed only.
- Source: `py/{ID}/{BF|ST}/W1/pipeline_1.npz`, paired with its `metadata.csv`.
- Per participant, condition and side: first 12 eligible footsteps in
  chronological `(StartFrame, FootstepID)` order. The target of 12 is a design
  choice for this initial study, not a claimed power calculation. Both Left
  and Right required for the participant-condition primary summary.
- Eligibility: metadata `Exclude`, `Incomplete`, `Standing` and `Outlier`
  all zero; known Left/Right side; matching participant/condition/speed;
  nonnegative finite pressure; nonempty footprint; footprint not touching
  the stored canvas boundary. No exclusions for low coverage, large CoP error,
  a missed peak, low sparse load, or all sensors reading zero.
- Validate row count and zero-based FootstepID-to-array correspondence before
  selection. Abort a trial with a mismatch; do not guess the mapping. Missing
  files or insufficient eligible steps are reported; no substitute participants.
  A side with fewer than 12 eligible steps is excluded from primary aggregation
  and logged. Its paired side is also omitted from that condition's primary
  summary. Missing whole trials are recorded and not silently treated as zero.
- Keep all loaded normalized stance frames of selected steps. A zero-total-load
  frame is omitted from denominators because contact coverage is undefined.
  A loaded frame with zero sparse signal stays in coverage and peak denominators;
  its sparse CoP is undefined and its frequency is separately reported.

## Orientation and physical scale

The inspected `docs/r2/orientation_001.png` contains the all-step mean and
separate metadata-labelled Right and Left means. Toes are at low row indices,
heels at high row indices. The hallux/medial side is at low column indices for
Right and high column indices for Left. Preserve the stored image and mirror
sensor columns for Left (`c -> 1-c`). Do not apply metadata Orientation again:
the authors already made Pipeline 1 footsteps upright. Retain side IDs in outputs.

The NPZ contains `arr_0` only; no embedded pitch or side metadata exists.
Scale is established from source provenance, not the old script's default:
the source instrument has a 600 mm tile containing 120 cells along each axis,
hence 5 mm/cell. The authors' Pipeline 1 applies unit-scale rotation, cropping,
padding and translation, without spatial resizing. Thus the 5 mm spatial pitch
is preserved, subject to nearest-neighbour rotation discretization. The setup
trial's first Right and Left footprints occupy lengths of 53 and 55 cells,
respectively, matching their own FootLength metadata. These are contact-map
length checks, not independent anatomical foot-length measurements.

Pipeline 2 resizes footprint length and width and normalizes amplitude; it is
excluded. Cropping or padding alone does not change pitch. Pipeline 1 resamples
time to 101 stance samples: these are normalized phase samples, not independent
100 Hz observations. The prior loader's description of all frames as original
recorded time samples was inaccurate.

## Fixed geometry and metric definitions

Use the existing five layout coordinate sets, frozen in `tools/r2_study.py`:
`niva4`, `niva6`, `published8`, `recommended13`, `ciniglio16`. These are legacy
identifiers only. All output labels identify them as layout models, and none is
represented as an exact published baseline. Count and placement both differ
between sets, so their comparison does not isolate a causal sensor-count effect.

For each footstep, form the bounding box of cells with positive pressure at any
stance phase. Map each fractional sensor coordinate to the first/last occupied
cell centre along that box; retain the physical grid and padded canvas unchanged.
This footprint-relative placement is an explicit model, not anatomical landmark
registration. Use the whole-step box throughout stance; never move sensors per
frame or move them toward a pressure peak.

Nominal active diameter is 12.7 mm, as specified in the project instrument brief.
Represent circular discs by fractional cell overlap, using a fixed 32 by 32
midpoint subgrid per sensel. Use the geometric union for area and load coverage,
so overlapping discs are not counted twice. Cell pressure is assumed uniform
within each source sensel; subgrid integration adds no spatial information.
Verify the numerical circle area against pi times radius squared and symmetry
with analytic/artificial test fixtures before running the cohort.

- Loaded contact cells: pressure at least 2% of that frame's maximum, retaining
  the legacy script's threshold as a fixed analysis choice. This is an operational
  definition, not validated biological contact area. Footprint bounds use positive
  pressure as specified above, independently of this framewise threshold.
- Area coverage: fractional contact area inside the union divided by total
  loaded contact area, averaged across loaded stance frames.
- Load coverage: pressure integrated over the union divided by full-map pressure
  integral, including all positive pressure, averaged across loaded stance frames.
- Peak capture: at least one tied maximum-pressure sensel centre inside any
  physical disc; report the phasewise percentage. Also export the mean overlap
  fraction of tied peak sensels, to expose sensel-level boundary uncertainty.
- CoP error: pressure-area-weighted centroid of individual disc forces at their
  fixed sensor centres versus the full-map centroid, separately AP/ML in mm.
  Compute MAE only on frames with nonzero sparse force and always report the
  undefined-sparse-CoP percentage alongside it. Do not drop these missed frames
  from any coverage measure.
- Load bias: phasewise percentage difference of union-observed force from
  full-map force; no scale fitted against the evaluation data. It is the
  unobserved load, not calibrated whole-foot force agreement. For each
  participant-condition/layout, report mean and descriptive bias +/- 1.96 SD
  across the two sides' step-mean differences; these are step-level descriptive
  limits, not validated device-agreement limits. Do not pool repeated phase
  samples as independent observations or make agreement/clinical claims.

## Aggregation and reporting

Compute each metric per step first, then average 12 steps within side, then
average the two sides within participant-condition. Report across participants
with equal subject weight, separately for BF and ST, as mean and observed
participant range. Export every step metric, every participant mean, selection
and exclusion audit, input SHA256 hashes, code hash and plan commit. Report
counts actually retained and missing. Do not describe a descriptive range as a
confidence interval. No hypothesis tests or general-population confidence claims
are planned for this administrative subset.

Generate cohort pressure-map contact sheets for visual QA before computing
outcomes. Check that both sides remain upright and metadata side labels agree
with anatomy where visible; shod hallux anatomy may be obscured. If a structural
orientation or scale failure is found, stop and document it; do not tune the
method based on outcome magnitude. Any amendment after seeing cohort outcomes
must be identified as such, with the original results preserved.

## Interpretation boundaries

StepUP measures pressure at a floor walkway. BF characterizes foot/sock-to-floor
contact and ST characterizes shoe-outsole-to-floor contact. Neither is a paired
measurement at the foot-insole interface. ST therefore cannot validate Niva's
in-shoe load distribution. There is no established direction or numerical bound
on transfer error. A flatter field does not necessarily increase the fraction
of load under fixed discs: redistribution away from initially captured peaks
can decrease it. Do not call BF a conservative lower bound on in-shoe coverage.

Low or high coverage is accepted as computed. Corrections before this run address
demonstrable definition errors: whole-canvas placement, square patches for discs,
unlabelled mixed feet, silent removal of zero-signal frames, and fitting a load
scale on the evaluation set. These corrections are not tuned to increase coverage.
Measured insole geometry, calibration, endurance and validity-gate performance
remain **to be measured**. Poster and deck result frames stay untouched.

## Sources and reproduction

- Dataset and licence: https://doi.org/10.20383/103.01285 (CC BY 4.0).
- Data descriptor, instrumentation and preprocessing:
  https://doi.org/10.1038/s41597-025-05792-1
- Companion code reviewed at commit `ff40d580779bf0ff78b6d5c4d7d183110f02b41a`:
  https://github.com/UNB-StepUP/StepUP-P150/tree/ff40d580779bf0ff78b6d5c4d7d183110f02b41a/python
  (`normalize_footsteps.ipynb`, Pipeline 1; `load_data.ipynb`, metadata selection).
- Setup source: `data/stepup-p150/001/BF/W1/{pipeline_1.npz,metadata.csv}`;
  local `AGENTS.md` for nominal disc diameter and research constraints.

Commands, using Python with NumPy and Matplotlib available:

```powershell
python tools/r2_study.py download
python tools/r2_study.py qa
python tools/r2_study.py run
```

`run` requires this plan and the runner to be committed and unchanged, and a
reviewed QA record matching the current input hashes. Downloaded data are ignored
by Git; analysis artefacts go to `docs/r2/`. Commit the plan before these commands
produce cohort outcomes. Missing results are written as `to be measured`.
