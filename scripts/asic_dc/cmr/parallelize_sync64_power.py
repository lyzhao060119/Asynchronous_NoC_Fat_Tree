"""Release Sync power pipeline stalls without overlapping SDF log slots.

Remote scheduler-only change. No resubmission, source edits or waveform edits.
LSF's verified 32-slot user limit continues to enforce account capacity.
"""
import json, re, subprocess, time
from pathlib import Path

ROOT=Path('/prjtemp/ghy19/formal64_power_supplement/20261021_sync_and_broadcast_r1')

def state(job):
    p=subprocess.run(['bjobs','-noheader','-o','stat',str(job)],capture_output=True,text=True)
    return p.stdout.strip() if p.returncode==0 else 'HISTORY_NOT_AVAILABLE'

def main():
    assert not (ROOT/'parallel_pipeline_r3.json').exists(),'already adjusted; inspect first'
    u=subprocess.check_output(['busers','ghy19'],text=True)
    print(u,flush=True)
    row=next(l.split() for l in u.splitlines() if l.startswith('ghy19 '))
    assert int(row[2])==32,'unexpected account limit'
    space=__import__('os').statvfs(ROOT)
    assert space.f_bavail*space.f_frsize>500*1024**3,'less than 500 GiB scratch headroom'
    jobs=[j for j in json.loads((ROOT/'manifest.json').read_text())['jobs'] if j['design']=='SYNC_M16']
    assert len(jobs)==24
    updates=[]
    for i,j in enumerate(jobs):
        s=state(j['activity_job'])
        if s!='PEND':continue
        prev=jobs[i-2] if i>=2 else None
        if prev and state(prev['activity_job']) in ['RUN','PEND']:
            # Same parity uses the same immutable compiled SDF log slot.
            dep='done(%s)'%prev['activity_job']
            cmd=['bmod','-w',dep,str(j['activity_job'])]
        elif prev:
            a=Path(prev['activity_dir'])
            run=(a/'run.log').read_text(errors='replace')
            sdf=(a/'sdf_annotate.log').read_text(errors='replace')
            assert 'TB_RESULT PASS' in run and re.search(r'Total errors:\s*0\b',sdf),prev['tag']
            dep='none: previous same-slot capture completed'
            cmd=['bmod','-wn',str(j['activity_job'])]
        else:raise RuntimeError('unexpected pending initial capture')
        result=subprocess.check_output(cmd,text=True)
        updates.append(dict(tag=j['tag'],job=j['activity_job'],dependency=dep,command=cmd,result=result))
        (ROOT/'parallel_pipeline_r3.json').write_text(json.dumps(dict(time=time.strftime('%Y-%m-%d %H:%M:%S'),account_limit=32,annotation_lanes=2,updates=updates),indent=2))
        print(j['tag'],dep,result.strip(),flush=True)
    print('SYNC_POWER_PIPELINE_PARALLELIZED captures_updated='+str(len(updates)),flush=True)
    print(subprocess.check_output(['busers','ghy19'],text=True),flush=True)

if __name__=='__main__':main()
