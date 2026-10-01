#!/usr/bin/env python3
"""
sensor_placement_study.py — how much of the plantar pressure map do N sensors see?

Niva ships four FSRs at heel / MT1 / MT5 / hallux. The literature says that is
below the usable floor:

  * Fuchs et al. 2024 (Sensors 24:4918) benchmarked 3-17 sensor layouts against a
    99-sensor Pedar-X and found 8-11 mm ML and 20-22 mm AP centre-of-pressure
    error at <= 9 sensors, concluding "caution is recommended when using insoles
    with nine or fewer sensors" and recommending 11-13.
  * Santos et al. 2024 (Appl Sci 14:6085), reviewing 33 studies, put the
    recommended minimum at fifteen.

This script answers the question empirically on YOUR chosen sensor positions,
using a real high-resolution pressure dataset as ground truth, before you spend
anything on a board revision.

    Recommended input: UNB StepUP-P150
      Larracy et al. 2025, Scientific Data — doi:10.1038/s41597-025-05792-1
      Data: doi:10.20383/103.01285
      240 x 720 sensels at 5 mm (4 sensors/cm^2), 100 Hz, 150 participants,
      200,000+ footsteps, 16 footwear/speed conditions.
      Check the licence at source before any commercial use.

    Also works with any (frames, rows, cols) pressure array saved as .npy,
    or a directory of .npy files. This legacy evaluator is a demo/prototype.
    For StepUP-P150 research analysis use tools/r2_study.py and the committed
    docs/R2_sampling_plan.md; do not flatten away footstep/side metadata.

WHAT IT MEASURES
    1. CoP error      — reconstructed from N sensors vs the full grid, in mm.
    2. Peak capture   — how often the true peak-pressure cell falls within one
                        sensor radius of any sensor. This is hazard H1 in the
                        risk file: a high-pressure region that falls between
                        sensors is a region the device cannot see.
    3. Load agreement — correlation and bias between summed sensor output and
                        true total force, reported Bland-Altman style because
                        correlation alone is the wrong statistic here.

USAGE
    python sensor_placement_study.py --data path/to/frames.npy
    python sensor_placement_study.py --demo          # synthetic, no download
    python sensor_placement_study.py --data d/ --layouts 4,6,8,13,16 --plot out.png

Requires: numpy. matplotlib only if --plot is used.
"""

from __future__ import annotations
import argparse
import glob
import os
import sys
from dataclasses import dataclass, field

import numpy as np

MM_PER_CELL_DEFAULT = 5.0          # StepUP-P150 sensel pitch
FSR402_ACTIVE_DIA_MM = 12.7        # Interlink FSR402 active area
CONTACT_THRESHOLD = 0.02           # fraction of frame max that counts as contact


# ----------------------------------------------------------------------------
# Sensor layouts. Positions are (row_frac, col_frac) in foot coordinates:
#   row 0.0 = toe end, row 1.0 = heel end
#   col 0.0 = medial edge, col 1.0 = lateral edge
# Niva's four positions are taken from the pin map in niva.ino:
#   GPIO32 heel, GPIO33 inner/MT1, GPIO34 outer/MT5, GPIO35 toe.
# ----------------------------------------------------------------------------
LAYOUTS: dict[str, list[tuple[float, float]]] = {
    "niva4": [
        (0.86, 0.50),   # heel        (GPIO32)
        (0.36, 0.28),   # MT1, medial (GPIO33)
        (0.36, 0.76),   # MT5, lateral(GPIO34)
        (0.10, 0.36),   # hallux      (GPIO35)
    ],
    # + midfoot and MT3. Fuchs found midfoot coverage drove the largest single
    # accuracy gain, and Niva currently has no midfoot sensor at all.
    "niva6": [
        (0.86, 0.50), (0.36, 0.28), (0.36, 0.76), (0.10, 0.36),
        (0.60, 0.62),   # lateral midfoot
        (0.36, 0.52),   # MT3
    ],
    # The 8-sensor arrangement used by Morales-Morales et al. 2026
    # (Technologies 14:362) on an ESP32-C3 with a 74HC4051 mux, ~USD 48/pair.
    "published8": [
        (0.88, 0.44), (0.88, 0.62),           # heel medial + lateral
        (0.60, 0.66),                         # midfoot
        (0.38, 0.24), (0.38, 0.40), (0.38, 0.56), (0.38, 0.74),  # MT1-MT5 band
        (0.10, 0.34),                         # hallux
    ],
    # Fuchs et al.'s recommended compromise.
    "recommended13": [
        (0.92, 0.42), (0.92, 0.60), (0.78, 0.50),
        (0.62, 0.30), (0.62, 0.68),
        (0.40, 0.22), (0.40, 0.38), (0.40, 0.52), (0.40, 0.66), (0.40, 0.80),
        (0.16, 0.30), (0.16, 0.50), (0.06, 0.34),
    ],
    # Ciniglio et al. 2021 (Sensors 21:1450): 4 hindfoot, 3 midfoot, 9 forefoot.
    "ciniglio16": [
        (0.94, 0.40), (0.94, 0.62), (0.82, 0.46), (0.82, 0.60),
        (0.64, 0.30), (0.64, 0.52), (0.64, 0.72),
        (0.44, 0.20), (0.44, 0.34), (0.44, 0.48), (0.44, 0.62), (0.44, 0.78),
        (0.28, 0.28), (0.28, 0.48), (0.28, 0.68),
        (0.08, 0.34),
    ],
}


