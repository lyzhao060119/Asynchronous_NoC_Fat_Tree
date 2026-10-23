"""Run isolated-model sweeps; preserve all original sources and prior logs."""
from run_remote_cmr_noc16_sdf import connect
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1"

client = connect()
try:
    sftp = client.open_sftp()
    path = REMOTE + "/thin/tb_router_matched_ppa_async.sv"
    with sftp.file(path) as file:
        tb = file.read().decode()
    tb = tb.replace("6'd8", "6'd0")
    with sftp.file(path, "w") as file:
        file.write(tb)
    for kind in ("thin", "c1p4"):
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
"$VCS_HOME/bin/vcs" -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile_sweep.log 2>&1
for delay in 0 0.20 0.35 0.4622 0.60; do
 for paced in 0 1; do
  ./simv +MODE=isolated +OUTPUT_PACED=$paced +REQOUT_DELAY_NS=$delay +NO_FULL_VCD +EVENT_CSV=sweep_${{delay}}_${{paced}}.csv > sweep_${{delay}}_${{paced}}.log 2>&1
 done
done
echo REQOUT_SWEEP_FINISHED
'''
        with sftp.file(REMOTE + f"/sweep_{kind}.sh", "w") as file:
            file.write(script)
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqsweep_{k} -o {REMOTE}/{k}/sweep_lsf.log bash {REMOTE}/sweep_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
    print(ch.makefile_stderr().read().decode())
finally:
    client.close()
