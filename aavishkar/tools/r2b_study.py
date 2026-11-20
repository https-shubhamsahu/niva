"""R2b: full-cohort extension of R2. See docs/R2b_full_cohort_plan.md before running.

The step-level method is the frozen v1 code in r2_study.py. From it this runner uses only
load_trial, select, bounds, centres, discs and measure. Aggregation is written here,
because the v1 aggregation is tied to the v1 participant list.
"""
from __future__ import annotations
import argparse
from collections import Counter
import concurrent.futures
import csv
from datetime import datetime, timezone
import gzip
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import time
import urllib.request

sys.path.insert(0, str(Path(__file__).resolve().parent))
import numpy as np
import r2_study as R
from r2_data import sha

ROOT, DATA = R.ROOT, R.DATA
OUT = ROOT / 'docs/r2b'
V1_RUN = ROOT / 'docs/r2/run_20260912T161228Z'
REF = OUT / 'reference'
PLAN = 'docs/R2b_full_cohort_plan.md'
CODE = ('tools/r2b_study.py',)
V1_CODE = ('tools/r2_study.py', 'tools/r2_data.py')
PARTICIPANTS = tuple(range(2, 151))      # everyone except the setup participant 001
FIRST = tuple(range(2, 14))              # the v1 cohort, outcomes already known
CONDITIONS, SIDES, LAYOUTS = R.CONDITIONS, R.SIDES, R.LAYOUTS
DIAMETERS = (12.7, 14.7)                 # primary, then the declared sensitivity run
KEYS = ('area_pct', 'load_pct', 'peak_hit_pct', 'peak_overlap_pct', 'cop_ap_mae_mm',
        'cop_ml_mae_mm', 'undefined_cop_pct', 'load_bias_pct')
ORIENT_MIN = 5.0                         # cells; set on participants 001 to 013 only (plan)
BASE = 'https://www.frdr-dfdr.ca/repo/files/1/published/publication_1280/submitted_data/'
UA = {'User-Agent': 'research-data-client/1.0'}
TOL = 1e-9


def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()


def dump(path, obj):
    Path(path).write_text(json.dumps(obj, indent=1, allow_nan=False) + '\n', encoding='utf-8')


def require_committed():
    """Plan and runner committed and unchanged; v1 method files identical to the v1 run."""
    for f in (PLAN, *CODE):
        git('ls-files', '--error-unmatch', f)
        if git('diff', 'HEAD', '--', f):
            raise RuntimeError(f'Commit protocol/implementation changes before run: {f}')
    recorded = json.loads((V1_RUN / 'provenance.json').read_text())['code_sha256']
    for f in V1_CODE:
        if sha(ROOT / f) != recorded[f]:
            raise RuntimeError(f'The frozen v1 method file has changed: {f}')


# ------------------------------------------------------------- download ---
def fetch(relative, destination):
    if destination.exists():
        return
    destination.parent.mkdir(parents=True, exist_ok=True)
    part = destination.with_suffix(destination.suffix + '.part')
    last = None
    for attempt in range(3):
        try:
            request = urllib.request.Request(BASE + relative, headers=UA)
            with urllib.request.urlopen(request, timeout=120) as response, part.open('wb') as f:
                shutil.copyfileobj(response, f)
            part.replace(destination)
            return
        except Exception as e:                      # transient network errors: try again
            last = e
            time.sleep(3 * (attempt + 1))
    raise last


