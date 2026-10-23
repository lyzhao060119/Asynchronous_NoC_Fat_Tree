"""Inspect remote power inputs without transferring waveforms."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
from run_remote_cmr_noc16_sdf import connect
from launch64_power_supplement import ROOT
import base64

CODE = r'''
from pathlib import Path
import json
R=Path(__ROOT__)
for p in sorted((R/'vcd').glob('*/measurement.vcd')):
 stack=[]; found=[]; stamp=[]
 with p.open(errors='replace') as f:
  for line in f:
   words=line.split()
   if words[:1]==['$scope']:
    stack.append(words[2])
    if words[2]=='dut':found.append('/'.join(stack))
   elif words[:1]==['$upscope']:stack.pop()
   elif words[:1]==['$enddefinitions']:break
  for line in f:
   if line.startswith('#'):
    stamp.append(line.strip())
    if len(stamp)==4:break
 print(json.dumps(dict(file=str(p),bytes=p.stat().st_size,dut_paths=found,first_timestamps=stamp)),flush=True)
'''.replace('__ROOT__',repr(ROOT))
if __name__=='__main__':
 c=connect();c.get_transport().channel_timeout=600
 payload=base64.b64encode(CODE.encode()).decode()
 cmd='/soft/GNU/python3.12/bin/python3 -c "import base64;exec(base64.b64decode(\''+payload+'\'))"'
 i,o,e=c.exec_command(cmd,timeout=600)
 for line in o:print(line,end='',flush=True)
 print(e.read().decode());c.close()
