#!/usr/bin/env python3
"""Generate and queue the six Async M16-64 repeated-unicast power cases."""
from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import re
import shlex
from pathlib import Path

from run_remote_cmr_flow import remote_run
from run_remote_cmr_noc16_sdf import connect


HERE = Path(__file__).resolve().parent
CAMPAIGN = "/prjtemp/ghy19/date2027_formal64/20261015_193500_formal64_multicast_inputs_r1"
ROOT = "/home/ghy19/Asynchronous_Router_CMR/formal64_native_repeated/20261019_m16_native_repeated_compact_r4"
NATIVE_POWER = "/home/ghy19/Asynchronous_Router_CMR/formal64_power_m16/20261018_m16_8bench_3seed_r2"
NETLIST = "/home/ghy19/Asynchronous_Router_CMR/outputs/20261011_prop_m16_current_timingopt_dc_lmh_r1"
NODES = "node21 node26 node24 node18 node20 node22"


def q(value: str) -> str:
    return shlex.quote(value)


def read_text(sftp, path: str) -> str:
    with sftp.file(path, "rb") as stream:
        return stream.read().decode("utf-8")


def upload(sftp, source: Path, target: str) -> str:
    data = source.read_bytes().replace(b"\r\n", b"\n")
    digest = hashlib.sha256(data).hexdigest()
    with sftp.file(target + ".part", "wb") as stream:
        stream.write(data)
    sftp.posix_rename(target + ".part", target)
    return digest