def download():
    OUT.mkdir(parents=True, exist_ok=True)
    checks = DATA / 'checksum_info.json'
    fetch('../checksum_info.json', checks)
    current = json.loads(checks.read_text(encoding='utf-8'))
    if current['algorithm'] != 'sha256':
        raise ValueError('Unsupported FRDR checksum algorithm')
    hashes = {r['filepath'].removeprefix('./'): r['checksum'] for r in current['checksums']}
    jobs = [('participant_metadata.csv', DATA / 'participant_metadata.csv')]
    jobs += [(f'py/{p:03}/{c}/W1/{f}', DATA / f'{p:03}' / c / 'W1' / f) for p in PARTICIPANTS for c in CONDITIONS
             for f in ('pipeline_1.npz', 'metadata.csv')]

    def one(job):
        rel, dest = job
        try:
            fetch(rel, dest)
            digest = sha(dest)
            if digest != hashes.get(rel):
                return {'rel': rel, 'error': 'published checksum mismatch', 'sha256': digest}
            return {'rel': rel, 'file': dest.relative_to(ROOT).as_posix(), 'sha256': digest,
                    'bytes': dest.stat().st_size, 'verified_frdr': True}
        except Exception as e:
            return {'rel': rel, 'error': f'{type(e).__name__}: {e}'}

    records = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for k, rec in enumerate(pool.map(one, jobs), 1):
            records.append(rec)
            if 'error' in rec or k % 50 == 0:
                print(f"{k}/{len(jobs)} {'UNAVAILABLE ' + rec['error'] if 'error' in rec else 'verified'} {rec['rel']}", flush=True)
    dump(OUT / 'inputs.json', {'checksum_manifest_sha256': sha(checks), 'checksum_manifest_date': current['generated_datetime'],
                               'files': sorted(records, key=lambda r: r['rel'])})
    bad = [r for r in records if 'error' in r]
    print(f'{len(records) - len(bad)} files verified, {len(bad)} unavailable, {sum(r.get("bytes", 0) for r in records):,} bytes')


def manifest():
    """Re-hash every input. Returns {(participant, condition): reason or None}."""
    m = json.loads((OUT / 'inputs.json').read_text())
    by = {r['rel']: r for r in m['files']}
    expected = {f'py/{p:03}/{c}/W1/{f}' for p in PARTICIPANTS for c in CONDITIONS for f in ('pipeline_1.npz', 'metadata.csv')}
    if not expected <= set(by):
        raise RuntimeError('Input manifest does not list every declared file')
    trials = {}
    for p in PARTICIPANTS:
        for c in CONDITIONS:
            reason = None
            for f in ('pipeline_1.npz', 'metadata.csv'):
                r = by[f'py/{p:03}/{c}/W1/{f}']
                if 'error' in r:
                    reason = f'{f}: {r["error"]}'
                elif sha(ROOT / r['file']) != r['sha256']:
                    raise RuntimeError('Input changed since download: ' + r['file'])
            trials[p, c] = reason
    return m, trials


def load(p, c):
    """v1 loader with its own checks. A failing trial is reported, never repaired."""
    try:
        return R.load_trial(p, c), None
    except Exception as e:
        return None, f'{type(e).__name__}: {e}'


# ------------------------------------------------------- quality checks ---
def orientation(step):
    """Row coordinate of the full-map CoP early in stance minus late in stance, in cells.
    Positive means the load moves from heel (high rows) to toe (low rows)."""
    flat = step.reshape(len(step), -1)
    total = flat.sum(axis=1)
    rows = np.indices(step.shape[1:])[0].ravel()
    r = np.where(total > 0, (flat @ rows) / np.where(total > 0, total, 1), np.nan)
    return float(np.nanmean(r[5:16]) - np.nanmean(r[85:96]))


def audit_all(trials):
    """Selection audit for every declared trial, in a fixed order."""
    audit = []
    for p in PARTICIPANTS:
        for c in CONDITIONS:
            if trials[p, c]:
                audit.append({'participant': p, 'condition': c, 'status': 'trial_unavailable', 'reason': trials[p, c]})
                continue
            loaded, reason = load(p, c)
            if reason:
                audit.append({'participant': p, 'condition': c, 'status': 'trial_unavailable', 'reason': reason})
                continue
            a, meta = loaded
            chosen, rows = R.select(a, meta, p, c)
            audit += rows
            yield p, c, a, chosen
            del a
    audit_all.result = audit


