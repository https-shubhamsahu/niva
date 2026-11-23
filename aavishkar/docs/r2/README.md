# R2 study record

The declared subset run is complete. Start with
[the results](run_20260912T161228Z/results.md) and
[the sampling plan](../R2_sampling_plan.md).

The protocol was committed as `799f322ec30417475408307313fab0d774d1d366`
before cohort outcomes. The implementation and inspected QA were committed as
`458b748` before the run. No method changes were made after the cohort outcomes
were produced. Participant 001 was used for setup; its earlier execution-check
table is invalid and superseded. The cohort is the predeclared IDs 002–013.

## Orientation and scale

[Setup mean pressure maps](orientation_001.png) show both feet mixed and separated
using source metadata. Toes are at low row indices and heels at high indices;
the medial edge is at low column indices for Right and high indices for Left.
The analysis mirrors sensor positions for Left. The inspected
[BF](qa_BF.png) and [ST](qa_ST.png) cohort contact sheets retain that orientation.

The NPZ has no embedded pitch field. The source instrument and the authors'
Pipeline 1 code establish a preserved 5 mm spatial pitch; the setup footprint
dimensions also match trial metadata. Pipeline 1 is time-normalized and spatially
padded. The analysis uses footprint bounds for placement, without interpreting
padding as foot area or normalized phase samples as raw recording time.

## Scope and audit

The saved selection audit contains 576 selected footsteps, 183 excluded footsteps,
and 1,466 later eligible footsteps beyond the fixed per-side quota. All planned
participant-condition-side groups supplied 12 eligible steps. Exclusion flags can
overlap and must not be summed as counts of distinct excluded footsteps.

Each selected step has 101 loaded normalized phase frames in this run. The output
contains 2,880 step-layout records and 120 participant-condition-layout records.
Checks verified quotas, metric bounds, force accounting, phase counts and equal
participant aggregation. Five independent geometry/selection fixture tests passed
before the cohort run; their generated arrays are software tests, never evidence.

Downloaded inputs total 118,463,346 bytes according to inputs.json. All input
SHA256 values match FRDR's publication-level `checksum_info.json`, generated
20 May 2026. The older submitted checksum text file dates to June 2025 and has
stale NPZ hashes. No checksum check was bypassed. The current manifest's own
hash is recorded for every input.

The retained outputs are:

- `run_20260912T161228Z/results.md`: human-readable findings and limitations.
- `run_20260912T161228Z/steps.json`: individual step/layout metrics.
- `run_20260912T161228Z/participants.json`: equal-side participant means and
  descriptive step-level load-bias limits.
- `run_20260912T161228Z/summary.json`: equal-participant condition summaries.
- `run_20260912T161228Z/selection.json`: selection and exclusion decisions.
- `run_20260912T161228Z/provenance.json`: source URLs, hashes, plan/code commits,
  software versions, fixed geometry and the reviewed QA record.

These results describe assumed layout coordinates on a walkway reference.
Actual Niva sensor coordinates and in-shoe performance remain **to be measured**.
The ST condition measures shoe-outsole-to-floor pressure. BF is not established
as a conservative lower bound on in-shoe coverage. No poster or deck result
frame has been populated.

## Reproduce

Use Python with NumPy. Matplotlib is needed for the scientific heatmaps only.
This workspace has a local plotting dependency directory at `data/r2-python`;
the R2 scripts detect it. The analysis itself uses NumPy.

```powershell
python tools/test_r2_study.py
python tools/r2_study.py download
python tools/r2_study.py qa
# Inspect both generated sheets and record the review in docs/r2/qa_review.json.
python tools/r2_study.py run
```

In the current Codex desktop environment, the Python executable used was:

```text
C:\Users\shubh\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe
```

The runner checks that the plan and analysis implementation are committed and
unchanged and that QA corresponds to current input and selection hashes. Each
completed run receives a new timestamped directory, preserving older results.
`sensor_placement_study.py --demo` remains a legacy prototype demonstration;
its previous NPZ-flattening path now directs users to this audited workflow.

Dataset: Larracy et al. (2025), [StepUP-P150](https://doi.org/10.20383/103.01285),
CC BY 4.0. See the plan for the source preprocessing-code revision.