@dataclass
class Result:
    name: str
    n_sensors: int
    cop_ml_mae: float = 0.0
    cop_ap_mae: float = 0.0
    cop_ml_rmse: float = 0.0
    cop_ap_rmse: float = 0.0
    peak_capture_pct: float = 0.0
    area_coverage_pct: float = 0.0
    load_seen_pct: float = 0.0
    load_r: float = 0.0
    load_bias_pct: float = 0.0
    load_loa: tuple[float, float] = (0.0, 0.0)
    n_frames: int = 0
    notes: list[str] = field(default_factory=list)


# ----------------------------------------------------------------------------
def load_frames(path: str) -> np.ndarray:
    """Load pressure maps as (frames, rows, cols).

    Accepts a .npy file or a directory of .npy files for legacy prototypes.
    StepUP requires side, footprint and preprocessing metadata, handled by
    r2_study.py. Pipeline 1 time samples are already phase-normalized.
    """
    if os.path.isdir(path):
        files = sorted(glob.glob(os.path.join(path, "*.npy")))
        if not files:
            raise SystemExit(f"No .npy files found in {path}")
        arrs = [np.load(f) for f in files]
        arrs = [a[None, ...] if a.ndim == 2 else a for a in arrs]
        return np.concatenate(arrs, axis=0)
    if path.lower().endswith(".npz"):
        raise SystemExit(
            "StepUP NPZ flattening was withdrawn after the R2 audit. "
            "Run tools/r2_study.py download, qa, then run, following "
            "docs/R2_sampling_plan.md. Foot side and footprint geometry are required."
        )

    arr = np.load(path)
    if arr.ndim == 2:
        arr = arr[None, ...]
    if arr.ndim != 3:
        raise SystemExit(f"Expected a 2-D or 3-D array, got shape {arr.shape}")
    return arr


def synthesize(n_frames: int = 240, rows: int = 128, cols: int = 48,
               seed: int = 7) -> np.ndarray:
    """
    Synthetic stance-phase pressure maps, for exercising the pipeline only.

    This is NOT a substitute for real data and no result from --demo should
    appear in any report. Di Martino et al. 2025 (arXiv:2505.14206) found
    generative models fail specifically at cross-modal consistency and
    long-horizon temporal structure in wearable sensor data; the same caution
    applies with far more force to a hand-written approximation like this one.
    Use it to check the script runs, then get StepUP-P150.
    """
    rng = np.random.default_rng(seed)
    rr, cc = np.mgrid[0:rows, 0:cols]
    rr = rr / (rows - 1)
    cc = cc / (cols - 1)
    frames = np.zeros((n_frames, rows, cols), dtype=np.float32)

    def blob(r0, c0, amp, sr, sc):
        return amp * np.exp(-(((rr - r0) ** 2) / (2 * sr ** 2) +
                              ((cc - c0) ** 2) / (2 * sc ** 2)))

    for i in range(n_frames):
        t = i / max(1, n_frames - 1)                    # 0 = heel strike, 1 = toe off
        heel = max(0.0, 1.0 - 2.2 * t)
        fore = max(0.0, 1.6 * (t - 0.28))
        toe = max(0.0, 2.0 * (t - 0.62))
        f = np.zeros((rows, cols), dtype=np.float32)
        f += blob(0.88, 0.50 + 0.02 * rng.standard_normal(), 220 * heel, 0.075, 0.16)
        f += blob(0.60, 0.66, 40 * min(heel, fore), 0.10, 0.09)   # lateral midfoot
        # A deliberately off-sensor forefoot hotspot: this is the H1 case.
        f += blob(0.38, 0.47, 260 * fore, 0.045, 0.075)
        f += blob(0.38, 0.26, 150 * fore, 0.045, 0.07)
        f += blob(0.38, 0.74, 130 * fore, 0.045, 0.07)
        f += blob(0.10, 0.36, 190 * toe, 0.045, 0.075)
        f += rng.normal(0, 1.2, (rows, cols)).astype(np.float32)
        frames[i] = np.clip(f, 0, None)
    return frames