def sheets(panels, condition):
    """Contact sheets, 20 participants each. Individual colour scales, for anatomy only."""
    from PIL import Image, ImageDraw, ImageFont
    font = ImageFont.truetype('/usr/share/fonts/liberation/LiberationSans-Regular.ttf', 15)
    stops = [(0.0, (0xEA, 0xF0, 0xF2)), (0.5, (0x0B, 0x6F, 0x79)), (1.0, (0x14, 0x31, 0x4B))]

    def colour(v):
        for (a0, ca), (b0, cb) in zip(stops, stops[1:]):
            if v <= b0:
                t = (v - a0) / (b0 - a0)
                return tuple(round(x + t * (y - x)) for x, y in zip(ca, cb))
        return stops[-1][1]
    lut = np.array([colour(i / 255) for i in range(256)], dtype=np.uint8)
    S, PW, PH, LAB, GAP = 4, 40 * 4, 75 * 4, 22, 12
    names, per = [], 20
    ids = list(PARTICIPANTS)                 # every declared participant gets a slot, with or without steps
    for k in range(0, len(ids), per):
        group = ids[k:k + per]
        img = Image.new('RGB', (8 * (PW + GAP) + GAP, 5 * (PH + LAB + GAP) + GAP + 26), 'white')
        d = ImageDraw.Draw(img)
        d.text((GAP, 4), f'{condition} / W1 / Pipeline 1: mean of the selected steps, stored orientation, individual colour scales', font=font, fill=(15, 27, 30))
        for j, p in enumerate(group):
            for s_i, side in enumerate(SIDES):
                col, row = (j % 4) * 2 + s_i, j // 4
                x, y = GAP + col * (PW + GAP), 26 + GAP + row * (PH + LAB + GAP)
                d.text((x, y), f'{p:03} {side}' + ('' if (p, side) in panels else ' (none)'), font=font, fill=(15, 27, 30))
                if (p, side) in panels:
                    m = panels[p, side]
                    tile = lut[np.round(m / m.max() * 255).astype(int)] if m.max() > 0 else np.full((*m.shape, 3), 255, np.uint8)
                    img.paste(Image.fromarray(tile.astype(np.uint8), 'RGB').resize((PW, PH), Image.NEAREST), (x, y + LAB))
                d.rectangle([x, y + LAB, x + PW - 1, y + LAB + PH - 1], outline=(0xCB, 0xD8, 0xDC))
        name = f'qa_{condition}_{group[0]:03}_{group[-1]:03}.png'
        img.save(OUT / name)
        names.append(name)
    return names


def qa():
    _, trials = manifest()
    OUT.mkdir(parents=True, exist_ok=True)
    panels = {c: {} for c in CONDITIONS}
    orient = []
    for p, c, a, chosen in audit_all(trials):
        for s in SIDES:
            ids = chosen[s]
            if ids:
                panels[c][p, s] = a[ids].mean(axis=(0, 1))
                d = [orientation(a[i]) for i in ids]
                orient.append({'participant': p, 'condition': c, 'side': s, 'n': len(d), 'min_cells': min(d),
                               'flagged_steps': [int(i) for i, v in zip(ids, d) if not v > ORIENT_MIN]})
    names = []
    for c in CONDITIONS:
        names += sheets(panels[c], c)
    dump(OUT / 'selection.json', audit_all.result)
    dump(OUT / 'orientation.json', {'threshold_cells': ORIENT_MIN, 'groups': orient})
    dump(OUT / 'qa_review.json', {'reviewed': False, 'inputs_sha256': sha(OUT / 'inputs.json'),
                                  'selection_sha256': sha(OUT / 'selection.json'), 'orientation_sha256': sha(OUT / 'orientation.json'),
                                  'sheet_sha256': {f: sha(OUT / f) for f in names},
                                  'review_notes': 'Pending inspection before outcomes are computed.'})
    flagged = [g for g in orient if g['flagged_steps']]
    groups = len(orient)
    print(f'{groups} participant-condition-side groups with 12 selected steps; {len(flagged)} groups with a flagged step; '
          f'lowest orientation value {min(g["min_cells"] for g in orient):.2f} cells; {len(names)} sheets written.')
    print('Inspect the sheets, then record the review in docs/r2b/qa_review.json.')


# ----------------------------------------------------------- aggregation ---
def mean(values):
    v = [x for x in values if x is not None]
    return float(np.mean(v)) if v else None


