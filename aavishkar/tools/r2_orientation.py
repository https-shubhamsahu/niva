"""Plot recorded Pipeline 1 means for orientation QA, without coverage analysis."""
import csv
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[1]
if (ROOT / 'data/r2-python').exists():
    sys.path.append(str(ROOT / 'data/r2-python'))
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import LinearSegmentedColormap

def main():
    folder = ROOT / 'data/stepup-p150/001/BF/W1'
    with np.load(folder / 'pipeline_1.npz', allow_pickle=False) as z:
        a = z['arr_0']
    with (folder / 'metadata.csv').open(newline='') as f:
        meta = list(csv.DictReader(f))
    assert len(meta) == len(a)
    assert [int(m['FootstepID']) for m in meta] == list(range(len(a)))
    good = [m for m in meta if all(int(m[k]) == 0 for k in
                                 ('Exclude', 'Incomplete', 'Standing', 'Outlier'))]
    plt.rcParams.update({'font.family': 'Arial', 'text.color': '#0F1B1E',
                         'axes.labelcolor': '#5A6C72', 'axes.edgecolor': '#CBD8DC'})
    cmap = LinearSegmentedColormap.from_list('niva', ['#EAF0F2','#0B6F79','#14314B'])
    maps = [a.mean(axis=(0,1))]
    titles = ['All stored footsteps\nBoth feet, includes flagged steps']
    for side in ('Right','Left'):
        ids = [int(m['FootstepID']) for m in good if m['Side'] == side]
        maps.append(a[ids].mean(axis=(0,1)))
        titles.append(f'{side} foot | metadata-labelled\n{len(ids)} unflagged steps')
    fig, axs = plt.subplots(1,3,figsize=(10,6),layout='constrained')
    maximum = max(float(m.max()) for m in maps)
    for ax,m,title in zip(axs,maps,titles):
        im=ax.imshow(m,origin='upper',interpolation='nearest',aspect='equal',
                     cmap=cmap,vmin=0,vmax=maximum)
        ax.set_title(title,fontsize=11,color='#14314B')
        ax.set_xlabel('Stored column index')
        ax.set_ylabel('Stored row index (0 at top)')
    fig.suptitle('StepUP 001 / BF / W1 — mean pressure, Pipeline 1',fontsize=15)
    fig.colorbar(im, ax=axs,shrink=.7,label='Mean pressure (kPa)')
    out=ROOT/'docs/r2'
    out.mkdir(parents=True,exist_ok=True)
    fig.savefig(out/'orientation_001.png',dpi=160)
    plt.close(fig)
    print('NPZ keys: arr_0 only; no embedded scale or side metadata')
    print('Shape:',a.shape)
    for side in ('Right','Left'):
        m=next(m for m in good if m['Side']==side)
        step=a[int(m['FootstepID'])]
        yy,xx=np.where(step.max(axis=0)>0)
        print(side, 'FootstepID',m['FootstepID'], 'nonzero bbox cells',
              (int(yy.min()),int(yy.max()),int(xx.min()),int(xx.max())),
              'metadata FootLength/FootWidth cells',m['FootLength'],m['FootWidth'])
    print(out/'orientation_001.png')

if __name__=='__main__':
    main()
