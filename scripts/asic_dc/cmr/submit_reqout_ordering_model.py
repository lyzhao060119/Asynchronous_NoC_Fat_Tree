"""Test evidence-based simulator ordering, isolated from production RTL.

Keep transport TailCapture model from r4. c1p4 Ack guard is 260 ps vs the
old functional model's 200 ps; the observed next-Head/release deficit was
50 ps. This is a simulator contract, NOT a physical library DEL size.
"""
import hashlib
import json
import re
import argparse
from run_remote_cmr_noc16_sdf import connect

BASE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r4_transport_eventprobe"
parser = argparse.ArgumentParser()
parser.add_argument("--run", default="rtl_reqout_calibration_20261022_r6_ordering_model")
parser.add_argument("--guard-all", type=float)
args = parser.parse_args()
if not re.fullmatch(r"[A-Za-z0-9_]+", args.run):
    raise ValueError("Unsafe run name")
if args.guard_all is not None and not (0 < args.guard_all < 2):
    raise ValueError("Guard must be positive and below 2 ns")
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + args.run
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"mkdir -p {REMOTE}/{k}; cp {BASE}/{k}/*.v {REMOTE}/{k}/; cp {BASE}/{k}/*.sv {REMOTE}/{k}/; cp -r {BASE}/{k}/hop_binds {REMOTE}/{k}/" for k in ("thin", "c1p4")))
    if ch.recv_exit_status():
        raise RuntimeError("Remote staging failed")
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        changes = 0
        guard = args.guard_all if args.guard_all is not None else (.260 if kind == "c1p4" else .200)
        if kind == "c1p4" or args.guard_all is not None:
            names = [name for name in sftp.listdir(f"{REMOTE}/{kind}") if name.startswith("CMRRouter_split_") and name.endswith(".v")]
            if len(names) != 1:
                raise RuntimeError(names)
            path = f"{REMOTE}/{kind}/{names[0]}"
            with sftp.file(path) as f:
                raw = f.read().decode()
            raw, changes = re.subn(r"DelayElement (#[^\n]+ AckoutGuard \()", r"ModelAckGuard \1", raw)
            if changes < 1:
                raise RuntimeError(f"Ack guard binding failed: {changes}")
            with sftp.file(path, "w") as f:
                f.write(raw)
            with sftp.file(f"{REMOTE}/{kind}/ModelAckGuard.v", "w") as f:
                f.write(f'''`timescale 1ns/1ps
// Simulator ordering contract; not a measured cell or physical protection.
module ModelAckGuard #(parameter DelayValue=1, DelayUnitPs=50)(input I, output Z);
 assign #({guard:.6f}*DelayValue) Z=I;
endmodule
''')
        hashes = {}
        for name in sftp.listdir(f"{REMOTE}/{kind}"):
            if name.endswith((".v", ".sv")):
                with sftp.file(f"{REMOTE}/{kind}/{name}") as f:
                    hashes[name] = hashlib.sha256(f.read()).hexdigest()
        manifest = dict(scope="RTL simulation surrogate; not STA/SDF signoff", kind=kind,
                        source=BASE, tail_capture="transport 200 ps event delay",
                        ack_guard_ns=guard,
                        ackguard_bound_module_definitions=changes, sha256=hashes)
        with sftp.file(f"{REMOTE}/{kind}/manifest.json", "w") as f:
            f.write(json.dumps(manifest, indent=2))
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
find . -maxdepth 1 -name '*.v' ! -name '*_ASIC.v' | sort > rtl.f
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
for test in isolated packet continuous backpressure contention; do
 mode=isolated; paced=0; packets=1; ack=0
 case "$test" in
 isolated) paced=1;;
 continuous) packets=10;;
 backpressure) packets=10; ack=1.0;;
 contention) mode=aggregate;;
 esac
 ./simv +MODE=$mode +OUTPUT_PACED=$paced +SINGLE_PACKETS=$packets +ACK_DELAY_NS=$ack +NO_FULL_VCD +EVENT_CSV=$test.csv > $test.log 2>&1
 grep -q 'MATCHED_RESULT PASS' $test.log
 if grep -E 'MATCHED_FAIL|Fatal|Error' $test.log; then exit 2; fi
done
echo ORDERING_MODEL_TESTS_PASS
'''
        with sftp.file(f"{REMOTE}/run_{kind}.sh", "w") as f:
            f.write(script)
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqorder_{k} -o {REMOTE}/{k}/lsf.log bash {REMOTE}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