# ----------------------------------------------------------------------------
def true_cop(frame: np.ndarray, mm: float) -> tuple[float, float, float]:
    """Full-grid CoP in mm, plus total load. Returns (ap_mm, ml_mm, total)."""
    total = float(frame.sum())
    if total <= 0:
        return (np.nan, np.nan, 0.0)
    rows, cols = frame.shape
    r = np.arange(rows)[:, None]
    c = np.arange(cols)[None, :]
    ap = float((frame * r).sum() / total) * mm
    ml = float((frame * c).sum() / total) * mm
    return (ap, ml, total)


def sensor_indices(layout, rows, cols):
    return [(int(round(fr * (rows - 1))), int(round(fc * (cols - 1))))
            for fr, fc in layout]


def sample_sensors(frame: np.ndarray, idx, radius_cells: int) -> np.ndarray:
    """
    Mean over the sensor's physical active area — a real FSR integrates over its
    contact patch, it does not read a point. Using a single cell would flatter
    the sparse layouts.
    """
    out = np.empty(len(idx), dtype=np.float64)
    rows, cols = frame.shape
    for k, (r, c) in enumerate(idx):
        r0, r1 = max(0, r - radius_cells), min(rows, r + radius_cells + 1)
        c0, c1 = max(0, c - radius_cells), min(cols, c + radius_cells + 1)
        out[k] = frame[r0:r1, c0:c1].mean()
    return out


def sensor_cop(vals, idx, mm) -> tuple[float, float]:
    """CoP reconstructed as the load-weighted centroid of the sensor positions."""
    s = vals.sum()
    if s <= 0:
        return (np.nan, np.nan)
    ap = sum(v * r for v, (r, _) in zip(vals, idx)) / s * mm
    ml = sum(v * c for v, (_, c) in zip(vals, idx)) / s * mm
    return (ap, ml)


def evaluate(frames: np.ndarray, name: str, layout, mm: float,
             sensor_dia_mm: float) -> Result:
    n_f, rows, cols = frames.shape
    idx = sensor_indices(layout, rows, cols)
    radius = max(0, int(round((sensor_dia_mm / 2.0) / mm)))
    res = Result(name=name, n_sensors=len(layout))

    d_ml, d_ap, caps, s_tot, t_tot = [], [], [], [], []
    cover, seen = [], []

    # Boolean mask of everything any sensor physically covers. Fixed geometry,
    # so it is computed once rather than per frame.
    mask = np.zeros((rows, cols), dtype=bool)
    for r, c in idx:
        r0, r1 = max(0, r - radius), min(rows, r + radius + 1)
        c0, c1 = max(0, c - radius), min(cols, c + radius + 1)
        mask[r0:r1, c0:c1] = True

    for f in frames:
        t_ap, t_ml, total = true_cop(f, mm)
        if not np.isfinite(t_ap) or total <= 0:
            continue
        if f.max() <= 0:
            continue

        vals = sample_sensors(f, idx, radius)
        s_ap, s_ml = sensor_cop(vals, idx, mm)
        if not np.isfinite(s_ap):
            continue

        d_ap.append(s_ap - t_ap)
        d_ml.append(s_ml - t_ml)

        # Peak capture: is the true peak cell within one sensor radius of any sensor?
        pr, pc = np.unravel_index(int(np.argmax(f)), f.shape)
        if f[pr, pc] >= CONTACT_THRESHOLD * f.max():
            near = any((abs(pr - r) <= radius and abs(pc - c) <= radius) for r, c in idx)
            caps.append(1.0 if near else 0.0)

        # Coverage: of the cells actually in contact this frame, what fraction
        # sits under a sensor — and what fraction of the total load do they hold?
        contact = f >= CONTACT_THRESHOLD * f.max()
        n_contact = int(contact.sum())
        if n_contact > 0:
            cover.append(100.0 * float((contact & mask).sum()) / n_contact)
            seen.append(100.0 * float(f[contact & mask].sum()) / total)

        s_tot.append(float(vals.sum()))
        t_tot.append(total)

    if not d_ap:
        res.notes.append("no valid frames")
        return res

    d_ap = np.asarray(d_ap); d_ml = np.asarray(d_ml)
    res.n_frames = len(d_ap)
    res.cop_ap_mae = float(np.abs(d_ap).mean())
    res.cop_ml_mae = float(np.abs(d_ml).mean())
    res.cop_ap_rmse = float(np.sqrt((d_ap ** 2).mean()))
    res.cop_ml_rmse = float(np.sqrt((d_ml ** 2).mean()))
    res.peak_capture_pct = 100.0 * float(np.mean(caps)) if caps else float("nan")
    res.area_coverage_pct = float(np.mean(cover)) if cover else float("nan")
    res.load_seen_pct = float(np.mean(seen)) if seen else float("nan")

    s = np.asarray(s_tot); t = np.asarray(t_tot)
    if s.std() > 0 and t.std() > 0:
        res.load_r = float(np.corrcoef(s, t)[0, 1])
    # Bland-Altman on percentage difference against a scale-matched sensor sum.
    scale = t.mean() / s.mean() if s.mean() != 0 else 1.0
    diff_pct = 100.0 * (s * scale - t) / t
    bias = float(diff_pct.mean()); sd = float(diff_pct.std(ddof=1))
    res.load_bias_pct = bias
    res.load_loa = (bias - 1.96 * sd, bias + 1.96 * sd)
    return res


