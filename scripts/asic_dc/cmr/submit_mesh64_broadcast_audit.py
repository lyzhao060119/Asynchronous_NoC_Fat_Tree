#!/usr/bin/env python3
"""Submit six serialized current-Mesh64 broadcast audit reruns."""

from __future__ import annotations

import json
import re
import shlex

from run_remote_cmr_noc16_sdf import connect


ROOT = "/prjtemp/ghy19/date2027_formal64/20261015_193500_formal64_multicast_inputs_r1"
HOME = "/home/ghy19/Asynchronous_Router_CMR"
RUN_ID = "20261021_mesh64_broadcast_m20_m40_audit_r1"
NETLIST_RUN = "20261017_190000_mesh64_xfirsty_dc_r3"
RUNNER = ROOT + "/run_e2_bc_hotspot64_remote.sh"


def execute(client, command: str) -> str:
    _stdin, stdout, stderr = client.exec_command(command, timeout=300)
    output = stdout.read().decode(errors="replace")
    error = stderr.read().decode(errors="replace")
    if error:
        output += "\nSTDERR:\n" + error
    return output


def main() -> None:
    client = connect()
    jobs: list[dict[str, object]] = []
    dependency = ""
    try:
        preflight = execute(
            client,
            f"test -x {shlex.quote(ROOT + '/work/FM64/simv')} && "
            f"test -s {shlex.quote(HOME + '/outputs/' + NETLIST_RUN + '/CMRMeshNoC_post.v')} && "
            f"test -s {shlex.quote(HOME + '/outputs/' + NETLIST_RUN + '/CMRMeshNoC.sdf')} && "
            "df -Pk /prjtemp | tail -1; bjobs -u ghy19 -noheader -o 'jobid stat job_name' 2>/dev/null | head -40 || true",
        )
        print("PREFLIGHT\n" + preflight, flush=True)
        for seed in (202701, 202702, 202703):
            for load in (20, 40):
                case_stem = f"ALL-BROADCAST_n64_s{seed}_m{load}_FM64_top0"
                result_name = f"ALL-BROADCAST_n64_s{seed}_m{load}_FM64_audit_r1"
                case_file = f"{ROOT}/cases/{case_stem}.case"
                log_file = f"{ROOT}/jobs/{RUN_ID}_{seed}_m{load}.log"
                name = f"fm64_bc_a{seed % 100}_m{load}"
                wait = f"-w {shlex.quote('done(' + dependency + ')')}" if dependency else ""
                body = (
                    f"env E2_REMOTE_ROOT={shlex.quote(ROOT)} E2_RUN_ID={shlex.quote(RUN_ID)} "
                    f"E2_NETLIST_RUN_ID={shlex.quote(NETLIST_RUN)} CMR_ARCHIVE_ROOT={shlex.quote(HOME)} "
                    "E2_ALLOW_MULTICAST=1 E2_COMPACT_OUTPUT=1 "
                    f"E2_CASE_NAME={shlex.quote(result_name)} E2_CASE_FILE={shlex.quote(case_file)} "
                    f"bash {shlex.quote(RUNNER)} run FM64"
                )
                command = f"bsub -q normal -J {shlex.quote(name)} -o {shlex.quote(log_file)} {wait} {shlex.quote(body)}"
                output = execute(client, command)
                match = re.search(r"Job <(\d+)>", output)
                if not match:
                    raise RuntimeError("submission failed: " + output)
                dependency = match.group(1)
                jobs.append({"seed": seed, "load": load, "job_id": dependency,
                             "case": case_stem, "result": result_name, "log": log_file})
                print("SUBMITTED", json.dumps(jobs[-1], sort_keys=True), flush=True)
        manifest = json.dumps({"run_id": RUN_ID, "netlist_run": NETLIST_RUN, "jobs": jobs}, indent=2)
        remote_manifest = f"{ROOT}/jobs/{RUN_ID}.json"
        encoded = shlex.quote(manifest)
        print(execute(client, f"printf '%s' {encoded} > {shlex.quote(remote_manifest)}; sha256sum {shlex.quote(remote_manifest)}"), flush=True)
    finally:
        client.close()


if __name__ == "__main__":
    main()
