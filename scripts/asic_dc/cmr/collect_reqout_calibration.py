import csv
import io
import hashlib
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

remote = "/home/ghy19/Asynchronous_Router_CMR/campaigns/rtl_reqout_calibration_20261022_r1"
out = Path("results/rtl_reqout_calibration_20261022_r1")
client = connect()
rows = []
try:
    ch = client.get_transport().open_session(timeout=180)
    ch.exec_command("bjobs -a 14945601 14945701")
    print(ch.makefile().read().decode())
    sftp = client.open_sftp()
    for kind in ("thin", "c1p4"):
        evidence = {}
        for name in ("CMRRouter.v", "tb_router_matched_ppa_async.sv", "DelayElement_sim.v"):
            with sftp.file(f"{remote}/{kind}/{name}") as f:
                evidence[name] = hashlib.sha256(f.read()).hexdigest()
        (out / kind / "remote_input_hashes.json").write_text(json.dumps(evidence, indent=2))
        for delay in ("0", "0.20", "0.35", "0.4622", "0.60"):
            for paced in (0, 1):
                base = f"sweep_{delay}_{paced}"
                try:
                    with sftp.file(f"{remote}/{kind}/{base}.log") as f:
                        log = f.read().decode()
                    with sftp.file(f"{remote}/{kind}/{base}.csv") as f:
                        events = list(csv.DictReader(io.StringIO(f.read().decode())))
                except OSError:
                    print(kind, base, "NOT_READY")
                    continue
                valid = "MATCHED_RESULT PASS" in log and len(events) == 5 and "MATCHED_FAIL" not in log
                row = dict(kind=kind, delay_ns=delay, paced=paced, valid=valid, flits=len(events))
                if events:
                    row["mean_flit_ns"] = sum(float(e["latency_ns"]) - .09 for e in events) / len(events)
                    row["packet_ns"] = int(events[-1]["time_ps"]) / 1000 - .09 - float(events[0]["input_ns"])
                rows.append(row)
                print(row)
    sftp.close()
finally:
    client.close()
if rows:
    with (out / "sweep_summary.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=["kind", "delay_ns", "paced", "valid", "flits", "mean_flit_ns", "packet_ns"])
        writer.writeheader()
        writer.writerows(rows)