# ----------------------------------------------------------------------------
def report(results: list[Result], demo: bool) -> None:
    print()
    print("=" * 96)
    print("SENSOR PLACEMENT STUDY".center(96))
    if demo:
        print("*** SYNTHETIC DEMO DATA — NOT A RESULT. Do not put these numbers "
              "in any report. ***".center(96))
    print("=" * 96)
    hdr = (f"{'Layout':<16}{'N':>4}{'CoP ML':>10}{'CoP AP':>10}"
           f"{'Area seen':>12}{'Load seen':>12}{'Peak hit':>11}"
           f"{'Load bias':>12}{'95% LoA':>21}")
    print(hdr)
    print("-" * 96)
    for r in results:
        loa = f"{r.load_loa[0]:+.0f} to {r.load_loa[1]:+.0f}%"
        print(f"{r.name:<16}{r.n_sensors:>4}{r.cop_ml_mae:>8.1f}mm"
              f"{r.cop_ap_mae:>8.1f}mm{r.area_coverage_pct:>11.1f}%"
              f"{r.load_seen_pct:>11.1f}%{r.peak_capture_pct:>10.1f}%"
              f"{r.load_bias_pct:>11.1f}%{loa:>21}")
    print("-" * 96)
    print(f"{results[0].n_frames} frames evaluated per layout.")
    print()
    print("HOW TO READ THIS")
    print("  CoP MAE      Fuchs et al. 2024 measured 8-11 mm ML and 20-22 mm AP at")
    print("               <=9 sensors against a 99-sensor reference, and advised")
    print("               against publishing CoP below that count. Compare directly.")
    print("  Area seen    Percentage of the loaded contact area that physically sits")
    print("               under a sensor. This is the hard geometric limit — pressure")
    print("               outside it is invisible to the device no matter how good the")
    print("               firmware is. Hazard H1 (false reassurance) in the risk file.")
    print("  Load seen    Share of total load falling under a sensor. Higher than area")
    print("               coverage when sensors sit on the peaks, which is the point of")
    print("               placing them at heel, metatarsal heads and hallux.")
    print("  Peak hit     How often the single highest-pressure cell fell under a")
    print("               sensor. Low values mean the device routinely misses the very")
    print("               region a diabetic-foot claim depends on seeing.")
    print("  Load r/bias  High correlation with large bias is the normal case, not a")
    print("               contradiction: a commercial insole with 100x the sensor")
    print("               count reported ICC 0.82-0.98 while under-reading force by")
    print("               up to 37%. Report bias and limits of agreement, never r alone.")
    print()
    base = next((r for r in results if r.n_sensors == 4), None)
    best = max(results, key=lambda r: r.n_sensors)
    if base and np.isfinite(base.area_coverage_pct):
        print(f"  Niva's four sensors observe {base.area_coverage_pct:.1f}% of the loaded "
              f"contact area, holding {base.load_seen_pct:.1f}% of total load.")
    if base and best is not base and np.isfinite(best.area_coverage_pct):
        print(f"  Going from {base.n_sensors} to {best.n_sensors} sensors changes area "
              f"coverage by {best.area_coverage_pct - base.area_coverage_pct:+.1f} points, "
              f"load seen by {best.load_seen_pct - base.load_seen_pct:+.1f} points,")
        print(f"  and ML CoP error by {best.cop_ml_mae - base.cop_ml_mae:+.1f} mm. That "
              f"difference is the argument for or against the board revision.")
    print()


