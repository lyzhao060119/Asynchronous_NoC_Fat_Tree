"""Replay frozen PFAT prefix boundary without changing DUT or assertions."""
import json
import re
import shlex
from datetime import datetime
from run_remote_cmr_noc16_sdf import connect
from run_remote_cmr_flow import remote_run

CAMPAIGN = '/prjtemp/ghy19/date2027_formal64/20261015_193500_formal64_multicast_inputs_r1'

def main():
    run = datetime.now().strftime('%Y%m%d_%H%M%S') + '_pfat_prefix_router_diag'
    root = '/prjtemp/ghy19/date2027_formal64/' + run
    client = connect()
    try:
        print(remote_run(client, 'set -e\ntest -x ' + CAMPAIGN + '/work/PFAT64/simv\nmkdir ' + shlex.quote(root)))
        sftp = client.open_sftp()
        for count in (354, 355):
            case = CAMPAIGN + f'/cases/diagnostic/PFAT64_MC5_s202701_m5_diag7_prefix{count}.case'
            out = root + f'/prefix{count}'
            wave = f' +DUMP_VCD={out}/trace.vcd' if count == 355 else ''
            script = f'''#!/bin/bash
set -euo pipefail
mkdir {out}
cd {out}
sha256sum {case} {CAMPAIGN}/work/PFAT64/simv > input_hashes.log
cp {CAMPAIGN}/work/PFAT64/input_hashes.log compile_input_hashes.log
{CAMPAIGN}/work/PFAT64/simv +CASE_FILE={case} +RESULT_CSV={out}/result.csv +EVENT_CSV={out}/events.csv +LATENCY_CSV={out}/latency.csv +FLIT_LATENCY_CSV={out}/flit_latency.csv +MISSING_CSV={out}/missing.csv +V3_METRICS_CSV={out}/metrics.csv +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +STALL_TIMEOUT_NS=50000 +HARD_TIMEOUT_NS=400000{wave} -l {out}/run.log > {out}/stdout.log 2>&1
echo PFAT_DIAGNOSTIC_REPLAY_FINISHED
'''
            path = root + f'/prefix{count}.sh'
            with sftp.open(path, 'w') as f:
                f.write(script)
            command = f"bsub -n 1 -m 'node21 node26 node24 node18' -W 30 -o {root}/prefix{count}.job.log -e {root}/prefix{count}.job.err -J pfdiag{count} bash {path}"
            answer = remote_run(client, command)
            match = re.search(r'Job <(\d+)>', answer)
            if not match:
                raise RuntimeError(answer)
            print(json.dumps({'run': run, 'prefix': count, 'job_id': match[1], 'output': out}), flush=True)
        sftp.close()
    finally:
        client.close()

if __name__ == '__main__':
    main()
