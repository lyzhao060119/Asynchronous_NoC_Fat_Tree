"""Upload staged simulation inputs and submit two one-slot baseline jobs."""
import io
import tarfile
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
LOCAL = ROOT / "results/rtl_reqout_calibration_20261022_r1"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1"
client = connect()
try:
    channel = client.get_transport().open_session(timeout=180)
    channel.exec_command(f"mkdir -p {REMOTE}")
    if channel.recv_exit_status():
        raise RuntimeError("Remote mkdir failed")
    blob = io.BytesIO()
    with tarfile.open(fileobj=blob, mode="w:gz") as archive:
        for path in LOCAL.rglob("*"):
            if path.is_file():
                archive.add(path, arcname=str(path.relative_to(LOCAL)).replace("\\", "/"))
    sftp = client.open_sftp()
    with sftp.file(REMOTE + "/inputs.tgz", "wb") as target:
        target.write(blob.getvalue())
    for kind in ("thin", "c1p4"):
        define = "+define+GEOM_C1_P4" if kind == "c1p4" else ""
        script = f'''#!/bin/bash
set -eu
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd {REMOTE}/{kind}
find . -maxdepth 1 -name '*.v' ! -name '*_ASIC.v' | sort > rtl.f
/soft/synopsys/vcs/V-2023.12/bin/vcs -full64 -sverilog -timescale=1ns/1ps +incdir+hop_binds {define} -f rtl.f tb_router_matched_ppa_async.sv -top tb_router_matched_ppa_async -o simv > compile.log 2>&1
for paced in 0 1; do
 ./simv +MODE=isolated +OUTPUT_PACED=$paced +REQOUT_DELAY_NS=0 +NO_FULL_VCD +EVENT_CSV=events_$paced.csv > baseline_$paced.log 2>&1
 grep -q 'MATCHED_RESULT PASS' baseline_$paced.log
done
echo REQOUT_BASELINE_PASS
'''
        with sftp.file(REMOTE + f"/run_{kind}.sh", "w") as target:
            target.write(script)
    sftp.close()
    command = f"cd {REMOTE} && tar xzf inputs.tgz && " + " && ".join(
        f"bsub -n 1 -J reqcal_{kind} -o {REMOTE}/{kind}/lsf.log bash {REMOTE}/run_{kind}.sh"
        for kind in ("thin", "c1p4"))
    channel = client.get_transport().open_session(timeout=180)
    channel.exec_command(command)
    print(channel.makefile().read().decode())
    print(channel.makefile_stderr().read().decode())
    if channel.recv_exit_status():
        raise RuntimeError("Submission failed")
finally:
    client.close()