def make_plot(results, frames, mm, sensor_dia_mm, out_path):
    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
    except ImportError:
        print("matplotlib not installed; skipping plot", file=sys.stderr)
        return

    mean_map = frames.mean(axis=0)
    rows, cols = mean_map.shape
    n = len(results)
    fig, axes = plt.subplots(1, n + 1, figsize=(3.0 * (n + 1), 6.2))

    axes[0].imshow(mean_map, cmap="viridis", aspect="auto")
    axes[0].set_title("Mean pressure\n(ground truth)", fontsize=10)
    axes[0].set_xticks([]); axes[0].set_yticks([])

    radius = max(1, int(round((sensor_dia_mm / 2.0) / mm)))
    for ax, r in zip(axes[1:], results):
        ax.imshow(mean_map, cmap="Greys", aspect="auto", alpha=0.75)
        idx = sensor_indices(LAYOUTS[r.name], rows, cols)
        for rr, cc in idx:
            ax.add_patch(plt.Circle((cc, rr), radius, fill=False,
                                    edgecolor="#0E6E78", linewidth=1.8))
        ax.set_title(f"{r.name}  (n={r.n_sensors})\n"
                     f"ML {r.cop_ml_mae:.1f} mm · peak {r.peak_capture_pct:.0f}%",
                     fontsize=9)
        ax.set_xticks([]); ax.set_yticks([])

    fig.suptitle("What each layout can see", fontsize=13)
    fig.tight_layout()
    fig.savefig(out_path, dpi=140)
    print(f"Plot written to {out_path}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument(
        "--data",
        help="legacy .npy prototype input; use r2_study.py for StepUP research",
    )
    ap.add_argument("--demo", action="store_true", help="run on synthetic data")
    ap.add_argument("--layouts", default="niva4,niva6,published8,recommended13,ciniglio16")
    ap.add_argument("--mm-per-cell", type=float, default=MM_PER_CELL_DEFAULT)
    ap.add_argument("--sensor-dia", type=float, default=FSR402_ACTIVE_DIA_MM)
    ap.add_argument("--max-frames", type=int, default=5000)
    ap.add_argument("--plot", metavar="PNG", help="write a layout comparison figure")
    args = ap.parse_args()

    if not args.data and not args.demo:
        ap.error("give --data PATH, or --demo to exercise the pipeline")

    if args.demo:
        frames = synthesize()
        # The synthetic grid is 128 x 48 over a ~260 x 100 mm foot, so its pitch
        # is ~2 mm, not StepUP's 5 mm. Correct it unless the user said otherwise,
        # or every geometric metric below is computed on the wrong scale.
        if args.mm_per_cell == MM_PER_CELL_DEFAULT:
            args.mm_per_cell = 2.0
        print("Running on SYNTHETIC data. Get StepUP-P150 before reporting anything:")
        print("  doi:10.1038/s41597-025-05792-1  /  data doi:10.20383/103.01285")
    else:
        frames = load_frames(args.data)

    if len(frames) > args.max_frames:
        sel = np.linspace(0, len(frames) - 1, args.max_frames).astype(int)
        frames = frames[sel]

    names = [n.strip() for n in args.layouts.split(",") if n.strip()]
    unknown = [n for n in names if n not in LAYOUTS]
    if unknown:
        ap.error(f"unknown layout(s): {', '.join(unknown)}. "
                 f"Available: {', '.join(LAYOUTS)}")

    results = [evaluate(frames, n, LAYOUTS[n], args.mm_per_cell, args.sensor_dia)
               for n in names]
    report(results, demo=args.demo)

    if args.plot:
        make_plot(results, frames, args.mm_per_cell, args.sensor_dia, args.plot)


if __name__ == "__main__":
    main()
