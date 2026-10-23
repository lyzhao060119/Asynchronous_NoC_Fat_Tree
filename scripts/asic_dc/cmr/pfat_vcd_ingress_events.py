"""Print request-edge data snapshots for selected PFAT boundary ports (ps)."""
import sys,re,json,bisect
stack=[]; signals={}; histories={}; now=0
pat=re.compile(sys.argv[2])
with open(sys.argv[1]) as f:
 for line in f:
  p=line.split()
  if not p:continue
  if p[0]=='$scope':stack.append(p[2])
  elif p[0]=='$upscope':stack.pop()
  elif p[0]=='$var':
   name='.'.join(stack)+'.'+p[4]+''.join(p[5:-1])
   if pat.search(name):signals.setdefault(p[3],[]).append(name);histories[p[3]]=[]
  elif p[0]=='$enddefinitions':break
 for line in f:
  p=line.split()
  if not p:continue
  if p[0][0]=='#':now=int(p[0][1:]);continue
  if p[0][0] in 'bBrR' and len(p)==2:code=p[1];value=p[0][1:]
  elif p[0][0] in '01xXzZ':code=p[0][1:];value=p[0][0]
  else:continue
  if code in signals:histories[code].append((now,value))
byname={name:histories[code] for code,names in signals.items() for name in names}
for name,h in byname.items():
 if not name.endswith('_HS_Req'):continue
 base=name[:-7]
 for t,req in h:
  if t<5800000:continue
  bits=[]
  for i in range(27,-1,-1):
   hist=byname.get(base+'_Data_flit['+str(i)+']',[])
   j=bisect.bisect_right(hist,(t,'z'))-1
   bits.append(hist[j][1] if j>=0 else 'x')
  data=''.join(bits)
  print(json.dumps([base,t,req,hex(int(data,2)) if set(data)<=set('01') else data]))
