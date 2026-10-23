"""Independent loaded validation with the frozen GLS benchmark parameters."""
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
ROOT = Path(__file__).resolve().parents[3]
BASE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r9_multicast_ordering"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r11_loaded_validation"
client = connect()
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command(f"mkdir -p {REMOTE}/thin {REMOTE}/c1p4")
    if ch.recv_exit_status():
        raise RuntimeError("Stage failed")
    sftp = client.open_sftp()
    sftp.put(str(ROOT / "scripts/asic_dc/cmr/reduce_reqout_loaded_remote.py"),REMOTE + "/reduce.py")
    for kind in ("thin", "c1p4"):
        with sftp.file(f"{REMOTE}/run_{kind}.sh", "w") as f:
            f.write(f'''#!/bin/bash
set -eu
cd {BASE}/{kind}
./simv +MODE=aggregate +DATA_RANDOM=1 +TX_SETUP_NS=0.05 +RX_CAPTURE_NS=0.09 +NO_FULL_VCD +EVENT_CSV={REMOTE}/{kind}/events.csv > {REMOTE}/{kind}/run.log 2>&1
grep -q 'MATCHED_RESULT PASS' {REMOTE}/{kind}/run.log
/soft/GNU/python3.12/bin/python3 {REMOTE}/reduce.py {REMOTE}/{kind}
echo MODEL_LOADED_VALIDATION_FUNCTIONAL_PASS
''')
    sftp.close()
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("; ".join(f"bsub -n 1 -J reqload_{k} -o {REMOTE}/{k}/lsf.log bash {REMOTE}/run_{k}.sh" for k in ("thin", "c1p4")))
    print(ch.makefile().read().decode())
finally:
    client.close()
