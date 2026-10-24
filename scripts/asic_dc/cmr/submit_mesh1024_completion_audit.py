"""Queue final artifact/hash audit on a compute slot, without large downloads."""
import json
import re
import shlex
from run_remote_cmr_noc16_sdf import connect
from submit_mesh1024_quadrants import LOCAL, REMOTE

AUDIT = r'''
import hashlib,json,os,re,sys,time
from pathlib import Path
r=Path(sys.argv[1]); checks=[]
source=Path('/home/ghy19/Asynchronous_Router_CMR/campaigns/20261020_split1024_tt_r1/rtl/split/mesh/top/CMRMeshNoC.v')
source_hash=hashlib.sha256(source.read_bytes()).hexdigest()
assert source_hash=='ff5d92d0b4cff1f94a8801c36c60e5d70b510d4aaa41b1235fba65d069b650e1','frozen_source_changed'
for q in range(5):
    top='Mesh1024Quadrant'+str(q) if q<4 else 'CMRMeshNoC'
    log=r/'logs'/('q'+str(q)+'_r4.log' if q<4 else 'final_r4.log')
    text=log.read_text(errors='replace')
    marker=('MESH_QUADRANT_PASS' if q<4 else 'MESH1024_FOUR_BLOCK_PASS')
    expected=256 if q<4 else 1024
    errors=re.findall(r'^(?:Error:|MESH_BLOCK_FAIL|NAME_COLLISION_REQUIRES_AUDIT|QUADRANT_LOG_ERROR).*',text,re.M)
    assert not errors,(top,errors[:5])
    assert '(UIO-92)' not in text,(top,'name_collision')
    assert re.search(r'^'+marker+r' top='+top+r' routers='+str(expected)+r'$',text,re.M),(top,'pass_missing')
    folder=r/'outputs'/top
    entries=[]
    for line in (folder/'hashes.sha256').read_text().splitlines():
        digest,path=line.split(maxsplit=1);p=Path(path.strip())
        assert p.parent==folder and p.stat().st_size>0
        h=hashlib.sha256()
        with p.open('rb') as f:
            for chunk in iter(lambda:f.read(8*1024*1024),b''): h.update(chunk)
        assert h.hexdigest()==digest,(str(p),'hash_mismatch')
        entries.append(dict(name=p.name,size=p.stat().st_size,sha256=digest))
    assert {a['name'] for a in entries}=={top+'.ddc',top+'_post.v',top+'.sdf'}
    with (folder/(top+'.sdf')).open('rb') as f:
        header=f.read(4096)
        assert ('(DESIGN "'+top+'")').encode() in header,(top,'sdf_design_mismatch')
        assert b'(PROCESS "tt0p8v25c")' in header,(top,'sdf_corner_mismatch')
        assert b'(VOLTAGE 0.80:0.80:0.80)' in header,(top,'sdf_voltage_mismatch')
        assert b'(TEMPERATURE 25.00:25.00:25.00)' in header,(top,'sdf_temperature_mismatch')
        f.seek(max(0,os.fstat(f.fileno()).st_size-4096))
        assert f.read().rstrip().endswith(b')'),(top,'sdf_truncated')
    checks.append(dict(top=top,routers=expected,passed=True,artifacts=entries))
    print('ARTIFACT_AUDIT_PASS '+top,flush=True)
partition=json.loads((r/'partition_audit.json').read_text())
assert partition['status']=='PASS' and partition['router_instances']==1024 and partition['cross_quadrant_signals']==384
result=dict(status='PASS',checked_unix=time.time(),objects=checks,partition=partition,source_top_sha256=source_hash,
            audit_script_sha256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),corner='tt0p8v25c',
            scope='Mapped hierarchical assembly and artifact integrity, not STA/SDF simulation signoff')
(r/'completion_audit.json').write_text(json.dumps(result,indent=2))
print('MESH1024_COMPLETION_AUDIT_PASS',flush=True)
'''


def main():
    jobs=json.loads((LOCAL/'jobs.json').read_text())
    assert 'audit_job' not in jobs,'audit already submitted'
    c=connect();s=c.open_sftp()
    with s.open(REMOTE+'/scripts/completion_audit.py','w') as f:f.write(AUDIT)
    shell='#!/bin/bash\nset -eo pipefail\n/soft/GNU/python3.12/bin/python3 '+REMOTE+'/scripts/completion_audit.py '+REMOTE+'\n'
    with s.open(REMOTE+'/scripts/completion_audit.sh','w') as f:f.write(shell)
    cmd=f'bsub -n 1 -w "done({jobs["namesafe_final_job"]})" -J mesh1024_artifact_audit -o {REMOTE}/logs/completion_audit.log -e {REMOTE}/logs/completion_audit.err bash {REMOTE}/scripts/completion_audit.sh'
    _,o,e=c.exec_command(cmd,timeout=60);out=o.read().decode();err=e.read().decode()
    if o.channel.recv_exit_status():raise RuntimeError(out+err)
    print(out,flush=True);jobs['audit_job']=re.search(r'Job <(\d+)>',out)[1]
    (LOCAL/'jobs.json').write_text(json.dumps(jobs,indent=2));s.close();c.close()


if __name__=='__main__':main()
