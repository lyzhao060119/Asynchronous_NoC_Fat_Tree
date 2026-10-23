"""Independent zero-added-delay comparator for the identical aggregate stimulus."""
from run_remote_cmr_noc16_sdf import connect
from pathlib import Path
import sys

client = connect()
remote = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r2"
if "--transport" in sys.argv:
    remote = remote[:-2] + "r4_transport_eventprobe"
try:
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
mkdir -p {remote}/raw_{kind}
cd {remote}/raw_{kind}
cp ../{kind}/*.v .
cp ../{kind}/*.sv .
cp ../{kind}/rtl.f .
cp -r ../{kind}/hop_binds .
cp /home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1/{kind}/CMRRouter.v .
find . -maxdepth 1 -name '*.v' ! -name '*_ASIC.v' | sort > rtl.f
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
./simv +MODE=aggregate +REQOUT_DELAY_NS=0 +NO_FULL_VCD +EVENT_CSV=contention.csv > contention.log 2>&1
grep -q 'MATCHED_RESULT PASS' contention.log
'''
        with sftp.file(remote + f"/raw_{kind}.sh", "w") as file:
            file.write(script)
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqraw_{k} -o {remote}/raw_{k}_lsf.log bash {remote}/raw_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
