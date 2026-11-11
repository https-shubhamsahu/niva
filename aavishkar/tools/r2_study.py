"""Reproducible R2 subset study. See docs/R2_sampling_plan.md before running."""
from __future__ import annotations
import argparse
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import subprocess
import sys

# Also supports the desktop's isolated Python runtime.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from r2_data import ROOT, DATA, OUT, PARTICIPANTS, CONDITIONS, downloads, sha
import numpy as np

PITCH = 5.0  # Source instrument + scale-preserving Pipeline 1; see protocol.
DIAMETER = 12.7
SUBGRID = 32
PLAN = 'docs/R2_sampling_plan.md'
CODE = ('tools/r2_study.py','tools/r2_data.py')
SIDES = ('Right','Left')
# Frozen legacy coordinates; these are layout MODELS, not measured hardware
# positions or verified reconstructions of the papers mentioned in old code.
LAYOUTS = {
    'niva4':[(.86,.50),(.36,.28),(.36,.76),(.10,.36)],
    'niva6':[(.86,.50),(.36,.28),(.36,.76),(.10,.36),(.60,.62),(.36,.52)],
    'published8':[(.88,.44),(.88,.62),(.60,.66),(.38,.24),(.38,.40),(.38,.56),(.38,.74),(.10,.34)],
    'recommended13':[(.92,.42),(.92,.60),(.78,.50),(.62,.30),(.62,.68),(.40,.22),(.40,.38),(.40,.52),(.40,.66),(.40,.80),(.16,.30),(.16,.50),(.06,.34)],
    'ciniglio16':[(.94,.40),(.94,.62),(.82,.46),(.82,.60),(.64,.30),(.64,.52),(.64,.72),(.44,.20),(.44,.34),(.44,.48),(.44,.62),(.44,.78),(.28,.28),(.28,.48),(.28,.68),(.08,.34)],
}

def git(*args):
    return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()

def require_committed():
    for f in (PLAN,*CODE):
        git('ls-files','--error-unmatch',f)
        if git('diff','HEAD','--',f):
            raise RuntimeError(f'Commit protocol/implementation changes before run: {f}')

def dump(path, obj):
    Path(path).write_text(json.dumps(obj,indent=2,allow_nan=False)+'\n',encoding='utf-8')

def manifest():
    m=json.loads((OUT/'inputs.json').read_text())
    expected={f'data/stepup-p150/{p:03}/{c}/W1/{f}' for p in PARTICIPANTS
              for c in CONDITIONS for f in ('metadata.csv','pipeline_1.npz')}
    if {r.get('file') for r in m} != expected:
        raise RuntimeError('Input manifest must contain exactly the declared subset')
    for r in m:
        if not r.get('verified_frdr') or sha(ROOT/r['file']) != r['sha256']:
            raise RuntimeError('Changed or unverified input: '+r.get('file','unknown'))
    return m

def load_trial(p,c):
    folder=DATA/f'{p:03}'/c/'W1'
    with (folder/'metadata.csv').open(newline='') as f:
        meta=list(csv.DictReader(f))
    with np.load(folder/'pipeline_1.npz',allow_pickle=False) as z:
        if z.files != ['arr_0']:
            raise RuntimeError('Unexpected NPZ members')
        a=z['arr_0']
    if a.ndim != 4 or a.shape[1:] != (101,75,40) or len(a)!=len(meta):
        raise RuntimeError(f'Array/metadata mismatch in {folder}')
    if [int(m['FootstepID']) for m in meta] != list(range(len(a))):
        raise RuntimeError(f'Ambiguous FootstepID mapping in {folder}')
    for m in meta:
        if (int(m['ParticipantID']),m['Footwear'],m['Speed']) != (p,c,'W1'):
            raise RuntimeError(f'Incorrect metadata identity in {folder}')
    return a,meta

def bounds(step):
    yy,xx=np.where(np.max(step,axis=0)>0)
    if not len(yy):
        raise ValueError('empty footprint')
    return int(yy.min()),int(yy.max()),int(xx.min()),int(xx.max())

