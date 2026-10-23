"""Read only reduced JSON and compare with the frozen single-router GLS audit."""
import json
from pathlib import Path
from run_remote_cmr_noc16_sdf import connect

ROOT = Path(__file__).resolve().parents[3]
RUN = "rtl_reqout_calibration_20261022_r11_loaded_validation"
REMOTE = "/home/ghy19/Asynchronous_Router_CMR/campaigns/" + RUN
out = ROOT / "results" / RUN
out.mkdir(parents=True, exist_ok=True)
reference_latency = json.loads((ROOT / "results/single_router_latency_power_audit_20261022_r3/summary.json").read_text())
reference_gls = json.loads((ROOT / "scripts/asic_dc/cmr/results/single_router_latency_power_20261022_r3/gls_summary.json").read_text())
client = connect()
rows = []
try:
    sftp = client.open_sftp()
    for kind, config in (("thin","async_c1p1"),("c1p4","async_c1p4")):
        try:
            with sftp.file(f"{REMOTE}/{kind}/summary.json") as f:
                model = json.loads(f.read())
        except OSError:
            with sftp.file(f"{REMOTE}/{kind}/run.log") as f:
                print(f.read().decode()[-1800:])
            continue
        (out / f"{kind}_summary.json").write_text(json.dumps(model, indent=2))
        ref = next(x for x in reference_latency if x["config"]==config and x["mode"]=="aggregate")
        gls = next(x for x in reference_gls if x["config"]==config and x["mode"]=="aggregate")
        row = dict(kind=kind, functional_valid=model["valid"], model_latency_ns=model["mean_flit_latency_ns"],
                   gls_latency_ns=ref["mean_flit_latency_ns"], model_gflit_s=model["throughput_gflit_s"],
                   gls_gflit_s=gls["throughput_gflit_s"], model_lane_counts=model["lane_counts"])
        row["latency_error_percent"] = 100*(row["model_latency_ns"]/row["gls_latency_ns"]-1)
        row["throughput_error_percent"] = 100*(row["model_gflit_s"]/row["gls_gflit_s"]-1)
        rows.append(row)
        print(json.dumps(row))
    sftp.close()
finally:
    client.close()
(out / "comparison.json").write_text(json.dumps(rows, indent=2))
