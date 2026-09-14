#!/usr/bin/env python3
"""Run the frozen 64-node DATE core power experiments without DC.

Stages are intentionally explicit: submit activity, validate/fetch it, submit
PT-PX, validate/fetch PT-PX, then aggregate.  A later stage refuses to run
unless the preceding stage has written its manifest evidence.
"""
from __future__ import annotations

import argparse
import base64
import csv
import hashlib
import json
import os
import re
import shlex
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

from _tmp_paper64_common import REMOTE_ROOT, connect_failover, remote_run_failover
from run_remote_cmr_flow import atomic_put_retry, atomic_put_bytes_retry, job_id

LOADS = (5, 100, 200, 260, 420)
FANOUTS = (2, 4, 8, 16, 32)
PROP_NETLIST = "20260913_prop_temp64_asap_uc_m5_200"
MESH_NETLIST = "20260913_104506_cmr_fm64_rpsdel150"
PROP_CASES = HERE / "generated_cases" / "20260913_prop_temp64_asap_m5_500_202701" / "cases"
MESH_CASES = HERE / "generated_cases" / "20260913_paper64_asap_m5_500_202701" / "cases"
MC_CASES = HERE / "generated_cases" / "20260914_prop_temp64_mc_emergency" / "cases"
RUN_ID = os.environ.get("CMR_CORE64_POWER_RUN_ID", datetime.now().strftime("%Y%m%d_%H%M%S") + "_core64_power")
RAW = REPO / "DATE paper" / "experiments" / "raw" / "core64_power" / RUN_ID
ROOT = os.environ.get("CMR_REMOTE_ROOT", REMOTE_ROOT)
DATA_ROOT = os.environ.get("CMR_CORE64_POWER_DATA_ROOT", "/prjtemp/ghy19/core64_power")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')
UPLOAD_MODE = os.environ.get("CMR_CORE64_POWER_UPLOAD_MODE", "ssh").lower()

