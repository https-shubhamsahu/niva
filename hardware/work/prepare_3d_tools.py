from pathlib import Path
import urllib.request, concurrent.futures, subprocess
root=Path(__file__).resolve().parent/'tools3d';root.mkdir(exist_ok=True)
jobs=[('blender.zip','https://download.blender.org/release/Blender4.5/blender-4.5.9-windows-x64.zip','blender'),('kicad.exe','https://mirrors.mit.edu/kicad/windows/stable/kicad-9.0.9-x86_64.exe','kicad')]
def run(job):
 name,url,dest=job;p=root/name
 if not p.exists():
  print('Downloading '+name,flush=True)
  with urllib.request.urlopen(url,timeout=120) as r, p.open('wb') as f:
   while b:=r.read(4*1024*1024):f.write(b)
 print(f'{name}: {p.stat().st_size//1048576} MB',flush=True)
 target=root/dest;target.mkdir(exist_ok=True)
 result=subprocess.run([r'C:\Users\shubh\scoop\shims\7z.exe','x',str(p),f'-o{target}','-y'],capture_output=True,text=True)
 print(dest+' extraction exit '+str(result.returncode)+' '+result.stdout[-300:],flush=True)
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(run,jobs))
