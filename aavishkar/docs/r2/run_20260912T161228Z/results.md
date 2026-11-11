# R2 declared subset results

Computed layout-model observability on recorded StepUP pressure fields.
Physical Niva sensor coordinates and actual in-shoe performance: **to be measured**.

Selection: 576 footsteps across 12 planned participants,
IDs 002–013; BF and ST at preferred speed W1. Twelve eligible steps per
side and condition were targeted. Participant 001 was setup-only.

Protocol: [committed sampling plan](../../R2_sampling_plan.md).
Exact inputs, code and plan revisions are in [provenance.json](provenance.json).

Means below give each participant equal weight after step and side aggregation.
Bracketed values are observed participant ranges, not confidence intervals.

| Condition | Layout model | Participants | Area observed % | Load observed % |
|---|---|---:|---:|---:|
| BF | niva4 | 12 | 3.55 [2.76, 4.25] | 3.90 [2.78, 4.50] |
| BF | niva6 | 12 | 5.03 [4.25, 5.69] | 4.89 [3.95, 5.39] |
| BF | published8 | 12 | 6.06 [4.91, 6.51] | 6.06 [4.80, 6.83] |
| BF | recommended13 | 12 | 8.99 [6.95, 10.43] | 8.64 [6.12, 10.48] |
| BF | ciniglio16 | 12 | 11.62 [10.12, 13.66] | 13.02 [11.39, 16.31] |
| ST | niva4 | 12 | 2.18 [1.66, 2.81] | 2.09 [1.31, 2.88] |
| ST | niva6 | 12 | 3.30 [2.69, 4.02] | 2.92 [1.94, 3.89] |
| ST | published8 | 12 | 3.83 [3.08, 4.53] | 3.10 [2.16, 4.12] |
| ST | recommended13 | 12 | 6.11 [5.20, 7.14] | 5.46 [4.63, 6.29] |
| ST | ciniglio16 | 12 | 8.20 [6.96, 9.62] | 8.22 [6.77, 10.71] |

| Condition | Layout model | Peak-centre hit % | AP CoP MAE mm | ML CoP MAE mm | Undefined CoP % |
|---|---|---:|---:|---:|---:|
| BF | niva4 | 3.76 [1.32, 7.63] | 16.49 [11.68, 22.74] | 8.94 [6.27, 11.42] | 2.92 [1.69, 4.37] |
| BF | niva6 | 4.01 [2.68, 7.63] | 14.74 [11.59, 19.56] | 8.30 [6.44, 9.93] | 2.87 [1.57, 4.37] |
| BF | published8 | 6.04 [2.06, 9.24] | 19.54 [14.04, 28.40] | 7.46 [5.63, 8.73] | 2.45 [1.32, 3.88] |
| BF | recommended13 | 6.84 [3.05, 12.33] | 12.57 [7.17, 23.10] | 6.21 [4.61, 8.19] | 0.75 [0.12, 2.27] |
| BF | ciniglio16 | 10.68 [7.84, 15.92] | 7.06 [5.81, 8.34] | 4.81 [3.72, 6.19] | 0.90 [0.33, 1.86] |
| ST | niva4 | 1.21 [0.08, 3.34] | 27.16 [18.09, 40.44] | 10.47 [6.52, 15.60] | 9.98 [8.04, 11.55] |
| ST | niva6 | 1.23 [0.08, 3.67] | 21.43 [14.52, 30.74] | 8.93 [4.88, 12.85] | 9.79 [7.92, 11.55] |
| ST | published8 | 0.87 [0.17, 1.77] | 27.19 [17.92, 36.16] | 9.39 [5.28, 13.31] | 9.01 [7.34, 10.85] |
| ST | recommended13 | 4.21 [1.03, 8.54] | 9.27 [6.79, 12.37] | 6.44 [5.11, 7.73] | 3.85 [1.65, 6.89] |
| ST | ciniglio16 | 7.94 [1.77, 20.50] | 10.10 [7.91, 13.12] | 5.10 [4.27, 6.27] | 3.90 [2.81, 5.36] |

CoP errors are conditional on nonzero sparse signal; undefined rates are
reported separately, and those missed frames remain in coverage denominators.
Peak capture tests recorded sensel centres and handles tied maxima. Fractional
peak-sensel overlap is included in the machine-readable outputs.

Load bias is observed load minus full-map load as a percentage of full-map
load, without calibration fitted on these data. Per-participant descriptive
step-level limits are in participants.json. They do not validate agreement
of a calibrated whole-foot force measurement.

All records, including excluded steps and steps after the first twelve, are
retained in selection.json. See steps.json for all per-step metrics.

## Limits on interpretation

This is an administrative subset, without a population sampling or power claim.
Layouts use assumed footprint-relative coordinates; their legacy names do not
establish fidelity to hardware or published sensor configurations. Count and
position change together. Discs integrate piecewise-constant source sensels,
and the contact threshold is an operational analysis choice. Pipeline 1
preserves spatial pitch but rotates with nearest-neighbour sampling and
normalizes time to stance phase. Frames are repeated observations.

BF records foot/sock-to-floor contact; ST records outsole-to-floor contact.
Neither measures the foot-insole interface. Transfer to actual in-shoe
coverage, including its direction of bias, is **to be measured**. No lower
bound on in-shoe performance is claimed. No poster or deck result was changed.

Dataset: Larracy et al. (2025), [StepUP-P150](https://doi.org/10.20383/103.01285),
CC BY 4.0. [Data descriptor](https://doi.org/10.1038/s41597-025-05792-1).
