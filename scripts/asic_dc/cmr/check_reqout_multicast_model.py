import json
import argparse
import re
import hashlib
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect
parser = argparse.ArgumentParser()
parser.add_argument("--run", default="rtl_reqout_calibration_20261022_r7_multicast")
args = parser.parse_args()
if not re.fullmatch(r"[A-Za-z0-9_]+",args.run):
    raise ValueError("Unsafe run name")
base = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + args.run
client = connect()
rows = []
try:
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        for delay in ("0", "0.5", "2"):
            try:
                with sftp.file(f"{base}/{kind}/multicast_{delay}.log") as file:
                    log = file.read().decode()
            except OSError:
                print(kind, delay, "NOT_READY")
                continue
            marker = re.search(r"MODEL_MULTICAST_PASS kind=\w+ input_flits=(\d+) delivered=(\d+) expected=(\d+)",log)
            expected = 200 if kind == "thin" else 400
            valid = bool(marker and tuple(map(int,marker.groups()))==(100,expected,expected)) and not any(
                bad in log for bad in ("Fatal", "Error"))
            row = dict(kind=kind, branch_ack_ns=float(delay), valid=valid,
                       input_flits=100 if marker else None, delivered=int(marker[2]) if marker else None,
                       expected=expected, log_sha256=hashlib.sha256(log.encode()).hexdigest(), evidence=log[-2000:])
            rows.append(row)
            print(kind, delay, marker.group() if valid else log[-1800:])
    sftp.close()
finally:
    client.close()
Path("results",args.run,"summary.json").write_text(json.dumps(rows, indent=2))