def submit(client, *, cores: int, name: str, log: str, command: str, dependency: str | None = None) -> str:
    dep = f"-w {q(dependency)} " if dependency else ""
    out = remote_run(
        client,
        f"bsub -n {cores} -m {q(NODES)} {dep}-o {q(log)} -e {q(log + '.err')} "
        f"-J {q(name)} {command}",
    )
    match = re.search(r"Job <(\d+)>", out)
    if not match:
        raise RuntimeError(out)
    return match.group(1)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("submit", "status"))
    args = parser.parse_args()
    client = connect()
    try:
        sftp = client.open_sftp()
        manifest_path = ROOT + "/manifest.json"
        if args.action == "status":
            manifest = json.loads(read_text(sftp, manifest_path))
            for item in manifest["jobs"]:
                markers = {}
                for kind, path, marker in (
                    ("activity", item["activity_log"], "FORMAL64_POWER_ACTIVITY_PASS"),
                    ("ptpx", item["ptpx_log"], "FORMAL64_PTPX_CASE_PASS"),
                    ("archive", item["archive_log"], "FORMAL64_POWER_VCD_ARCHIVE_PASS"),
                ):
                    try:
                        markers[kind] = marker in read_text(sftp, path)
                    except OSError:
                        markers[kind] = False
                print(item["tag"], json.dumps(markers, sort_keys=True))
            ids = " ".join(
                item[key] for item in manifest["jobs"]
                for key in ("activity_job_id", "ptpx_job_id", "archive_job_id")
            )
            print(remote_run(client, "bjobs -a -noheader -o 'jobid stat job_name' " + ids + " 2>/dev/null || true"), end="")
            return

        try:
            sftp.stat(manifest_path)
        except OSError:
            pass
        else:
            raise RuntimeError(f"refusing duplicate submission: {manifest_path}")

        remote_run(
            client,
            "mkdir -p " + " ".join(q(ROOT + suffix) for suffix in
                ("/scripts", "/python/date_v3", "/src", "/work", "/inputs", "/activity", "/reports", "/logs", "/vcd")),
        )
        remote_generator = ROOT + "/scripts/generate_formal64_native_repeated.py"
        activity_runner = ROOT + "/scripts/run_formal64_power_activity_remote.sh"
        ptpx_runner = ROOT + "/scripts/run_formal64_ptpx_case.py"
        archive_runner = ROOT + "/scripts/archive_formal64_power_vcd.py"
        tcl = ROOT + "/scripts/run_ptpx_cmr_mesh_power.tcl"
        hashes = {
            "generator": upload(sftp, HERE / "generate_formal64_native_repeated.py", remote_generator),
            "activity_runner": upload(sftp, HERE / "run_formal64_power_activity_remote.sh", activity_runner),
            "ptpx_runner": upload(sftp, HERE / "run_formal64_mesh_ptpx_case.py", ptpx_runner),
            "archive_runner": upload(sftp, HERE / "archive_formal64_power_vcd.py", archive_runner),
            "ptpx_tcl": upload(sftp, HERE.parent / "power/run_ptpx_cmr_mesh_power.tcl", tcl),
            "compile_runner": upload(sftp, HERE / "run_e2_bc_hotspot64_remote.sh", ROOT + "/run_e2_bc_hotspot64_remote.sh"),
            "adapter": upload(sftp, HERE.parents[2] / "sim/AsyncNoC/async_prop_temp64_port_adapter.sv", ROOT + "/src/async_prop_temp64_port_adapter.sv"),
            "tb": upload(sftp, HERE.parents[2] / "sim/AsyncNoC/testbench/tb_noc64_async_boundary.sv", ROOT + "/src/tb_noc64_async_boundary.sv"),
            "failfast": upload(sftp, HERE / "tb_cmr_noc64_async_boundary_failfast.sv", ROOT + "/src/tb_cmr_noc64_async_boundary_failfast.sv"),
        }
        package_source = HERE.parents[2] / "DATE_paper/experiments/scripts/date_v3"
        for source in sorted(package_source.glob("*.py")):
            hashes["date_v3/" + source.name] = upload(sftp, source, ROOT + "/python/date_v3/" + source.name)
        remote_run(client, f"chmod +x {q(remote_generator)} {q(activity_runner)} {q(ptpx_runner)} {q(archive_runner)}")
        generate = remote_run(
            client,
            f"/soft/GNU/python3.12/bin/python3 {q(remote_generator)} --campaign-root {q(CAMPAIGN)} "
            f"--output-root {q(ROOT + '/inputs')} --package-root {q(ROOT + '/python')}",
        )
        if "FORMAL64_NATIVE_REPEATED_GENERATION_PASS" not in generate:
            raise RuntimeError(generate)
        rows = list(csv.DictReader(io.StringIO(read_text(sftp, ROOT + "/inputs/case_manifest.csv"))))
        if len(rows) != 12 or any(row["destination_audit"] != "PASS" for row in rows):
            raise RuntimeError("twelve-case destination audit did not pass")

        compile_env = (
            f"env E2_REMOTE_ROOT={q(ROOT)} E2_RUN_ID=native_repeated_r2 "
            "E2_NETLIST_RUN_ID=20261011_prop_m16_current_timingopt_dc_lmh_r1 "
            "CMR_ARCHIVE_ROOT=/home/ghy19/Asynchronous_Router_CMR"
        )
        compile_job = submit(
            client, cores=8, name="nr_compile_m16", log=ROOT + "/logs/compile.log",
            command=f"{compile_env} bash {q(ROOT + '/run_e2_bc_hotspot64_remote.sh')} compile PROP_M16",
        )

        jobs = []
        for row in rows:
            benchmark = row["benchmark"]
            seed = int(row["seed"])
            load = int(row["load_mflit_port_s"])
            mode = row["mode"]
            tag = f"PROP_M16_{benchmark}_s{seed}_m{load}_{mode}"
            activity = ROOT + "/activity/" + tag
            report = ROOT + "/reports/" + tag
            log_dir = ROOT + "/logs/" + tag
            remote_run(client, f"mkdir -p {q(activity)} {q(report)} {q(log_dir)}")
            case_file = row["case"]
            case_name = f"{benchmark}_n64_s{seed}_m{load}_PROP_M16_{mode}"
            env = {
                "FORMAL64_POWER_DESIGN": "PROP_M16",
                "FORMAL64_POWER_CASE_FILE": case_file,
                "FORMAL64_POWER_CASE_NAME": case_name,
                "FORMAL64_POWER_TAG": tag,
                "FORMAL64_POWER_ROOT": ROOT,
                "FORMAL64_ASYNC_ROOT": ROOT,
                "FORMAL64_SYNC_SIMV": ROOT + "/work/PROP_M16/simv",
                "FORMAL64_POWER_VCD_STORAGE_DIR": ROOT + "/vcd",
            }
            command = "env " + " ".join(f"{key}={q(value)}" for key, value in env.items()) + " bash " + q(activity_runner)
            activity_job = submit(client, cores=1, name="nr_act_" + str(seed) + benchmark[:3],
                                  log=activity + "/lsf.log", command=command,
                                  dependency=f"done({compile_job})")
            ptpx_log = log_dir + "/ptpx.log"
            ptpx_cmd = (
                f"/soft/GNU/python3.12/bin/python3 {q(ptpx_runner)} --activity {q(activity)} "
                f"--report {q(report)} --tcl {q(tcl)} --netlist-root {q(NETLIST)} "
                "--ddc-name PROP_temp64_m16.ddc --netlist-name PROP_temp64_m16_post.v "
                "--sdf-name PROP_temp64_m16.sdf --top PROP_temp64_m16 "
                "--strip-path tb_cmr_noc64_async_boundary_failfast/core/"
                "g_behavioral_noc_prop_temp_m16.noc/dut"
            )
            ptpx_job = submit(client, cores=4, name="nr_px_" + str(seed) + benchmark[:3],
                              log=ptpx_log, command=ptpx_cmd, dependency=f"done({activity_job})")
            archive_log = log_dir + "/archive.log"
            archive_cmd = (
                f"/soft/GNU/python3.12/bin/python3 {q(archive_runner)} "
                f"--activity {q(activity)} --ptpx-log {q(ptpx_log)}"
            )
            archive_job = submit(client, cores=1, name="nr_gz_" + str(seed) + benchmark[:3],
                                 log=archive_log, command=archive_cmd, dependency=f"done({ptpx_job})")
            jobs.append({
                **row, "tag": tag, "case_name": case_name,
                "activity_dir": activity, "report_dir": report,
                "activity_log": activity + "/lsf.log", "ptpx_log": ptpx_log,
                "archive_log": archive_log,
                "activity_job_id": activity_job, "ptpx_job_id": ptpx_job,
                "archive_job_id": archive_job,
            })
            print("NATIVE_REPEATED_QUEUED", tag, activity_job, ptpx_job, archive_job, flush=True)

        manifest = {
            "schema": "formal64-native-repeated-run-v1",
            "root": ROOT, "campaign": CAMPAIGN, "netlist": NETLIST,
            "native_power_root": NATIVE_POWER, "scripts_sha256": hashes,
            "compile_job_id": compile_job, "jobs": jobs,
        }
        with sftp.file(manifest_path + ".part", "wb") as stream:
            stream.write((json.dumps(manifest, indent=2) + "\n").encode())
        sftp.posix_rename(manifest_path + ".part", manifest_path)
        print("FORMAL64_NATIVE_REPEATED_QUEUED cases=12 chains=36 root=" + ROOT)
    finally:
        client.close()


if __name__ == "__main__":
    main()
