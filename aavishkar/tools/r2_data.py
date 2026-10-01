"""Fetch only the declared R2 subset, checking FRDR's published SHA256 values."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / 'data/stepup-p150'
OUT = ROOT / 'docs/r2'
BASE = 'https://www.frdr-dfdr.ca/repo/files/1/published/publication_1280/submitted_data/'
PARTICIPANTS = tuple(range(2,14))
CONDITIONS = ('BF','ST')

def sha(path):
    with Path(path).open('rb') as f:
        return hashlib.file_digest(f,'sha256').hexdigest()

def fetch(relative, destination):
    if destination.exists():
        return
    destination.parent.mkdir(parents=True,exist_ok=True)
    part=destination.with_suffix(destination.suffix+'.part')
    request=urllib.request.Request(BASE+relative,headers={'User-Agent':'Niva-R2-research/1.0'})
    with urllib.request.urlopen(request,timeout=90) as response, part.open('wb') as f:
        shutil.copyfileobj(response,f)
    part.replace(destination)

def downloads():
    OUT.mkdir(parents=True,exist_ok=True)
    # The older submitted text manifest predates updated NPZ files. FRDR's
    # publication-level manifest records the current checksums.
    checks=DATA/'checksum_info.json'
    fetch('../checksum_info.json',checks)
    current=json.loads(checks.read_text(encoding='utf-8'))
    if current['algorithm'] != 'sha256':
        raise ValueError('Unsupported FRDR checksum algorithm')
    hashes={r['filepath'].removeprefix('./'):r['checksum'] for r in current['checksums']}
    jobs=[f'py/{p:03}/{c}/W1/{f}' for p in PARTICIPANTS for c in CONDITIONS
          for f in ('pipeline_1.npz','metadata.csv')]
    def one(rel):
        dest=DATA/rel.removeprefix('py/')
        fetch(rel,dest)
        digest=sha(dest)
        if digest!=hashes.get(rel):
            raise ValueError(f'Published checksum mismatch: {rel}')
        return {'file':dest.relative_to(ROOT).as_posix(),'url':BASE+rel,
                'sha256':digest,'bytes':dest.stat().st_size,'verified_frdr':True,
                'checksum_manifest_sha256':sha(checks),
                'checksum_manifest_date':current['generated_datetime']}
    records=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures={pool.submit(one,rel):rel for rel in jobs}
        for future in concurrent.futures.as_completed(futures):
            rel=futures[future]
            try:
                records.append(future.result())
                print('Verified',rel,flush=True)
            except Exception as e:
                records.append({'url':BASE+rel,'error':str(e)})
                print('UNAVAILABLE',rel,str(e),flush=True)
    (OUT/'inputs.json').write_text(json.dumps(sorted(records,key=lambda r:r['url']),indent=2)+'\n')
    if any('error' in r for r in records):
        raise SystemExit('Download failures recorded; retry download before QA.')

if __name__=='__main__':
    downloads()