def participant_means(steps):
    """One row per participant, condition and layout: mean of each side's steps, then mean of the two sides."""
    groups = {}
    for r in steps:
        groups.setdefault((r['participant'], r['condition'], r['layout']), []).append(r)
    people = []
    for (p, c, name), rows in sorted(groups.items(), key=lambda kv: (kv[0][0], CONDITIONS.index(kv[0][1]), list(LAYOUTS).index(kv[0][2]))):
        row = {'participant': p, 'condition': c, 'layout': name, 'n_steps': len(rows)}
        for key in KEYS:
            row[key] = mean([mean([x[key] for x in rows if x['side'] == s]) for s in SIDES])
        people.append(row)
    return people


def _betacf(a, b, x):
    tiny, qab, qap, qam = 1e-300, a + b, a + 1, a - 1
    c, d = 1.0, 1 - qab * x / qap
    d = 1 / (d if abs(d) > tiny else tiny)
    h = d
    for m in range(1, 400):
        m2 = 2 * m
        for aa in (m * (b - m) * x / ((qam + m2) * (a + m2)), -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2))):
            d = 1 + aa * d
            d = 1 / (d if abs(d) > tiny else tiny)
            c = 1 + aa / c
            c = c if abs(c) > tiny else tiny
            h *= d * c
        if abs(d * c - 1) < 1e-15:
            break
    return h


def _betai(a, b, x):
    if x <= 0:
        return 0.0
    if x >= 1:
        return 1.0
    bt = math.exp(math.lgamma(a + b) - math.lgamma(a) - math.lgamma(b) + a * math.log(x) + b * math.log(1 - x))
    return bt * _betacf(a, b, x) / a if x < (a + 1) / (a + b + 2) else 1 - bt * _betacf(b, a, 1 - x) / b


def t_crit(df, level=0.95):
    """Two-sided critical value of Student's t, by bisection on its distribution function."""
    target = 1 - (1 - level) / 2
    cdf = lambda t: 1 - 0.5 * _betai(df / 2, 0.5, df / (df + t * t))
    lo, hi = 0.0, 100.0
    for _ in range(200):
        mid = (lo + hi) / 2
        lo, hi = (mid, hi) if cdf(mid) < target else (lo, mid)
    return (lo + hi) / 2


def spread(values):
    v = [float(x) for x in values if x is not None]
    n = len(v)
    if not n:
        return {'n': 0, 'mean': None, 'sd': None, 'min': None, 'max': None, 'ci95': None}
    m = float(np.mean(v))
    sd = float(np.std(v, ddof=1)) if n > 1 else None
    half = t_crit(n - 1) * sd / math.sqrt(n) if n > 1 else None
    return {'n': n, 'mean': m, 'sd': sd, 'min': min(v), 'max': max(v), 'ci95': [m - half, m + half] if half is not None else None}


def group_summary(people, ids, keys=KEYS):
    ids = set(ids)
    groups = []
    for c in CONDITIONS:
        for name in LAYOUTS:
            rows = [r for r in people if r['condition'] == c and r['layout'] == name and r['participant'] in ids]
            g = {'condition': c, 'layout': name, 'n_participants': len(rows), 'n_sensors': len(LAYOUTS[name])}
            for key in keys:
                g[key] = spread([r[key] for r in rows])
            groups.append(g)
    return groups


def maxdiff(a, b):
    """Largest absolute numeric difference between two nested structures of the same shape."""
    if isinstance(a, dict):
        if a.keys() != b.keys():
            return math.inf
        return max((maxdiff(a[k], b[k]) for k in a), default=0.0)
    if isinstance(a, (list, tuple)):
        if len(a) != len(b):
            return math.inf
        return max((maxdiff(x, y) for x, y in zip(a, b)), default=0.0)
    if a is None or b is None:
        return 0.0 if a is b else math.inf
    if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
        return abs(a - b)
    return 0.0 if a == b else math.inf


