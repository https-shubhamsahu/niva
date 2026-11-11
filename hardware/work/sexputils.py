import re,json
class Atom(str): pass
def parse(s):
 ts=re.findall(r'"(?:\\.|[^"\\])*"|[()]|[^\s()]+',s); stack=[]; root=None
 for t in ts:
  if t=='(':
   a=[]
   if stack:stack[-1].append(a)
   stack.append(a)
  elif t==')':
   root=stack.pop()
  else:stack[-1].append(json.loads(t) if t.startswith('"') else Atom(t))
 return root
def dump(a):
 if isinstance(a,list):return '('+' '.join(dump(v) for v in a)+')'
 return str(a) if isinstance(a,Atom) else json.dumps(str(a),ensure_ascii=False)
def find(a,k):return next((v for v in a if isinstance(v,list) and v and v[0]==k),None)
def allof(a,k):return [v for v in a if isinstance(v,list) and v and v[0]==k]
def extract(path,name):
 s=path.read_text(encoding='utf8');start=s.index('(symbol "'+name+'"');i=start;depth=0;instr=False;esc=False
 while i<len(s):
  c=s[i]
  if instr:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='"':instr=False
  elif c=='"':instr=True
  elif c=='(':depth+=1
  elif c==')':
   depth-=1
   if depth==0:return parse(s[start:i+1])
  i+=1
def resolve(path,name):
 a=extract(path,name);e=find(a,'extends')
 if e:
  p=resolve(path,e[1]);p[1]=name
  for v in allof(p,'symbol'):v[1]=v[1].replace(e[1]+'_',name+'_',1)
  props={v[1]:v for v in allof(a,'property')}
  for i,v in enumerate(p):
   if isinstance(v,list) and v and v[0]=='property' and v[1] in props:p[i]=props.pop(v[1])
  p.extend(props.values());return p
 return a
if __name__=='__main__':
 from pathlib import Path
 lib=Path(__file__).parent/'tools3d/kicad/share/kicad/symbols'
 for folder,name in [('RF_Module','ESP32-C3-MINI-1'),('Analog_ADC','MCP3208'),('Regulator_Linear','TLV75533PDBV'),('Amplifier_Operational','MCP6001-OT')]:
  a=resolve(lib/(folder+'.kicad_sym'),name);print(folder,name)
  for sym in allof(a,'symbol'):
   for pin in allof(sym,'pin'):print(find(pin,'number')[1],find(pin,'name')[1],find(pin,'at')[1:])
