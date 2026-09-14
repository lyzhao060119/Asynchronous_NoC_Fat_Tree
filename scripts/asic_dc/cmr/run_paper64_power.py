#!/usr/bin/env python3
"""Run immutable MAXIMUM-SDF activity + PT-PX power for paper64 Mesh/PFAT.

This intentionally reuses existing post-DC artifacts and writes a fresh raw
run.  It never invokes DC and never mutates a latency-scan directory.
"""
from __future__ import annotations

import csv
import base64
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime
from pathlib import Path

CMR = Path(__file__).resolve().parent
REPO = CMR.parents[2]
sys.path.insert(0, str(CMR))
from _tmp_paper64_common import CASE_DIR, REMOTE_ROOT, connect_failover, remote_run_failover  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import atomic_put_retry, fetch_tree, job_id, wait_job  # noqa: E402
from run_remote_cmr_flow import atomic_put_bytes_retry  # noqa: E402

RUN_ID = os.environ.get("CMR_POWER_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_paper64_mesh_pfat_power")
SOURCE = Path(os.environ.get("CMR_POWER_SOURCE", str(CMR / "results/paper64/20260913_asap_uc_m5_200_mesh64_pfat64/manifest.json")))
RAW = REPO / "DATE paper/experiments/raw/paper64_power" / RUN_ID
SUBMIT_ONLY = os.environ.get("CMR_POWER_SUBMIT_ONLY", "0") == "1"
SSH_UPLOAD = os.environ.get("CMR_POWER_UPLOAD_MODE", "").lower() == "ssh"