def select(a,meta,p,c):
    audit=[]
    chosen={s:[] for s in SIDES}
    for m in sorted(meta,key=lambda m:(int(m['StartFrame']),int(m['FootstepID']))):
        i=int(m['FootstepID'])
        side=m['Side']
        reasons=[k for k in ('Exclude','Incomplete','Standing','Outlier') if int(m[k])!=0]
        if side not in SIDES:
            reasons.append('unknown_side')
        step=a[i]
        if not np.isfinite(step).all() or np.any(step<0):
            reasons.append('invalid_pressure')
        elif step.max()<=0:
            reasons.append('empty_footprint')
        else:
            r0,r1,c0,c1=bounds(step)
            if r0==0 or c0==0 or r1==step.shape[1]-1 or c1==step.shape[2]-1:
                reasons.append('canvas_boundary')
        if reasons:
            status='excluded'
        elif len(chosen[side])<12:
            chosen[side].append(i)
            status='selected'
        else:
            status='eligible_after_first_12'
        audit.append({'participant':p,'condition':c,'side':side,'step_id':i,
                      'status':status,'reasons':reasons})
    if any(len(chosen[s])<12 for s in SIDES):
        for row in audit:
            if row['status']=='selected':
                row['status']='excluded_incomplete_paired_sample'
        chosen={s:[] for s in SIDES}
    return chosen,audit

def centres(box,layout,side):
    r0,r1,c0,c1=box
    return np.asarray([(r0+fr*(r1-r0),c0+(fc if side=='Right' else 1-fc)*(c1-c0))
                       for fr,fc in layout])

def discs(shape,positions,subgrid=SUBGRID):
    """Fractional circular footprints and their union; uniform pressure per cell."""
    radius=DIAMETER/(2*PITCH)
    d=(np.arange(subgrid)+.5)/subgrid-.5
    weights=np.zeros((len(positions),*shape))
    union_cells={}
    for k,(r,c) in enumerate(positions):
        for y in range(max(0,int(np.floor(r-radius-.5))),min(shape[0],int(np.ceil(r+radius+.5))+1)):
            for x in range(max(0,int(np.floor(c-radius-.5))),min(shape[1],int(np.ceil(c+radius+.5))+1)):
                inside=(y+d[:,None]-r)**2+(x+d[None,:]-c)**2 <= radius**2
                if inside.any():
                    weights[k,y,x]=inside.mean()
                    if (y,x) in union_cells:
                        union_cells[y,x] |= inside
                    else:
                        union_cells[y,x]=inside.copy()
    union=np.zeros(shape)
    for (y,x),inside in union_cells.items():
        union[y,x]=inside.mean()
    return weights,union

def measure(step,positions):
    w,union=discs(step.shape[1:],positions)
    flat=step.reshape(len(step),-1)
    total=flat.sum(axis=1)
    loaded=total>0
    flat=flat[loaded]
    total=total[loaded]
    if not len(total):
        raise ValueError('Selected step has no loaded frames')
    peak=flat.max(axis=1)
    contact=flat >= .02*peak[:,None]
    coverage=100*(contact@union.ravel())/contact.sum(axis=1)
    load=100*(flat@union.ravel())/total
    maximum=flat==peak[:,None]
    yy,xx=np.indices(union.shape)
    peak_centres=np.zeros(union.shape,dtype=bool)
    for r,c in positions:
        peak_centres |= (yy-r)**2+(xx-c)**2 <= (DIAMETER/(2*PITCH))**2
    hit=np.any(maximum & peak_centres.ravel(),axis=1)
    peak_overlap=(maximum@union.ravel())/maximum.sum(axis=1)
    forces=flat@w.reshape(len(w),-1).T
    sparse_total=forces.sum(axis=1)
    available=sparse_total>0
    reference=np.column_stack((flat@yy.ravel(),flat@xx.ravel()))/total[:,None]
    delta=(forces[available]@positions/sparse_total[available,None]-reference[available])*PITCH
    return {'loaded_frames':int(len(total)), 'empty_frames':int((~loaded).sum()),
            'area_pct':float(coverage.mean()),'load_pct':float(load.mean()),
            'peak_hit_pct':float(100*hit.mean()),'peak_overlap_pct':float(100*peak_overlap.mean()),
            'cop_ap_mae_mm':float(np.abs(delta[:,0]).mean()) if available.any() else None,
            'cop_ml_mae_mm':float(np.abs(delta[:,1]).mean()) if available.any() else None,
            'undefined_cop_pct':float(100*(~available).mean()),
            'load_bias_pct':float((load-100).mean())}

def plotting():
    # Matplotlib is only for scientific pressure heatmaps, not apparatus diagrams.
    local=ROOT/'data/r2-python'
    if local.exists():
        sys.path.append(str(local))
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap
    plt.rcParams.update({'font.family':'Arial','text.color':'#0F1B1E',
                         'axes.edgecolor':'#CBD8DC','axes.labelcolor':'#5A6C72'})
    return plt,LinearSegmentedColormap.from_list('niva',['#EAF0F2','#0B6F79','#14314B'])

