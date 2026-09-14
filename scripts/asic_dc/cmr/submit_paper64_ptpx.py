#!/usr/bin/env python3
"""Submit PT-PX for an already-passed paper64 activity-capture run.

This is deliberately a resume-only stage: it consumes the immutable VCD and
TB result.csv from activity capture and never recompiles or re-runs GLS.
"""
from __future__ import annotations

import csv
import json
import os
import shlex
import sys
from pathlib import Path

CMR = Path(__file__).resolve().parent
REPO = CMR.parents[2]
sys.path.insert(0, str(CMR))
from _tmp_paper64_common import REMOTE_ROOT, connect_failover, remote_run_failover  # noqa: E402
from run_paper64_power import DESIGNS, quoted_env, source_cases  # noqa: E402
from run_remote_cmr_flow import atomic_put_bytes_retry  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import job_id  # noqa: E402

SOURCE_RUN_ID = os.environ.get("CMR_POWER_SOURCE_RUN_ID", "20260913_160000_paper64_mesh_pfat_power")
RUN_ID = os.environ.get("CMR_POWER_RUN_ID", SOURCE_RUN_ID)
SOURCE_RAW = REPO / "DATE paper/experiments/raw/paper64_power" / SOURCE_RUN_ID
RAW = REPO / "DATE paper/experiments/raw/paper64_power" / RUN_ID
PT_TCL = REPO / "scripts/asic_dc/power/run_ptpx_cmr_mesh_power.tcl"


def csv_window(sftp, remote: str) -> tuple[int, int, int]:
    with sftp.file(remote, "r") as fh:
        rows = list(csv.DictReader(fh.read().decode("utf-8").splitlines()))
    if len(rows) != 1 or rows[0].get("pass_fail") != "PASS":
        raise RuntimeError("invalid activity result " + remote)
    row = rows[0]
    start, end = int(row["measurement_start_ps"]), int(row["measurement_end_ps"])
    delivered = int(row["measurement_delivered_flits"])
    if end <= start or delivered <= 0:
        raise RuntimeError("invalid measurement window " + remote)
    return start, end, delivered


def main() -> int:
    if not PT_TCL.is_file():
        raise SystemExit("missing " + str(PT_TCL))
    source_manifest_path = SOURCE_RAW / "manifest.json"
    if not source_manifest_path.is_file():
        raise SystemExit("missing activity manifest " + str(source_manifest_path))
    manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    if len(manifest.get("submitted_activity_jobs", [])) != 24:
        raise SystemExit("activity manifest does not contain 24 submitted points")
    if RUN_ID == SOURCE_RUN_ID:
        raise SystemExit("refusing to overwrite source activity run; set a distinct CMR_POWER_RUN_ID")
    RAW.mkdir(parents=True, exist_ok=False)
    manifest = {"run_id": RUN_ID, "source_activity_run_id": SOURCE_RUN_ID,
                "source_activity_manifest": str(source_manifest_path), "points": []}
    client = connect_failover()
    sftp = client.open_sftp()
    submitted = []
    try:
        for design, load, case_name in source_cases():
            spec = DESIGNS[design]
            source_log = f"{REMOTE_ROOT}/logs/paper64_power/{SOURCE_RUN_ID}/{design}/m{load}"
            result = f"{REMOTE_ROOT}/results/paper64_power/{SOURCE_RUN_ID}/{design}/m{load}/result.csv"
            log = f"{REMOTE_ROOT}/logs/paper64_power/{RUN_ID}/{design}/m{load}"
            report = f"{REMOTE_ROOT}/reports/paper64_power/{RUN_ID}/{design}/m{load}"
            client, gate = remote_run_failover(
                client, "grep -q CMR_POWER_ACTIVITY_PASS " + shlex.quote(source_log + "/lsf.log") + " && echo ACTIVITY_OK"
            )
            if "ACTIVITY_OK" not in gate:
                raise RuntimeError("activity gate missing " + design + " M" + str(load))
            start, end, delivered = csv_window(sftp, result)
            client, _ = remote_run_failover(
                client, "mkdir -p " + shlex.quote(log) + " " + shlex.quote(report)
            )
            wrapper = log + "/ptpx.sh"
            env = {
                "CMR_POWER_DDC": f"{REMOTE_ROOT}/outputs/{spec['netlist']}/{spec['ddc']}",
                "CMR_POWER_SDC": f"{REMOTE_ROOT}/outputs/{spec['netlist']}/{spec['sdc']}",
                "CMR_POWER_NETLIST": f"{REMOTE_ROOT}/outputs/{spec['netlist']}/{spec['post']}",
                "CMR_POWER_SDF": f"{REMOTE_ROOT}/outputs/{spec['netlist']}/{spec['sdf']}",
                "CMR_POWER_VCD": source_log + "/measurement.vcd", "CMR_POWER_TOP": spec["top"],
                "CMR_POWER_STRIP_PATH": spec["strip"],
                "CMR_POWER_START_NS": f"{start / 1000.0:.3f}",
                "CMR_POWER_END_NS": f"{end / 1000.0:.3f}", "CMR_POWER_REPORT_DIR": report,
            }
            body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n" + quoted_env(env)
            body += f"\nexec /soft/synopsys/prime/V-2023.12/bin/pt_shell -f {REMOTE_ROOT}/scripts/run_ptpx_cmr_mesh_power.tcl\n"
            atomic_put_bytes_retry(client, sftp, body.encode(), wrapper)
            command = "chmod +x {w}; bsub -n 4 -oo {l}/ptpx.lsf.log -eo {l}/ptpx.lsf.err -J p64px_{d}_{m}_{r} {w}".format(
                w=shlex.quote(wrapper), l=shlex.quote(log), d=design.lower(), m=load, r=RUN_ID)
            client, answer = remote_run_failover(client, command)
            jid = job_id(answer)
            submitted.append({"design": design, "load_mflit_per_port_s": load, "case": case_name,
                              "ptpx_job": jid, "measurement_start_ps": start,
                              "measurement_end_ps": end, "measurement_delivered_flits": delivered})
            print("PTPX_JOB", design, load, jid, flush=True)
    finally:
        sftp.close()
        client.close()
    manifest["submitted_ptpx_jobs"] = submitted
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print("PAPER64_PTPX_SUBMITTED", RUN_ID)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