DESIGNS = {
    "FM64": {
        "netlist": "20260913_104506_cmr_fm64_rpsdel150",
        "top": "CMRMeshNoC",
        "ddc": "CMRMeshNoC.ddc", "sdc": "CMRMeshNoC.sdc", "post": "CMRMeshNoC_post.v", "sdf": "CMRMeshNoC.sdf",
        "case_suffix": "FM64_top0",
        # PrimeTime PX consumes VCD hierarchy, not the dot-separated SDF
        # instance scope.  The generated VCD has g_behavioral_noc_mesh.noc
        # as one scope identifier, hence only hierarchy boundaries use '/'.
        "strip": "tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_mesh.noc/dut",
    },
    "PFAT64": {
        "netlist": "20260912_195012_cmr_pfat64_rpsdel050_1248",
        "top": "NoC_64nodes",
        "ddc": "NoC_64nodes.ddc", "sdc": "NoC_64nodes.sdc", "post": "NoC_64nodes_post.v", "sdf": "NoC_64nodes.sdf",
        "case_suffix": "PFAT64_top8",
        "strip": "tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc.noc/dut",
    },
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def quoted_env(values: dict[str, str]) -> str:
    return " ".join("export %s=%s;" % (key, shlex.quote(value)) for key, value in values.items())


def ssh_put(client, local: Path, remote: str) -> tuple[object, str]:
    """Small-chunk, hash-checked atomic upload when SFTP is unavailable."""
    data = local.read_bytes().replace(b"\r\n", b"\n")
    digest = hashlib.sha256(data).hexdigest()
    encoded = base64.b64encode(data).decode("ascii")
    temporary = remote + ".power_upload.b64"
    print("SSH_UPLOAD_BEGIN", remote, len(data), flush=True)
    client, out = remote_run_failover(client, "mkdir -p {d}; : > {t}".format(d=shlex.quote(str(Path(remote).parent).replace("\\", "/")), t=shlex.quote(temporary)))
    print("SSH_UPLOAD_CHANNEL_READY", remote, flush=True)
    # Keep individual exec-channel uploads small: some login proxies stall on
    # otherwise valid large commands.
    for offset in range(0, len(encoded), 12288):
        client, _ = remote_run_failover(client, "printf %s {c} >> {t}".format(c=shlex.quote(encoded[offset:offset + 12288]), t=shlex.quote(temporary)))
    command = "base64 -d {t} > {r}.tmp && test \"$(sha256sum {r}.tmp | awk '{{print $1}}')\" = {h} && mv {r}.tmp {r} && rm -f {t} && echo SSH_UPLOAD_OK".format(t=shlex.quote(temporary), r=shlex.quote(remote), h=shlex.quote(digest))
    client, out = remote_run_failover(client, command)
    if "SSH_UPLOAD_OK" not in out:
        raise RuntimeError("ssh upload failed %s: %s" % (remote, out[-2000:]))
    print("SSH_UPLOAD_OK", remote, flush=True)
    return client, digest


def put_file(client, sftp, local: Path, remote: str) -> tuple[object, object, str]:
    if SSH_UPLOAD:
        client, digest = ssh_put(client, local, remote)
        return client, sftp, digest
    # The legacy SFTP helper prepends CMR_REMOTE_ROOT itself.
    relative = remote.removeprefix(REMOTE_ROOT.rstrip("/") + "/")
    if relative == remote:
        raise RuntimeError("SFTP destination is outside CMR_REMOTE_ROOT: " + remote)
    client, _ = remote_run_failover(
        client, "mkdir -p " + shlex.quote(str(Path(remote).parent).replace("\\", "/"))
    )
    client, sftp, digest = atomic_put_retry(client, sftp, local, relative)
    return client, sftp, digest


def put_bytes(client, sftp, data: bytes, remote: str) -> tuple[object, object, str]:
    if SSH_UPLOAD:
        temp = RAW / (".upload_" + hashlib.sha256(data).hexdigest())
        temp.write_bytes(data)
        try:
            return put_file(client, sftp, temp, remote)
        finally:
            temp.unlink(missing_ok=True)
    return atomic_put_bytes_retry(client, sftp, data, remote)


def source_cases() -> list[tuple[str, int, str]]:
    data = json.loads(SOURCE.read_text(encoding="utf-8"))
    cases = []
    for run in data.get("runs", []):
        design = run.get("design")
        if design not in DESIGNS:
            continue
        if run.get("netlist_run_id") != DESIGNS[design]["netlist"]:
            raise SystemExit("source manifest netlist mismatch for " + design)
        for item in run.get("cases", []):
            cases.append((design, int(item["load_mflit_per_port_s"]), item["name"]))
    expected = {(design, load) for design in DESIGNS for load in (5, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200)}
    if {(d, l) for d, l, _ in cases} != expected:
        raise SystemExit("source manifest must contain exactly the 24 paper64 points")
    return sorted(cases)


def result_window(path: Path) -> tuple[int, int, int]:
    row = next(csv.DictReader(path.open(encoding="utf-8", newline="")))
    start, end = int(row["measurement_start_ps"]), int(row["measurement_end_ps"])
    delivered = int(row["measurement_delivered_flits"])
    if end <= start or delivered <= 0 or row.get("pass_fail") != "PASS":
        raise RuntimeError("invalid activity metrics " + str(path))
    return start, end, delivered


def main() -> int:
    if not SOURCE.is_file():
        raise SystemExit("missing source manifest " + str(SOURCE))
    points = source_cases()
    local_files = {
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": "sim/tb/tb_noc64_async_boundary.sv",
        CMR / "tb_cmr_noc64_async_boundary_failfast.sv": "sim/tb/tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/async_noc64_port_adapter.sv": "sim/tb/async_noc64_port_adapter.sv",
        REPO / "sim/AsyncNoC/async_noc64_mesh_port_adapter.sv": "sim/tb/async_noc64_mesh_port_adapter.sv",
        CMR / "run_gls_cmr_noc64_power_activity.sh": "scripts/run_gls_cmr_noc64_power_activity.sh",
        REPO / "scripts/asic_dc/power/run_ptpx_cmr_mesh_power.tcl": "scripts/run_ptpx_cmr_mesh_power.tcl",
    }
    missing = [str(p) for p in local_files if not p.is_file()]
    if missing:
        raise SystemExit("missing local inputs: " + ", ".join(missing))
    RAW.mkdir(parents=True, exist_ok=False)
    client = connect_failover()
    sftp = None if SSH_UPLOAD else client.open_sftp()
    manifest: dict = {"run_id": RUN_ID, "source_manifest": str(SOURCE), "points": [], "inputs": {}}
    try:
        client, _ = remote_run_failover(client, "mkdir -p {r}/sim/paper64_power_cases/{run} {r}/logs/paper64_power/{run} {r}/reports/paper64_power/{run} {r}/results/paper64_power/{run} {r}/sim/work/{run}".format(r=REMOTE_ROOT, run=RUN_ID))
        for local, rel in local_files.items():
            remote = "%s/%s" % (REMOTE_ROOT, rel)
            client, sftp, digest = put_file(client, sftp, local, remote)
            manifest["inputs"][rel] = digest
        client, _ = remote_run_failover(client, "chmod +x {r}/scripts/run_gls_cmr_noc64_power_activity.sh".format(r=REMOTE_ROOT))
        activity_jobs = []
        for design, load, name in points:
            case = CASE_DIR / (name + ".case")
            if not case.is_file():
                raise SystemExit("missing case " + str(case))
            if SSH_UPLOAD:
                case_dir = "sim/cases_mesh64" if design == "FM64" else "sim/cases_noc64"
                shared_case = "%s/%s/%s" % (REMOTE_ROOT, case_dir, case.name)
                case_hash = sha256(case)
                client, verified = remote_run_failover(client, "test \"$(sha256sum {f} 2>/dev/null | awk '{{print $1}}')\" = {h} && echo CASE_HASH_OK".format(f=shlex.quote(shared_case), h=shlex.quote(case_hash)))
                if "CASE_HASH_OK" not in verified:
                    # The shared case tree may legitimately contain an older
                    # traffic-model revision.  Do not mutate it; upload the
                    # immutable local case into this run's private directory.
                    remote_case = "%s/sim/paper64_power_cases/%s/%s" % (REMOTE_ROOT, RUN_ID, case.name)
                    client, sftp, verified_hash = put_file(client, sftp, case, remote_case)
                    if verified_hash != case_hash:
                        raise RuntimeError("uploaded case hash mismatch " + case.name)
                else:
                    remote_case = shared_case
            else:
                remote_case = "%s/sim/paper64_power_cases/%s/%s" % (REMOTE_ROOT, RUN_ID, case.name)
                client, sftp, case_hash = put_file(client, sftp, case, remote_case)
            spec = DESIGNS[design]
            wrapper = "%s/logs/paper64_power/%s/%s/m%d/activity.sh" % (REMOTE_ROOT, RUN_ID, design, load)
            body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n" + quoted_env({
                "CMR_REMOTE_ROOT": REMOTE_ROOT, "CMR_POWER_RUN_ID": RUN_ID,
                "CMR_POWER_NETLIST_RUN_ID": spec["netlist"], "CMR_POWER_DESIGN": design,
                "CMR_POWER_CASE_NAME": name, "CMR_POWER_CASE_FILE": remote_case,
                "CMR_POWER_LOAD_MFLIT": str(load),
            }) + "\nexec bash %s/scripts/run_gls_cmr_noc64_power_activity.sh\n" % REMOTE_ROOT
            client, sftp, _ = put_bytes(client, sftp, body.encode(), wrapper)
            command = "chmod +x {w}; bsub -n 8 -oo {log}/lsf.log -eo {log}/lsf.err -J p64act_{d}_{l}_{run} {w}".format(w=shlex.quote(wrapper), log=shlex.quote("%s/logs/paper64_power/%s/%s/m%d" % (REMOTE_ROOT, RUN_ID, design, load)), d=design.lower(), l=load, run=RUN_ID)
            client, response = remote_run_failover(client, command)
            jid = job_id(response)
            activity_jobs.append((design, load, name, jid, case_hash))
            print("ACTIVITY_JOB", design, load, jid, flush=True)
        if SUBMIT_ONLY:
            manifest["submitted_activity_jobs"] = [{"design": d, "load": l, "job_id": j} for d, l, _, j, _ in activity_jobs]
            (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
            print("PAPER64_POWER_SUBMITTED", RUN_ID, flush=True)
            return 0
        power_jobs = []
        for design, load, name, jid, case_hash in activity_jobs:
            client = wait_job(client, jid, "activity_%s_m%d" % (design, load), polls=1440)
            remote_log = "%s/logs/paper64_power/%s/%s/m%d" % (REMOTE_ROOT, RUN_ID, design, load)
            client, log = remote_run_failover(client, "cat {p}/run.log {p}/sdf_annotate.log {p}/lsf.err 2>/dev/null".format(p=shlex.quote(remote_log)))
            if "CMR_POWER_ACTIVITY_PASS" not in log:
                raise RuntimeError("activity failed %s M%d\n%s" % (design, load, log[-6000:]))
            local_point = RAW / design / ("m%d" % load)
            fetch_tree(sftp, remote_log, local_point / "activity")
            result = local_point / "activity" / "result.csv"
            start_ps, end_ps, delivered = result_window(result)
            spec = DESIGNS[design]
            remote_report = "%s/reports/paper64_power/%s/%s/m%d" % (REMOTE_ROOT, RUN_ID, design, load)
            wrapper = remote_log + "/ptpx.sh"
            env = {
                "CMR_POWER_DDC": "%s/outputs/%s/%s" % (REMOTE_ROOT, spec["netlist"], spec["ddc"]),
                "CMR_POWER_SDC": "%s/outputs/%s/%s" % (REMOTE_ROOT, spec["netlist"], spec["sdc"]),
                "CMR_POWER_NETLIST": "%s/outputs/%s/%s" % (REMOTE_ROOT, spec["netlist"], spec["post"]),
                "CMR_POWER_SDF": "%s/outputs/%s/%s" % (REMOTE_ROOT, spec["netlist"], spec["sdf"]),
                "CMR_POWER_VCD": remote_log + "/measurement.vcd", "CMR_POWER_TOP": spec["top"],
                "CMR_POWER_STRIP_PATH": spec["strip"], "CMR_POWER_START_NS": "%.3f" % (start_ps / 1000.0),
                "CMR_POWER_END_NS": "%.3f" % (end_ps / 1000.0), "CMR_POWER_REPORT_DIR": remote_report,
            }
            body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n" + quoted_env(env) + "\nexec /soft/synopsys/prime/V-2023.12/bin/pt_shell -f %s/scripts/run_ptpx_cmr_mesh_power.tcl\n" % REMOTE_ROOT
            client, sftp, _ = put_bytes(client, sftp, body.encode(), wrapper)
            client, response = remote_run_failover(client, "chmod +x {w}; bsub -n 4 -oo {p}/ptpx.lsf.log -eo {p}/ptpx.lsf.err -J p64px_{d}_{l}_{run} {w}".format(w=shlex.quote(wrapper), p=shlex.quote(remote_log), d=design.lower(), l=load, run=RUN_ID))
            power_jobs.append((design, load, name, job_id(response), case_hash, start_ps, end_ps, delivered))
        for design, load, name, jid, case_hash, start_ps, end_ps, delivered in power_jobs:
            client = wait_job(client, jid, "ptpx_%s_m%d" % (design, load), polls=1440)
            remote_log = "%s/logs/paper64_power/%s/%s/m%d" % (REMOTE_ROOT, RUN_ID, design, load)
            remote_report = "%s/reports/paper64_power/%s/%s/m%d" % (REMOTE_ROOT, RUN_ID, design, load)
            client, text = remote_run_failover(client, "cat {p}/ptpx.lsf.log {p}/ptpx.lsf.err 2>/dev/null".format(p=shlex.quote(remote_log)))
            if "CMR_POWER_PASS" not in text:
                raise RuntimeError("PT-PX failed %s M%d\n%s" % (design, load, text[-6000:]))
            local_point = RAW / design / ("m%d" % load)
            fetch_tree(sftp, remote_report, local_point / "power")
            subprocess.run([sys.executable, str(REPO / "scripts/asic_dc/power/summarize_cmr_mesh_power.py"), "--result-csv", str(local_point / "activity/result.csv"), "--power-report", str(local_point / "power/power.rpt"), "--out", str(local_point / "power/metrics.csv")], check=True)
            manifest["points"].append({"design": design, "load_mflit_per_port_s": load, "case": name, "case_sha256": case_hash, "activity_job": jid, "measurement_start_ps": start_ps, "measurement_end_ps": end_ps, "measurement_delivered_flits": delivered})
        (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print("PAPER64_POWER_PASS", RUN_ID, flush=True)
        return 0
    finally:
        try:
            if sftp is not None: sftp.close()
        finally: client.close()


if __name__ == "__main__":
    raise SystemExit(main())
