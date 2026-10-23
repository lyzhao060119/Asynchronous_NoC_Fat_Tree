"""Reuse remote raw RTL; upload only small, isolated wrapper/TB inputs."""
from pathlib import Path
import sys
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
RUN = "rtl_reqout_calibration_20261022_r2"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + RUN
BASE = REMOTE[:-2] + "r1"
client = connect()
probe = "--probe" in sys.argv
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"mkdir -p {REMOTE}/{k}; cp {BASE}/{k}/*.v {REMOTE}/{k}/; cp {BASE}/{k}/rtl.f {REMOTE}/{k}/; cp -r {BASE}/{k}/hop_binds {REMOTE}/{k}/" for k in ("thin", "c1p4")))
    if ch.recv_exit_status():
        raise RuntimeError("Staging failed")
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        for filename in ("CMRRouter.v", "tb_router_matched_ppa_async.sv", "manifest.json"):
            sftp.put(str(ROOT / "results" / RUN / kind / filename), f"{REMOTE}/{kind}/{filename}")
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
for test in {"probe" if probe else "isolated packet continuous backpressure contention"}; do
 mode=isolated; paced=0; packets=1; ack=0
 case "$test" in
 isolated) paced=1;;
 continuous) packets=10;;
 backpressure) packets=10; ack=1.0;;
 contention) mode=aggregate;;
 probe) mode=aggregate;;
 esac
 ./simv +MODE=$mode +OUTPUT_PACED=$paced +SINGLE_PACKETS=$packets +ACK_DELAY_NS=$ack +NO_FULL_VCD {"+PROBE" if probe else ""} +EVENT_CSV=$test.csv > $test.log 2>&1
 grep -q 'MATCHED_RESULT PASS' $test.log
 if grep -E 'MATCHED_FAIL|Fatal|Error' $test.log; then exit 2; fi
done
echo REQOUT_SERVICE_MODEL_PASS
'''
        with sftp.file(f"{REMOTE}/run_{kind}.sh", "w") as f:
            f.write(script)
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqmodel_{k} -o {REMOTE}/{k}/lsf.log bash {REMOTE}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
    print(ch.makefile_stderr().read().decode())
finally:
    client.close()