def qa():
    manifest()
    plt,cmap=plotting()
    all_audit=[]
    sheets=[]
    for c in CONDITIONS:
        fig,axs=plt.subplots(4,6,figsize=(13,13),layout='constrained')
        for k,p in enumerate(PARTICIPANTS):
            a,meta=load_trial(p,c)
            chosen,audit=select(a,meta,p,c)
            all_audit+=audit
            for j,s in enumerate(SIDES):
                ax=axs.flat[k*2+j]
                ids=chosen[s]
                if ids:
                    mean=a[ids].mean(axis=(0,1))
                    ax.imshow(mean,cmap=cmap,origin='upper',aspect='equal',interpolation='nearest')
                ax.set_title(f'{p:03} {s} | n={len(ids)}',fontsize=10)
                ax.set_xticks([]);ax.set_yticks([])
            del a
        fig.suptitle(f'{c} / W1 / Pipeline 1 — selected mean pressure maps\n'
                     'Stored orientation; individual colour scales for anatomy QA only',fontsize=15)
        dest=OUT/f'qa_{c}.png'
        fig.savefig(dest,dpi=140)
        plt.close(fig)
        sheets.append(dest.name)
    dump(OUT/'selection.json',all_audit)
    dump(OUT/'qa_review.json',{'reviewed':False,'inputs_sha256':sha(OUT/'inputs.json'),
        'selection_sha256':sha(OUT/'selection.json'),
        'sheet_sha256':{f:sha(OUT/f) for f in sheets},
        'review_notes':'Pending visual inspection before cohort metrics.'})
    print('QA sheets written. Inspect both, then record review in docs/r2/qa_review.json.')

def mean(values):
    v=[x for x in values if x is not None]
    return float(np.mean(v)) if v else None

def summarize(steps):
    keys=('area_pct','load_pct','peak_hit_pct','peak_overlap_pct','cop_ap_mae_mm',
          'cop_ml_mae_mm','undefined_cop_pct','load_bias_pct')
    people=[]
    for p in PARTICIPANTS:
        for c in CONDITIONS:
            for name in LAYOUTS:
                rows=[r for r in steps if (r['participant'],r['condition'],r['layout'])==(p,c,name)]
                if not rows:
                    continue
                r={'participant':p,'condition':c,'layout':name,'n_steps':len(rows)}
                for key in keys:
                    side_means=[mean([x[key] for x in rows if x['side']==s]) for s in SIDES]
                    r[key]=mean(side_means)
                differences=[x['load_bias_pct'] for x in rows]
                sd=float(np.std(differences,ddof=1))
                r['step_bias_descriptive_limits_pct']=[r['load_bias_pct']-1.96*sd,r['load_bias_pct']+1.96*sd]
                people.append(r)
    groups=[]
    for c in CONDITIONS:
        for name in LAYOUTS:
            rows=[r for r in people if (r['condition'],r['layout'])==(c,name)]
            r={'condition':c,'layout':name,'n_participants':len(rows),'n_sensors':len(LAYOUTS[name])}
            for key in keys:
                values=[x[key] for x in rows if x[key] is not None]
                r[key]={'mean':mean(values),'min':float(min(values)) if values else None,
                        'max':float(max(values)) if values else None,'n':len(values)}
            groups.append(r)
    return people,groups

