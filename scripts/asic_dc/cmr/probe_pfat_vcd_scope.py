import sys, re, json
from collections import defaultdict, deque
stack=[]; signals={}; hist=defaultdict(lambda:deque(maxlen=8)); now=0
pattern=re.compile(sys.argv[2])
with open(sys.argv[1]) as f:
 for line in f:
  p=line.split()
  if not p: continue
  if p[0]=='$scope':stack.append(p[2])
  elif p[0]=='$upscope':stack.pop()
  elif p[0]=='$var':
   name='.'.join(stack)+'.'+p[4]+(''.join(p[5:-1]))
   if pattern.search(name):signals.setdefault(p[3],[]).append(name)
  elif p[0]=='$enddefinitions':break
 for line in f:
  p=line.split()
  if not p:continue
  if p[0][0]=='#':now=int(p[0][1:]);continue
  if p[0][0] in 'bBrR' and len(p)==2:code=p[1];value=p[0][1:]
  elif p[0][0] in '01xXzZ':code=p[0][1:];value=p[0][0]
  else:continue
  if code in signals:hist[code].append((now,value))
for code,names in signals.items():
 for name in names:print(json.dumps([name,list(hist[code])]))
