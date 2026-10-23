from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
base = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r8_multicast_trace"
out = Path("results/rtl_reqout_calibration_20261022_r8_multicast_trace")
out.mkdir(parents=True, exist_ok=True)
client = connect()
try:
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        with sftp.file(f"{base}/{kind}/trace.log") as f:
            log = f.read().decode()
        (out / f"{kind}.log").write_text(log)
        print(kind, log[-18000:])
    sftp.close()
finally:
    client.close()
