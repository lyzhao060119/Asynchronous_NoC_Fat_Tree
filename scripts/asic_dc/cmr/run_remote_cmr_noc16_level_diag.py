#!/usr/bin/env python3
"""Run a hierarchy-level probe against the frozen CMR NoC16 r3 netlist."""
import os
import re
import shlex
import stat
import time
from pathlib import Path

from run_remote_cmr_flow import atomic_put, password, remote_run
import paramiko

REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
ULTRA = "/home/ghy19/Asynchronous_Router_ultra"
BASELINE = os.environ.get(
    "CMR_NOC16_DIAG_BASELINE", "20260819_cmr_noc16_tab_vctm_p50_sdf_r3"
)
RUN_ID = os.environ.get("CMR_NOC16_DIAG_RUN_ID", "20260819_cmr_noc16_tab_level_diag_r2")
CASE = "TAB-NET-UR-3f-r0p50"
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def fetch_tree(sftp, remote, local):
    local.mkdir(parents=True, exist_ok=True)
    for entry in sftp.listdir_attr(remote):
        rp, lp = remote + "/" + entry.filename, local / entry.filename
        if stat.S_ISDIR(entry.st_mode):
            fetch_tree(sftp, rp, lp)
        else:
            sftp.get(rp, str(lp))


def main():
    client = paramiko.SSHClient()
    client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    client.connect("192.168.2.8", username="ghy19", password=password(),
                   allow_agent=False, look_for_keys=False)
    remote_run(client, f"mkdir -p {ROOT}/sim/tb {ROOT}/scripts {ROOT}/logs/gls/{RUN_ID}")
    sftp = client.open_sftp()
    atomic_put(client, sftp, REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_level_probe.sv",
               f"{ROOT}/sim/tb/tb_cmr_noc16_level_probe.sv")
    atomic_put(client, sftp, REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16_level_diag.sh",
               f"{ROOT}/scripts/run_gls_cmr_noc16_level_diag.sh")
    sftp.close()
    remote_run(client, f"chmod +x {ROOT}/scripts/run_gls_cmr_noc16_level_diag.sh")
    case_file = f"{ULTRA}/sim/cases/{CASE}.case"
    wrapper = f"{ROOT}/logs/gls/{RUN_ID}/run.sh"
    body = (
        "#!/bin/bash\nset -euo pipefail\n"
        f"export CMR_REMOTE_ROOT={shlex.quote(ROOT)}\n"
        f"export CMR_NOC16_RUN_ID={shlex.quote(RUN_ID)}\n"
        f"export CMR_NOC16_NETLIST_RUN_ID={shlex.quote(BASELINE)}\n"
        f"export CMR_NOC16_CASE_NAME={shlex.quote(CASE)}\n"
        f"export CMR_NOC16_CASE_FILE={shlex.quote(case_file)}\n"
        f"exec {ROOT}/scripts/run_gls_cmr_noc16_level_diag.sh\n"
    )
    sftp = client.open_sftp()
    with sftp.file(wrapper + ".tmp", "w") as f:
        f.write(body)
    sftp.rename(wrapper + ".tmp", wrapper)
    sftp.close()
    remote_run(client, f"chmod +x {wrapper}")
    submit = remote_run(client, f"bsub -n 8 -o {ROOT}/logs/gls/{RUN_ID}/bsub.log -e {ROOT}/logs/gls/{RUN_ID}/bsub.err -J cmr_level_diag {wrapper}")
    jid = re.search(r"Job <(\d+)>", submit).group(1)
    print("DIAG_JOB", jid, flush=True)
    for _ in range(120):
        state_out = remote_run(client, f"printf '__STATE__'; bjobs -noheader -o stat {jid} 2>/dev/null | tr -d '[:space:]'; printf '\\n'")
        match = re.search(r"__STATE__([A-Z]*)", state_out)
        state = match.group(1) if match else ""
        if not state or state == "DONE":
            break
        if state in ("EXIT", "ZOMBI", "UNKWN"):
            raise RuntimeError(f"diagnostic job {jid} ended in {state}")
        print("DIAG_WAIT", state, flush=True)
        time.sleep(15)
    else:
        raise TimeoutError(jid)
    sftp = client.open_sftp()
    fetch_tree(sftp, f"{ROOT}/logs/gls/{RUN_ID}", RESULT)
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, flush=True)


if __name__ == "__main__":
    main()