SPECS = {
    "FM64": {
        "netlist": MESH_NETLIST, "ddc": "CMRMeshNoC.ddc", "sdc": "CMRMeshNoC.sdc",
        "post": "CMRMeshNoC_post.v", "sdf": "CMRMeshNoC.sdf", "top": "CMRMeshNoC",
        "strip": "tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_mesh.noc/dut",
        "dc_pass": "CMR_MESH64_DC_PASS",
    },
    "PROP_temp64": {
        "netlist": PROP_NETLIST, "ddc": "PROP_temp64.ddc", "sdc": "PROP_temp64.sdc",
        "post": "PROP_temp64_post.v", "sdf": "PROP_temp64.sdf", "top": "PROP_temp64",
        "strip": "tb_cmr_noc64_async_boundary_failfast/core/g_behavioral_noc_prop_temp.noc/dut",
        "dc_pass": "PROP_TEMP64_DC_PASS",
    },
}


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def save(manifest: dict) -> None:
    RAW.mkdir(parents=True, exist_ok=True)
    (RAW / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


def load() -> dict:
    path = RAW / "manifest.json"
    if not path.is_file():
        raise SystemExit("missing manifest: run preflight first: " + str(path))
    return json.loads(path.read_text(encoding="utf-8"))


def cases() -> list[dict]:
    rows = []
    for load in LOADS:
        for design, directory, suffix in (
            ("FM64", MESH_CASES, "FM64_top0"),
            ("PROP_temp64", PROP_CASES, "PROP_temp64_top16"),
        ):
            name = "TOPO-UR_n64_s202701_m%d_%s" % (load, suffix)
            rows.append({"suite": "ur", "design": design, "load": load, "case": name,
                         "path": directory / (name + ".case"), "vcd_mode": "measurement"})
    for fanout in FANOUTS:
        for scheme, suffix in (("native", "PROP_temp64_top16"), ("source_repeated_unicast", "source_repeated_unicast_top16")):
            name = "MC-REGION-F%d_n64_s202701_m5_%s" % (fanout, suffix)
            rows.append({"suite": "fanout", "design": "PROP_temp64", "load": 5, "fanout": fanout,
                         "scheme": scheme, "case": name, "path": MC_CASES / (name + ".case"),
                         "vcd_mode": "full_drain"})
    missing = [str(row["path"]) for row in rows if not row["path"].is_file()]
    if missing:
        raise SystemExit("missing selected cases: " + ", ".join(missing[:4]))
    return rows


def remote(client, command: str) -> tuple[object, str]:
    return remote_run_failover(client, command)


def ssh_put_bytes(client, data: bytes, destination: str) -> tuple[object, str]:
    """Upload through bounded SSH chunks; the login SFTP server truncates files."""
    normalized = data.replace(b"\r\n", b"\n")
    digest = hashlib.sha256(normalized).hexdigest()
    encoded = base64.b64encode(normalized).decode("ascii")
    temporary = destination + ".core64_upload.b64"
    client, _ = remote(client, "mkdir -p %s; : > %s" % (
        shlex.quote(str(Path(destination).parent).replace("\\", "/")), shlex.quote(temporary)))
    for offset in range(0, len(encoded), 12288):
        client, _ = remote(client, "printf %%s %s >> %s" % (
            shlex.quote(encoded[offset:offset + 12288]), shlex.quote(temporary)))
    command = ("base64 -d {tmp} > {dst}.tmp && test \"$(sha256sum {dst}.tmp | awk '{{print $1}}')\" = {sha} "
               "&& mv {dst}.tmp {dst} && rm -f {tmp} && echo CORE64_SSH_UPLOAD_OK").format(
                   tmp=shlex.quote(temporary), dst=shlex.quote(destination), sha=shlex.quote(digest))
    client, text = remote(client, command)
    if "CORE64_SSH_UPLOAD_OK" not in text:
        raise RuntimeError("SSH upload hash check failed for %s: %s" % (destination, text[-1000:]))
    return client, digest


def put_file(client, sftp, source: Path, destination: str) -> tuple[object, object, str]:
    if UPLOAD_MODE == "ssh":
        client, digest = ssh_put_bytes(client, source.read_bytes(), destination)
        return client, sftp, digest
    return atomic_put_retry(client, sftp, source, destination)


def put_bytes(client, sftp, data: bytes, destination: str) -> tuple[object, object, str]:
    if UPLOAD_MODE == "ssh":
        client, digest = ssh_put_bytes(client, data, destination)
        return client, sftp, digest
    return atomic_put_bytes_retry(client, sftp, data, destination)


def preflight() -> None:
    if RAW.exists():
        raise SystemExit("refusing to overwrite existing raw directory: " + str(RAW))
    selected = cases()
    client = connect_failover()
    try:
        artifacts = {}
        commands = []
        for design, spec in SPECS.items():
            out = "%s/outputs/%s" % (ROOT, spec["netlist"])
            dc = "%s/logs/dc/%s.log" % (ROOT, spec["netlist"])
            commands.append("echo __CORE64_%s__; for f in %s %s %s %s; do test -s \"$f\" || exit 9; done; sha256sum %s %s %s %s; grep -E '^%s output=' %s 2>/dev/null" % (
                design,
                *[shlex.quote(out + "/" + spec[key]) for key in ("ddc", "sdc", "post", "sdf")],
                *[shlex.quote(out + "/" + spec[key]) for key in ("ddc", "sdc", "post", "sdf")],
                spec["dc_pass"], shlex.quote(dc)))
        client, evidence = remote(client, "\n".join(commands))
        for design, spec in SPECS.items():
            if spec["dc_pass"] not in evidence:
                raise RuntimeError("missing frozen DC pass marker for %s:\n%s" % (design, evidence[-4000:]))
            artifacts[design] = {"netlist_run_id": spec["netlist"], "remote_evidence": evidence,
                                 "dc_pass_marker": spec["dc_pass"]}
        manifest = {
            "run_id": RUN_ID, "created_utc": datetime.now(timezone.utc).isoformat(),
            "git_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip(),
            "simulation_level": "post-synthesis MAXIMUM-SDF GLS + time-based PT-PX",
            "frozen_artifacts": artifacts, "loads": list(LOADS), "fanouts": list(FANOUTS),
            "points": [{k: (str(v) if k == "path" else v) for k, v in row.items()} for row in selected],
            "stages": {"preflight": "PASS"},
        }
        save(manifest)
        print("CORE64_POWER_PREFLIGHT_PASS", RUN_ID, flush=True)
    finally:
        client.close()


def input_files() -> dict[Path, str]:
    files = {
        HERE / "run_gls_cmr_noc64_power_activity.sh": "run_gls_cmr_noc64_power_activity.sh",
        REPO / "scripts/asic_dc/power/run_ptpx_cmr_mesh_power.tcl": "run_ptpx_cmr_mesh_power.tcl",
        REPO / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv": "tb_noc64_async_boundary.sv",
        HERE / "tb_cmr_noc64_async_boundary_failfast.sv": "tb_cmr_noc64_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/async_noc64_mesh_port_adapter.sv": "async_noc64_mesh_port_adapter.sv",
        REPO / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv": "async_prop_temp64_port_adapter.sv",
    }
    missing = [str(p) for p in files if not p.is_file()]
    if missing:
        raise SystemExit("missing power inputs: " + ", ".join(missing))
    return files


def submit_activity() -> None:
    manifest = load()
    if manifest["stages"].get("preflight") != "PASS":
        raise SystemExit("preflight did not pass")
    client = connect_failover(); sftp = client.open_sftp()
    try:
        base = "%s/%s" % (DATA_ROOT, RUN_ID)
        client, _ = remote(client, "mkdir -p %s/inputs %s/cases %s/logs/paper64_power/%s %s/results/paper64_power/%s %s/reports/paper64_power/%s" % (base, base, DATA_ROOT, RUN_ID, DATA_ROOT, RUN_ID, DATA_ROOT, RUN_ID))
        hashes = {}
        for local, name in input_files().items():
            client, sftp, digest = put_file(client, sftp, local, base + "/inputs/" + name)
            hashes[name] = digest
        jobs = []
        for point in manifest["points"]:
            local = Path(point["path"])
            remote_case = "%s/cases/%s.case" % (base, point["case"])
            client, sftp, case_hash = put_file(client, sftp, local, remote_case)
            tag = "%s_%s" % (point["suite"], point["case"])
            log = "%s/logs/paper64_power/%s/%s" % (DATA_ROOT, RUN_ID, tag)
            wrapper = log + "/activity.sh"
            env = {
                "CMR_REMOTE_ROOT": ROOT, "CMR_POWER_RUN_ID": RUN_ID,
                "CMR_POWER_NETLIST_RUN_ID": SPECS[point["design"]]["netlist"],
                "CMR_POWER_DESIGN": point["design"], "CMR_POWER_CASE_NAME": point["case"],
                "CMR_POWER_CASE_FILE": remote_case, "CMR_POWER_LOAD_MFLIT": str(point["load"]),
                "CMR_POWER_INPUT_ROOT": base + "/inputs", "CMR_POWER_VCD_MODE": point["vcd_mode"],
                "CMR_POWER_TAG": tag,
                "CMR_POWER_DATA_ROOT": DATA_ROOT,
            }
            exports = " ".join("export %s=%s;" % (k, shlex.quote(v)) for k, v in env.items())
            body = "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n%s\nexec bash %s/inputs/run_gls_cmr_noc64_power_activity.sh\n" % (exports, base)
            client, _ = remote(client, "mkdir -p %s" % shlex.quote(log))
            client, sftp, _ = put_bytes(client, sftp, body.encode(), wrapper)
            client, reply = remote(client, "chmod +x %s; bsub -n 8 %s -oo %s/lsf.log -eo %s/lsf.err -J %s %s" % (shlex.quote(wrapper), HOSTS, shlex.quote(log), shlex.quote(log), shlex.quote("core64act_" + RUN_ID + "_" + str(len(jobs))), shlex.quote(wrapper)))
            jobs.append({**point, "activity_job": job_id(reply), "case_sha256": case_hash, "remote_log": log})
            print("CORE64_ACTIVITY_SUBMITTED", tag, jobs[-1]["activity_job"], flush=True)
        manifest["input_sha256"] = hashes; manifest["activity_jobs"] = jobs; manifest["stages"]["activity"] = "SUBMITTED"; save(manifest)
    finally:
        sftp.close(); client.close()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("stage", choices=("preflight", "submit-activity"))
    args = ap.parse_args()
    {"preflight": preflight, "submit-activity": submit_activity}[args.stage]()


if __name__ == "__main__":
    main()
