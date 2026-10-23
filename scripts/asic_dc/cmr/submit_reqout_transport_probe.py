"""Diagnostic only: preserve TailCapture events in an isolated simulator copy.

No functional source or prior candidate is edited. This is NOT a physical
pulse-width fix, nor permission to call an invalid physical pulse safe.
"""
import re
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

base = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r2"
remote = base[:-2] + "r4_transport_eventprobe"
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"mkdir -p {remote}/{k}; cp {base}/{k}/*.v {remote}/{k}/; cp {base}/{k}/*.sv {remote}/{k}/; cp -r {base}/{k}/hop_binds {remote}/{k}/" for k in ("thin", "c1p4")))
    if ch.recv_exit_status():
        raise RuntimeError("Remote staging failed")
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        local_wrapper = Path(__file__).resolve().parents[3] / "results/rtl_reqout_calibration_20261022_r2" / kind / "CMRRouter.v"
        sftp.put(str(local_wrapper), f"{remote}/{kind}/CMRRouter.v")
        names = [name for name in sftp.listdir(f"{remote}/{kind}") if name.startswith("CMRRouter_split_") and name.endswith(".v")]
        if len(names) != 1:
            raise RuntimeError(names)
        path = f"{remote}/{kind}/{names[0]}"
        with sftp.file(path) as f:
            raw = f.read().decode()
        raw, count = re.subn(r"DelayElement (#[^\n]+ TailCaptureDelay_\d+ \()", r"TransportDelayElement \1", raw)
        if count < 4:
            raise RuntimeError(f"Tail capture binding failed: {count}")
        with sftp.file(path, "w") as f:
            f.write(raw)
        with sftp.file(f"{remote}/{kind}/TransportDelayElement.v", "w") as f:
            f.write('''`timescale 1ns/1ps
// Diagnostic event transport, NOT a physical timing model.
module TransportDelayElement #(parameter DelayValue=1, DelayUnitPs=50)(input I, output reg Z);
 always @(I) Z <= #(0.2*DelayValue) I;
endmodule
''')
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {remote}/{kind}
find . -maxdepth 1 -name '*.v' ! -name '*_ASIC.v' | sort > rtl.f
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
./simv +MODE=aggregate +PROBE +NO_FULL_VCD +EVENT_CSV=probe.csv > probe.log 2>&1
grep -q 'MATCHED_RESULT PASS' probe.log
echo TRANSPORT_DIAGNOSTIC_PASS
'''
        with sftp.file(f"{remote}/run_{kind}.sh", "w") as f:
            f.write(script)
        print(kind, "TailCapture instances modified in diagnostic only:", count)
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqtransport_{k} -o {remote}/{k}/lsf.log bash {remote}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