# ---------------------------------------------------------------- compute ---
def descriptors(step):
    flat = step.reshape(len(step), -1)
    total = flat.sum(axis=1)
    flat = flat[total > 0]
    contact = (flat >= .02 * flat.max(axis=1)[:, None]).sum(axis=1) * R.PITCH ** 2
    r0, r1, c0, c1 = R.bounds(step)
    return {'contact_mm2': float(contact.mean()), 'length_mm': (r1 - r0 + 1) * R.PITCH, 'width_mm': (c1 - c0 + 1) * R.PITCH}


def compute(trials, reviewed_audit):
    steps = {d: [] for d in DIAMETERS}
    scale = []
    seen = 0
    for p, c, a, chosen in audit_all(trials):
        for s in SIDES:
            for i in chosen[s]:
                box = R.bounds(a[i])
                scale.append({'participant': p, 'condition': c, 'side': s, 'step_id': i, **descriptors(a[i])})
                for d in DIAMETERS:
                    R.DIAMETER = d                       # the v1 functions read this global at call time
                    try:
                        for name, layout in LAYOUTS.items():
                            steps[d].append({'participant': p, 'condition': c, 'side': s, 'step_id': i, 'layout': name,
                                             'bbox': list(box), **R.measure(a[i], R.centres(box, layout, s))})
                    finally:
                        R.DIAMETER = DIAMETERS[0]
        seen += 1
        if seen % 20 == 0:
            print(f'Computed {seen} trials', flush=True)
    if audit_all.result != reviewed_audit:
        raise RuntimeError('Selection differs from the reviewed quality-check record')
    return steps, scale


def scale_people(scale):
    out = []
    for p in PARTICIPANTS:
        for c in CONDITIONS:
            rows = [r for r in scale if r['participant'] == p and r['condition'] == c]
            if rows:
                out.append({'participant': p, 'condition': c, **{k: mean([mean([r[k] for r in rows if r['side'] == s]) for s in SIDES])
                                                                   for k in ('contact_mm2', 'length_mm', 'width_mm')}})
    return out


def characteristics(ids):
    with (DATA / 'participant_metadata.csv').open(newline='', encoding='utf-8-sig') as f:
        rows = {int(r['ParticipantID']): r for r in csv.DictReader(f)}
    sel = [rows[p] for p in sorted(ids) if p in rows]
    count = lambda field: dict(sorted(Counter((r.get(field) or '').strip() or 'missing' for r in sel).items()))

    def numeric(field):
        vals, missing = [], 0
        for r in sel:
            try:
                vals.append(float(r[field]))
            except (KeyError, TypeError, ValueError):
                missing += 1
        s = spread(vals)
        return {'n': s['n'], 'missing': missing, 'mean': s['mean'], 'sd': s['sd'], 'min': s['min'], 'max': s['max']}
    return {'n': len(sel), 'not_in_metadata': sorted(set(ids) - set(rows)), 'Sex': count('Sex'), 'BFType': count('BFType'),
            'Age': numeric('Age'), 'Weight (Kg)': numeric('Weight (Kg)'), 'Height (cm)': numeric('Height (cm)')}, {p: (r.get('Sex') or '').strip() or 'missing' for p, r in rows.items()}


