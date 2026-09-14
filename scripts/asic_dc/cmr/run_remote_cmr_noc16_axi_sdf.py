#!/usr/bin/env python3
"""Frozen-netlist CMR NoC16 TAB/VCTM p50 on the Ultra AXI/BRAM harness."""
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import connect, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_thin_axi_p50",
)
NETLIST_RUN_ID = os.environ.get(
    "CMR_NOC16_NETLIST_RUN_ID", "20260820_cmr_rcu_delay_s4_noc16_sdf"
)
CASES = tuple(
    name for name in os.environ.get(
        "CMR_NOC16_CASES", "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
    ).split(",")
    if name.strip()
)
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def main():
    client = connect()
    remote_run(client, "mkdir -p %s/sim/tb %s/scripts %s/logs/gls/%s %s/results/%s/csv" % (
        ROOT, ROOT, ROOT, RUN_ID, ROOT, RUN_ID
    ))
    copy_cmd = (
        "cp %s/sim/tb/async_noc16_axi_bram_wrapper.sv %s/sim/tb/ && "
        "cp %s/sim/tb/tb_noc16_async_axi_bram.sv %s/sim/tb/"
        % (ULTRA, ROOT, ULTRA, ROOT)
    )
    output = remote_run(client, copy_cmd)
    if output.strip():
        print(output, flush=True)

    probe = remote_run(client,
        "test -s %s/outputs/%s/NoC_16nodes_post.v && "
        "test -s %s/outputs/%s/NoC_16nodes.sdf && echo OK" %
        (ROOT, NETLIST_RUN_ID, ROOT, NETLIST_RUN_ID))
    if "OK" not in probe:
        raise RuntimeError("missing frozen netlist " + NETLIST_RUN_ID)

    sftp = client.open_sftp()
    atomic_put(
        client, sftp,
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16_axi.sh",
        ROOT + "/scripts/run_gls_cmr_noc16_axi.sh",
    )
    sftp.close()
    remote_run(client, "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc16_axi.sh; "
                       "chmod +x %s/scripts/run_gls_cmr_noc16_axi.sh" % (ROOT, ROOT))

    remote_cases = {name: ULTRA + "/sim/cases/" + name + ".case" for name in CASES}
    case_hashes = {}
    jobs = {}
    for name, path in remote_cases.items():
        check = remote_run(client, "test -s %s && sha256sum %s" %
                           (shlex.quote(path), shlex.quote(path)))
        hashes = re.findall(r"\b[0-9a-f]{64}\b", check)
        if not hashes:
            raise RuntimeError("missing remote case: " + path)
        case_hashes[name] = hashes[0]
        print("REMOTE_CASE", name, hashes[0], flush=True)

        wrapper = ROOT + "/logs/gls/%s/axi_%s.sh" % (RUN_ID, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
            "CMR_NOC16_NETLIST_RUN_ID=%s CMR_NOC16_CASE_NAME=%s "
            "CMR_NOC16_CASE_FILE=%s CMR_NOC16_SKIP_GLS=0\n"
            "exec bash %s/scripts/run_gls_cmr_noc16_axi.sh\n" %
            (ROOT, RUN_ID, NETLIST_RUN_ID, name, path, ROOT)
        )
        sftp = client.open_sftp()
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        remote_run(client, "chmod +x " + wrapper)
        submit = remote_run(client,
            "bsub -n 8 -o %s/logs/gls/%s/axi_%s.bsub.log "
            "-e %s/logs/gls/%s/axi_%s.bsub.err -J cmr_axi_%s_%s %s" %
            (ROOT, RUN_ID, name, ROOT, RUN_ID, name, RUN_ID, name, wrapper))
        match = re.search(r"Job <(\d+)>", submit)
        if not match:
            raise RuntimeError("submit failed: " + submit)
        jobs[name] = match.group(1)
        print("AXI_JOB", name, match.group(1), flush=True)

    for name, jid in jobs.items():
        client = wait_job(client, jid, "axi_" + name, polls=480, allow_exit=True)

    all_pass = True
    status = {
        "run_id": RUN_ID,
        "harness": "axi_bram",
        "netlist_run_id": NETLIST_RUN_ID,
        "case_hashes": case_hashes,
        "cases": {},
    }
    for name, jid in jobs.items():
        base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, name)
        run_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
        annotate = remote_run(client, "cat %s/sdf_annotate.log 2>/dev/null" % base)
        csv_text = remote_run(client, "cat %s/result.csv 2>/dev/null" % base)
        errors = re.search(r"Total errors:\s*(\d+)", annotate)
        result_line = next(
            (line for line in run_log.splitlines() if "TB_RESULT " in line),
            None,
        )
        entry = {
            "job_id": jid,
            "tb_pass": "TB_RESULT PASS" in run_log,
            "annotation_done": "Doing SDF annotation ...... Done" in run_log,
            "annotation_errors": int(errors.group(1)) if errors else None,
            "ifnsdfa": "IFNSDFA" in run_log,
            "timing_violation_count": run_log.count("Timing violation"),
            "timeout_in_result": bool(result_line and "timeout=1" in result_line),
            "unexpected_in_result": bool(result_line and re.search(r"unexpected=[1-9]", result_line)),
            "result_line": result_line,
            "csv": csv_text.strip()[-500:] if csv_text.strip() else "",
        }
        passed = (
            entry["tb_pass"]
            and entry["annotation_done"]
            and entry["annotation_errors"] == 0
            and not entry["ifnsdfa"]
            and entry["timing_violation_count"] == 0
            and not entry["timeout_in_result"]
            and not entry["unexpected_in_result"]
        )
        all_pass &= passed
        status["cases"][name] = entry
        print("AXI_CASE", name, "PASS" if passed else "FAIL", result_line, flush=True)

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for name in jobs:
        for fname in ("run.log", "result.csv", "compile.log", "sdf_annotate.log"):
            remote = ROOT + "/logs/gls/%s/sdf/%s/%s" % (RUN_ID, name, fname)
            local = RESULT / ("%s_%s" % (name, fname))
            try:
                sftp.get(remote, str(local))
            except IOError:
                pass
    sftp.close()
    client.close()
    print("LOCAL_RESULT", RESULT, flush=True)
    if not all_pass:
        raise SystemExit(2)


if __name__ == "__main__":
    main()