def run():
    require_committed()
    inputs=manifest()
    review=json.loads((OUT/'qa_review.json').read_text())
    if not review['reviewed'] or review['inputs_sha256']!=sha(OUT/'inputs.json') or review['selection_sha256']!=sha(OUT/'selection.json'):
        raise RuntimeError('Current input and selection QA must be reviewed before analysis')
    for file,digest in review['sheet_sha256'].items():
        if sha(OUT/file)!=digest:
            raise RuntimeError('QA sheet changed after review')
    audit=json.loads((OUT/'selection.json').read_text())
    steps=[]
    for p in PARTICIPANTS:
        for c in CONDITIONS:
            a,meta=load_trial(p,c)
            chosen,new_audit=select(a,meta,p,c)
            expected=[r for r in audit if (r['participant'],r['condition'])==(p,c)]
            if new_audit!=expected:
                raise RuntimeError('Selection differs from reviewed QA')
            for s in SIDES:
                for i in chosen[s]:
                    box=bounds(a[i])
                    for name,layout in LAYOUTS.items():
                        positions=centres(box,layout,s)
                        steps.append({'participant':p,'condition':c,'side':s,'step_id':i,
                            'layout':name,'bbox':list(box),**measure(a[i],positions)})
            print(f'Computed {p:03}/{c}',flush=True)
            del a
    people,groups=summarize(steps)
    dest=OUT/('run_'+datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    dest.mkdir(parents=True,exist_ok=False)
    dump(dest/'steps.json',steps)
    dump(dest/'participants.json',people)
    dump(dest/'summary.json',groups)
    dump(dest/'selection.json',audit)
    dump(dest/'provenance.json',{'utc':datetime.now(timezone.utc).isoformat(),
        'plan_commit':git('log','-1','--format=%H','--',PLAN),
        'implementation_commit':git('rev-parse','HEAD'),
        'code_sha256':{f:sha(ROOT/f) for f in CODE},'plan_sha256':sha(ROOT/PLAN),
        'python':sys.version,'numpy':np.__version__,'inputs':inputs,'qa_review':review,
        'pitch_mm':PITCH,'sensor_diameter_mm':DIAMETER,'subgrid':SUBGRID,'layouts':LAYOUTS})
    report(dest,steps,people,groups,audit)
    print(dest)

def report(dest,steps,people,groups,audit):
    selected=[r for r in audit if r['status']=='selected']
    text=['# R2 declared subset results','',
          'Computed layout-model observability on recorded StepUP pressure fields.',
          'Physical Niva sensor coordinates and actual in-shoe performance: **to be measured**.','',
          f'Selection: {len(selected)} footsteps across {len(PARTICIPANTS)} planned participants,',
          'IDs 002–013; BF and ST at preferred speed W1. Twelve eligible steps per',
          'side and condition were targeted. Participant 001 was setup-only.','',
          'Protocol: [committed sampling plan](../../R2_sampling_plan.md).',
          'Exact inputs, code and plan revisions are in [provenance.json](provenance.json).','',
          'Means below give each participant equal weight after step and side aggregation.',
          'Bracketed values are observed participant ranges, not confidence intervals.','',
          '| Condition | Layout model | Participants | Area observed % | Load observed % |',
          '|---|---|---:|---:|---:|']
    def fmt(m):
        return 'to be measured' if m['mean'] is None else f"{m['mean']:.2f} [{m['min']:.2f}, {m['max']:.2f}]"
    for g in groups:
        text.append(f"| {g['condition']} | {g['layout']} | {g['n_participants']} | {fmt(g['area_pct'])} | {fmt(g['load_pct'])} |")
    text+=['','| Condition | Layout model | Peak-centre hit % | AP CoP MAE mm | ML CoP MAE mm | Undefined CoP % |',
           '|---|---|---:|---:|---:|---:|']
    for g in groups:
        text.append(f"| {g['condition']} | {g['layout']} | {fmt(g['peak_hit_pct'])} | {fmt(g['cop_ap_mae_mm'])} | {fmt(g['cop_ml_mae_mm'])} | {fmt(g['undefined_cop_pct'])} |")
    text+=['','CoP errors are conditional on nonzero sparse signal; undefined rates are',
           'reported separately, and those missed frames remain in coverage denominators.',
           'Peak capture tests recorded sensel centres and handles tied maxima. Fractional',
           'peak-sensel overlap is included in the machine-readable outputs.','',
           'Load bias is observed load minus full-map load as a percentage of full-map',
           'load, without calibration fitted on these data. Per-participant descriptive',
           'step-level limits are in participants.json. They do not validate agreement',
           'of a calibrated whole-foot force measurement.','',
           'All records, including excluded steps and steps after the first twelve, are',
           'retained in selection.json. See steps.json for all per-step metrics.','',
           '## Limits on interpretation','',
           'This is an administrative subset, without a population sampling or power claim.',
           'Layouts use assumed footprint-relative coordinates; their legacy names do not',
           'establish fidelity to hardware or published sensor configurations. Count and',
           'position change together. Discs integrate piecewise-constant source sensels,',
           'and the contact threshold is an operational analysis choice. Pipeline 1',
           'preserves spatial pitch but rotates with nearest-neighbour sampling and',
           'normalizes time to stance phase. Frames are repeated observations.','',
           'BF records foot/sock-to-floor contact; ST records outsole-to-floor contact.',
           'Neither measures the foot-insole interface. Transfer to actual in-shoe',
           'coverage, including its direction of bias, is **to be measured**. No lower',
           'bound on in-shoe performance is claimed. No poster or deck result was changed.','',
           'Dataset: Larracy et al. (2025), [StepUP-P150](https://doi.org/10.20383/103.01285),',
           'CC BY 4.0. [Data descriptor](https://doi.org/10.1038/s41597-025-05792-1).','']
    (dest/'results.md').write_text('\n'.join(text),encoding='utf-8')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=('download','qa','run'))
    args=p.parse_args()
    {'download':downloads,'qa':qa,'run':run}[args.command]()

if __name__=='__main__':
    main()