def run():
    require_committed()
    inputs, trials = manifest()
    review = json.loads((OUT / 'qa_review.json').read_text())
    if (not review['reviewed'] or review['inputs_sha256'] != sha(OUT / 'inputs.json') or review['selection_sha256'] != sha(OUT / 'selection.json')
            or review['orientation_sha256'] != sha(OUT / 'orientation.json')):
        raise RuntimeError('Current inputs, selection and orientation check must be reviewed before analysis')
    for file, digest in review['sheet_sha256'].items():
        if sha(OUT / file) != digest:
            raise RuntimeError('A contact sheet changed after review')
    audit = json.loads((OUT / 'selection.json').read_text())
    steps, scale = compute(trials, audit)
    people = {d: participant_means(steps[d]) for d in DIAMETERS}
    sp = scale_people(scale)

    # ---- consistency with what is already on record for participants 002 to 013
    first = set(FIRST)
    v1_steps = json.loads((V1_RUN / 'steps.json').read_text())
    mine = [r for r in steps[12.7] if r['participant'] in first]
    d1 = maxdiff(mine, v1_steps)
    ref147 = json.loads((REF / 'sens147_first12.json').read_text())
    got147 = group_summary(people[14.7], first, keys=('area_pct', 'load_pct', 'peak_hit_pct', 'cop_ap_mae_mm', 'cop_ml_mae_mm', 'undefined_cop_pct'))
    d2 = max(abs(g[k][s] - r[k][s]) for g, r in zip(got147, ref147) for k in r if isinstance(r[k], dict) for s in ('mean', 'min', 'max'))
    assert all((g['condition'], g['layout']) == (r['condition'], r['layout']) for g, r in zip(got147, ref147))
    refpost = json.loads((REF / 'posthoc_first12.json').read_text())['cond']
    d3 = 0.0
    for c in CONDITIONS:
        rows = [r for r in sp if r['condition'] == c and r['participant'] in first]
        for mine_key, ref_key in (('contact_mm2', 'mean_contact_area_mm2_per_frame'), ('length_mm', 'footprint_length_mm'), ('width_mm', 'footprint_width_mm')):
            s = spread([r[mine_key] for r in rows])
            d3 = max(d3, *(abs(s[k] - refpost[c][ref_key][k]) for k in ('mean', 'min', 'max')))
    print(f'consistency: v1 steps {d1:.3g}; 14.7 mm summary {d2:.3g}; scale descriptors {d3:.3g}')
    if max(d1, d2, d3) > TOL:
        raise RuntimeError('The first cohort does not reproduce the stored record. No results written.')

    contributing = {c: sorted({r['participant'] for r in people[12.7] if r['condition'] == c}) for c in CONDITIONS}
    everyone = sorted(set(contributing['BF']) | set(contributing['ST']))
    sets = {'all': set(PARTICIPANTS), 'new': set(PARTICIPANTS) - first, 'first': first}
    summary = {f'{d}': {name: group_summary(people[d], ids) for name, ids in sets.items()} for d in DIAMETERS}
    scale_summary = {name: {c: {k: spread([r[k] for r in sp if r['condition'] == c and r['participant'] in ids]) for k in ('contact_mm2', 'length_mm', 'width_mm')}
                            for c in CONDITIONS} for name, ids in sets.items()}
    chars, sex_of = characteristics(everyone)
    by_sex = []
    for value in sorted(set(sex_of[p] for p in everyone if p in sex_of)):
        ids = {p for p in everyone if sex_of.get(p) == value}
        for g in group_summary(people[12.7], ids, keys=('area_pct', 'load_pct')):
            by_sex.append({'sex': value, **g})

    dest = OUT / ('run_' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    dest.mkdir(parents=True, exist_ok=False)
    for d in DIAMETERS:
        with gzip.open(dest / f'steps_{d}.json.gz', 'wt', encoding='utf-8') as f:
            json.dump(steps[d], f, allow_nan=False)
        dump(dest / f'participants_{d}.json', people[d])
    dump(dest / 'summary.json', summary)
    dump(dest / 'scale_participants.json', sp)
    dump(dest / 'scale_summary.json', scale_summary)
    dump(dest / 'characteristics.json', chars)
    dump(dest / 'by_sex.json', by_sex)
    dump(dest / 'selection.json', audit)
    unavailable = [r for r in audit if r.get('status') == 'trial_unavailable']
    dropped = [{'participant': p, 'condition': c} for p in PARTICIPANTS for c in CONDITIONS
               if not trials[p, c] and p not in contributing[c] and not any(u['participant'] == p and u['condition'] == c for u in unavailable)]
    dump(dest / 'provenance.json', {
        'utc': datetime.now(timezone.utc).isoformat(), 'plan_commit': git('log', '-1', '--format=%H', '--', PLAN),
        'implementation_commit': git('rev-parse', 'HEAD'), 'code_sha256': {f: sha(ROOT / f) for f in (*CODE, *V1_CODE)},
        'plan_sha256': sha(ROOT / PLAN), 'python': sys.version, 'numpy': np.__version__,
        'inputs_sha256': sha(OUT / 'inputs.json'), 'n_input_files': len(inputs['files']), 'input_bytes': sum(r.get('bytes', 0) for r in inputs['files']),
        'checksum_manifest_date': inputs['checksum_manifest_date'], 'qa_review': review,
        'pitch_mm': R.PITCH, 'diameters_mm': list(DIAMETERS), 'subgrid': R.SUBGRID, 'layouts': LAYOUTS, 'orientation_threshold_cells': ORIENT_MIN,
        'contributing': {c: len(v) for c, v in contributing.items()}, 'contributing_ids': contributing,
        'trials_unavailable': unavailable, 'left_out_fewer_than_12_steps': dropped,
        'n_step_records': {f'{d}': len(steps[d]) for d in DIAMETERS},
        'consistency_max_abs_diff': {'v1_steps_12.7': d1, 'first12_summary_14.7': d2, 'first12_scale': d3}})
    report(dest, summary, scale_summary, contributing, unavailable, dropped, audit)
    print(dest)


def report(dest, summary, scale_summary, contributing, unavailable, dropped, audit):
    fmt = lambda m, dp=2: 'to be measured' if m['mean'] is None else f"{m['mean']:.{dp}f} ({m['sd']:.{dp}f}) [{m['min']:.{dp}f}, {m['max']:.{dp}f}]"
    selected = sum(1 for r in audit if r.get('status') == 'selected')
    text = ['# R2b full-cohort results', '',
            'Computed layout-model observability on recorded StepUP pressure fields, for every participant',
            'except the setup participant. Physical Niva sensor coordinates and actual in-shoe performance: **to be measured**.', '',
            f"Contributing participants: BF {len(contributing['BF'])}, ST {len(contributing['ST'])}. Selected footsteps: {selected}.",
            f'Trials unavailable: {len(unavailable)}. Participant-conditions left out for fewer than 12 eligible steps on a side: {len(dropped)}.', '',
            'Protocol: [R2b plan](../../R2b_full_cohort_plan.md). Inputs, code and plan revisions are in [provenance.json](provenance.json).', '',
            'Values are mean (SD) [lowest participant, highest participant], with each participant given equal weight.', '']
    for d in DIAMETERS:
        for name, label in (('all', 'All participants 002 to 150'), ('new', 'New participants 014 to 150'), ('first', 'First cohort 002 to 013')):
            if d != DIAMETERS[0] and name != 'all':
                continue
            text += [f'## {label}, {d} mm discs', '', '| Condition | Layout model | n | Area observed % | Load observed % | Peak-centre hit % | AP CoP MAE mm | ML CoP MAE mm | Undefined CoP % |',
                     '|---|---|---:|---:|---:|---:|---:|---:|---:|']
            for g in summary[f'{d}'][name]:
                text.append(f"| {g['condition']} | {g['layout']} | {g['n_participants']} | " + ' | '.join(fmt(g[k]) for k in ('area_pct', 'load_pct', 'peak_hit_pct', 'cop_ap_mae_mm', 'cop_ml_mae_mm', 'undefined_cop_pct')) + ' |')
            text.append('')
    text += ['## Limits on interpretation', '',
             'The layouts use assumed footprint-relative coordinates; their legacy names do not establish fidelity to hardware',
             'or to published sensor configurations. Count and position change together. BF records foot or sock on the floor',
             'and ST records outsole on the floor; neither measures the foot-insole interface, and no lower bound on in-shoe',
             'performance is claimed. Confidence intervals in summary.json describe the precision of the mean for volunteers',
             'like those in this dataset and are not a claim about any other population. No hypothesis test was made.', '',
             'Dataset: Larracy et al. (2025), [StepUP-P150](https://doi.org/10.20383/103.01285), CC BY 4.0.', '']
    (dest / 'results.md').write_text('\n'.join(text), encoding='utf-8')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('download', 'qa', 'run'))
    {'download': download, 'qa': qa, 'run': run}[p.parse_args().command]()


if __name__ == '__main__':
    main()
