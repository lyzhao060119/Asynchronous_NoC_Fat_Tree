"""Read-only remote audit of waveform time coverage; handles gzip in memory.

Run on compute nodes. Does not extract, modify, or delete source waveforms.
Outputs separate coverage and EOF integrity findings, never power signoff.
"""
import argparse, csv, gzip, json, re, traceback, hashlib
from pathlib import Path
from collections import deque

UNITS={'s':10**12,'ms':10**9,'us':10**6,'ns':1000,'ps':1,'fs':.001}

def inspect(path):
 compressed=path.suffix=='.gz'; size=path.stat().st_size
 head=b''; tail=b''; count=0; digest=hashlib.sha256()
 if compressed:
  ring=deque(maxlen=8)
  with gzip.open(path,'rb') as f:
   for chunk in iter(lambda:f.read(4*1024*1024),b''):
    if len(head)<128*1024*1024:head+=chunk
    ring.append(chunk);count+=len(chunk);digest.update(chunk)
  tail=b''.join(ring)
 else:
  with path.open('rb') as f:
   head=f.read(min(size,128*1024*1024))
   f.seek(max(0,size-32*1024*1024));tail=f.read()
  count=size
 scale=re.search(rb'\$timescale\s+(\d+)\s*(s|ms|us|ns|ps|fs)\s+\$end',head)
 if not scale:raise ValueError('missing VCD timescale')
 factor=int(scale[1])*UNITS[scale[2].decode()]
 stamps=re.findall(rb'^#(\d+)\s*$',tail,re.M)
 first=re.findall(rb'^#(\d+)\s*$',head,re.M)
 if not stamps:raise ValueError('no timestamp within 32 MiB tail')
 return dict(path=str(path),compressed=compressed,bytes=size,uncompressed_bytes=count,
             uncompressed_sha256=digest.hexdigest() if compressed else None,
             timescale_ps=factor,last_timestamp_ps=int(stamps[-1])*factor,
             first_timestamps_ps=[int(x)*factor for x in first[:5]],
             ends_with_newline=tail.endswith(b'\n'),
             last_line_preview=tail.splitlines()[-1][:120].decode(errors='replace'))

def audit(record):
 out=dict(design=record['design'],benchmark=record['benchmark'],seed=record['seed'],
          tag=record['tag'],variant=record.get('variant'),activity_dir=record['activity_dir'])
 a=Path(record['activity_dir'])
 with (a/'result.csv').open() as f:rows=list(csv.DictReader(f))
 if len(rows)!=1:raise ValueError('expected one measurement record')
 row=rows[0];start=int(row['measurement_start_ps']);end=int(row['measurement_end_ps'])
 out.update(start_ps=start,end_ps=end)
 candidates=[a/'measurement.vcd',a/'measurement.vcd.gz'];archive=None
 for p in a.glob('*archive*.json'):
  obj=json.loads(p.read_text())
  if isinstance(obj,dict) and obj.get('archive'):
   candidates.append(Path(obj['archive']));archive=obj
 # Follow dangling symlinks to archives alongside their original targets.
 p=a/'measurement.vcd'
 if p.is_symlink():candidates += [p.resolve(),Path(str(p.resolve())+'.gz')]
 candidates += [a.parent.parent/'vcd'/record['tag']/'measurement.vcd',a.parent.parent/'vcd'/record['tag']/'measurement.vcd.gz']
 p=next((p for p in candidates if p.is_file()),None)
 if p is None:
  out.update(status='MISSING_WAVEFORM',candidates=list(map(str,candidates)));return out
 out.update(inspect(p.resolve()))
 last=out['last_timestamp_ps']
 out['window_coverage_upper_bound']=max(0,min(1,(last-start)/(end-start)))
 # TB computes ps window with rounding and dump starts/ends at fractional ns.
 # Permit one VCD time quantum, not an arbitrary capture-time extension.
 tolerance=out['timescale_ps']
 if last+tolerance<end:out['status']='TRUNCATED_BEFORE_WINDOW_END'
 elif not out['ends_with_newline']:out['status']='EOF_INTEGRITY_FAIL'
 elif len(out['first_timestamps_ps'])<2 or out['first_timestamps_ps'][1]>start+tolerance:
  out['status']='START_COVERAGE_UNPROVEN'
 else:out['status']='BOUNDARY_COVERAGE_OK'
 if archive and out['compressed']:
  out['archive_hash_matches']=out['uncompressed_sha256']==archive.get('uncompressed_sha256')==archive.get('roundtrip_sha256')
  out['archive_size_matches']=out['uncompressed_bytes']==archive.get('uncompressed_bytes')
  if not out['archive_hash_matches'] or not out['archive_size_matches']:out['status']='ARCHIVE_INTEGRITY_FAIL'
 return out

if __name__=='__main__':
 ap=argparse.ArgumentParser();ap.add_argument('--inventory',required=True);ap.add_argument('--part',type=int,required=True);ap.add_argument('--parts',type=int,default=4);ap.add_argument('--output',required=True)
 args=ap.parse_args();records=json.loads(Path(args.inventory).read_text());out=[]
 for i,r in enumerate(records):
  if i%args.parts!=args.part:continue
  try:v=audit(r)
  except Exception as e:v={**r,'status':'AUDIT_ERROR','error':str(e),'traceback':traceback.format_exc()}
  out.append(v);Path(args.output).write_text(json.dumps(out,indent=2));print(json.dumps(v),flush=True)
 print('POWER_VCD_COVERAGE_AUDIT_PART_DONE',args.part,len(out),flush=True)
