"""Freeze/upload split RTL, then run gated child DC and stitch for both networks.

Uses an isolated remote project so existing campaigns and shared RTL cannot race.
Run with D:\anaconda\python.exe. Resume with the same run directory and hashes.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tarfile
import time

REPO = Path(__file__).resolve().parents[3]
CAMPAIGN = '20261020_split1024_tt_r1'
REMOTE = '/home/ghy19/Asynchronous_Router_CMR/campaigns/' + CAMPAIGN


def main():
    from run_remote_cmr_noc64_sdf import shared_input_files
    from run_remote_cmr_noc16_sdf import connect
    local = REPO / 'scripts/asic_dc/cmr/results' / CAMPAIGN
    local.mkdir(parents=True, exist_ok=True)
    if '--resume' in sys.argv:
        run_drivers(local)
        return
    files = dict(shared_input_files())
    for name in ('run_dc_cmr_hier_child.tcl', 'run_dc_cmr_hier_stitch.tcl',
                 'apply_cmr_ipm_timing_recipe.tcl', 'apply_cmr_router_cell_recipe.tcl'):
        files[REPO/'scripts/asic_dc/cmr'/name] = 'scripts/dc/' + name
    for kind in ('mesh', 'm16'):
        bundle = REPO/'generated_cmr/split1024_20261020'/kind
        audit = json.loads((bundle/'audit.json').read_text())
        assert audit['status'] == 'PASS'
        for relative, digest in audit['hashes'].items():
            relative = relative.replace('\\', '/')
            path = bundle/relative
            assert hashlib.sha256(path.read_bytes()).hexdigest() == digest
            # Simulation primitive resources are deliberately excluded: child
            # synthesis uses the frozen ASIC resources from shared_input_files.
            if relative.startswith('top/') or path.name.startswith('CMRRouter_split_'):
                files[path] = 'rtl/split/' + kind + '/' + relative
        for name in ('routers.tsv', 'audit.json', 'source_environment.sha256'):
            files[bundle/name] = 'rtl/split/' + kind + '/' + name
        top = 'PROP_temp1024_m16' if kind == 'm16' else 'CMRMeshNoC'
        assert bundle/'top'/(top+'.v') in files, 'missing top RTL in upload manifest'
    archive = local/'inputs.tar.gz'
    hashes = {dst: hashlib.sha256(src.read_bytes()).hexdigest() for src,dst in files.items()}
    (local/'input_hashes.json').write_text(json.dumps(hashes, indent=2))
    with tarfile.open(archive, 'w:gz', compresslevel=1) as tar:
        for src,dst in files.items():
            tar.add(src, arcname=dst)
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    print('SPLIT_UPLOAD_START', len(files), archive.stat().st_size, digest, flush=True)
    client = connect()
    def remote(cmd):
        chan = client.get_transport().open_session(timeout=180)
        chan.settimeout(600)
        chan.exec_command(cmd)
        out = chan.makefile('r').read().decode()
        err = chan.makefile_stderr('r').read().decode()
        rc = chan.recv_exit_status()
        if rc: raise RuntimeError((cmd,rc,out,err))
        return out
    print(remote(f'mkdir -p {REMOTE} && df -h /home /prjtemp && bjobs -u ghy19 -o "stat slots job_name"'), flush=True)
    sftp = client.open_sftp()
    sftp.get_channel().settimeout(600)
    temporary = REMOTE+'/inputs.tar.gz.upload'
    with sftp.open(temporary, 'wb') as target, archive.open('rb') as source:
        while True:
            block = source.read(256*1024)
            if not block: break
            target.write(block)
    sftp.close()
    assert digest in remote(f'sha256sum {temporary}')
    print(remote(f'mv {temporary} {REMOTE}/inputs.tar.gz && tar -xzf {REMOTE}/inputs.tar.gz -C {REMOTE} && echo SPLIT_INPUT_UPLOAD_PASS'), flush=True)
    client.close()
    run_drivers(local)


def run_drivers(local):
    env = os.environ.copy()
    env.update(CMR_REMOTE_ROOT=REMOTE, CMR_HIER_SKIP_UPLOAD='1', CMR_HIER_SKIP_GLS='1',
               CMR_LIBRARY_CORNER='tt0p8v25c', CMR_APPLY_IPM_TIMING_RECIPE='1',
               CMR_HIER_CHILD_BATCH_SIZE='4', CMR_HIER_CHILD_BSUB='-n 4',
               CMR_HIER_STITCH_BSUB='-n 8', CMR_HIER_RESUME='1',
               CMR_DESCAL_SUBMIT_ONLY='0', CMR_HIER_SUBMIT_ONLY='0')
    # Serial networks; bounded child batches. Failed batches stop the driver.
    for kind in ('mesh', 'm16'):
        env.update(CMR_SPLIT_BUNDLE=f'generated_cmr/split1024_20261020/{kind}',
                   CMR_HIER_KIND='mesh1024' if kind == 'mesh' else 'prop_temp1024_m16',
                   CMR_HIER_STITCH_RUN_ID=CAMPAIGN+'_'+kind)
        with (local/(kind+'_driver.log')).open('a') as log:
            rc = subprocess.call([sys.executable, str(REPO/'scripts/asic_dc/cmr/run_remote_cmr_hier_dc.py')],
                                 cwd=REPO, env=env, stdout=log, stderr=subprocess.STDOUT)
        if rc: raise RuntimeError(f'{kind} DC driver failed: {rc}')
    print('SPLIT1024_DC_BOTH_COMPLETE', flush=True)


if __name__ == '__main__': main()
