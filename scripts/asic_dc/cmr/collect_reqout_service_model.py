import csv
import io
import json
import argparse
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
parser = argparse.ArgumentParser()
parser.add_argument("--run", default="rtl_reqout_calibration_20261022_r2")
RUN = parser.parse_args().run
if "/" in RUN or "\\" in RUN or ".." in RUN:
    raise ValueError("Run must be a directory name")
(ROOT / "results" / RUN).mkdir(parents=True, exist_ok=True)
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + RUN
rows = []
client = connect()
try:
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        (ROOT / "results" / RUN / kind).mkdir(parents=True, exist_ok=True)
        try:
            with sftp.file(f"{REMOTE}/{kind}/manifest.json") as file:
                (ROOT / "results" / RUN / kind / "remote_manifest.json").write_bytes(file.read())
        except OSError:
            pass
        for test in ("isolated", "packet", "continuous", "backpressure", "contention"):
            try:
                with sftp.file(f"{REMOTE}/{kind}/{test}.log") as f:
                    log = f.read().decode()
                with sftp.file(f"{REMOTE}/{kind}/{test}.csv") as f:
                    events = list(csv.DictReader(io.StringIO(f.read().decode())))
            except OSError:
                print(kind, test, "NOT_READY")
                continue
            expected = 48000 if test == "contention" else 50 if test in ("continuous", "backpressure") else 5
            valid = "MATCHED_RESULT PASS" in log and len(events) == expected and not any(
                bad in log for bad in ("MATCHED_FAIL", "Fatal", "Error"))
            row = dict(kind=kind, test=test, valid=valid, count=len(events), expected=expected)
            if events:
                row["mean_flit_ns"] = sum(float(e["latency_ns"])-.09 for e in events)/len(events)
                if test in ("isolated", "packet"):
                    row["packet_ns"] = int(events[-1]["time_ps"])/1000-.09-float(events[0]["input_ns"])
            if not valid:
                print(log[-1800:])
            print(row)
            rows.append(row)
            # Only summaries and ten-event calibration traces are downloaded.
            if test in ("isolated", "packet"):
                with (ROOT / "results" / RUN / kind / f"{test}.csv").open("w", newline="") as f:
                    writer = csv.DictWriter(f, fieldnames=list(events[0]) if events else ["no_events"])
                    writer.writeheader()
                    writer.writerows(events)
    sftp.close()
finally:
    client.close()
(ROOT / "results" / RUN / "summary.json").write_text(json.dumps(rows, indent=2))
