#!/usr/bin/env python3
"""Read-only paired STA and click inventory on a frozen RouterL1 CMR DDC."""

import csv
import hashlib
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import connect, fetch_tree, job_id, wait_job


REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
BASELINE = os.environ.get(
    "CMR_ROUTER_STA_BASELINE", "20260925_cmr_routerl1_dff_sdf_r6"
)
RUN_ID = os.environ.get(
    "CMR_PAIRED_STA_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_routerl1_click_sta_r1",
)
RESULT = CMR / "results" / RUN_ID
TCL = CMR / "run_sta_cmr_router_click_catalog.tcl"


def normalized_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def raw_digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify_frozen_manifest() -> dict:
    summary_path = CMR / "results" / BASELINE / "summary.json"
    manifest = json.loads(summary_path.read_text(encoding="utf-8"))["manifest"]
    files = manifest["files"]
    mapping = {
        f"rtl/runs/{BASELINE}/CMRRouter.v": REPO / "generated_cmr" / "router_l1" / "CMRRouter.v",
        "rtl/OPMSelector.v": REPO / "src/main/resources/ASYNC/CMR/OPMSelector.v",
        "rtl/ReadControlUnit.v": REPO / "src/main/resources/ASYNC/CMR/ReadControlUnit.v",
        "rtl/ReadPhaseSelector.v": REPO / "src/main/resources/ASYNC/CMR/ReadPhaseSelector.v",
        "scripts/dc/run_dc_cmr_router.tcl": CMR / "run_dc_cmr_router.tcl",
        "rtl/async_cmr_router.sdc": CMR / "async_cmr_router.sdc",
    }
    mismatches = []
    for rel, path in mapping.items():
        expected = files.get(rel)
        if expected is None or not path.is_file():
            mismatches.append({"path": rel, "problem": "missing_manifest_or_source"})
            continue
        actual = normalized_digest(path)
        if actual != expected:
            mismatches.append(
                {"path": rel, "expected": expected, "actual": actual}
            )
    if mismatches:
        raise RuntimeError("frozen RTL/tool manifest mismatch: " + json.dumps(mismatches))
    return manifest


def main() -> None:
    if RESULT.exists():
        raise RuntimeError("refusing to overwrite STA result folder " + str(RESULT))
    if not TCL.is_file():
        raise RuntimeError("missing STA Tcl: " + str(TCL))
    manifest = verify_frozen_manifest()
    local_ddc = CMR / "results" / BASELINE / "outputs" / "CMRRouter.ddc"
    if not local_ddc.is_file() or local_ddc.stat().st_size == 0:
        raise RuntimeError("missing local frozen DDC " + str(local_ddc))

    client = connect()
    remote_ddc = f"{ROOT}/outputs/{BASELINE}/CMRRouter.ddc"
    remote_probe = remote_run(client, f"test -s {shlex.quote(remote_ddc)} && sha256sum {shlex.quote(remote_ddc)}")
    remote_digest_match = re.search(r"\b([0-9a-f]{64})\b", remote_probe)
    if remote_digest_match is None:
        raise RuntimeError("remote frozen DDC not found: " + remote_probe)
    # DDC is binary; do not normalize CRLF byte sequences in it.
    local_ddc_hash = raw_digest(local_ddc)
    if remote_digest_match.group(1) != local_ddc_hash:
        raise RuntimeError(
            "local/remote DDC digest mismatch local=%s remote=%s"
            % (local_ddc_hash, remote_digest_match.group(1))
        )

    fresh = remote_run(
        client,
        "test ! -e %s/reports/sta/%s && test ! -e %s/logs/sta/%s.log && echo FRESH"
        % (ROOT, shlex.quote(RUN_ID), ROOT, shlex.quote(RUN_ID)),
    )
    if "FRESH" not in fresh:
        raise RuntimeError("refusing to overwrite remote STA artifacts: " + fresh)

    remote_run(client, f"mkdir -p {ROOT}/scripts/sta {ROOT}/reports/sta/{RUN_ID} {ROOT}/logs/sta")
    sftp = client.open_sftp()
    atomic_put(client, sftp, TCL, ROOT + "/scripts/sta/" + TCL.name)
    wrapper = f"{ROOT}/logs/sta/{RUN_ID}.sh"
    log = f"{ROOT}/logs/sta/{RUN_ID}.log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_ROUTER_STA_BASELINE=%s CMR_PAIRED_STA_RUN_ID=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/sta/%s\n"
        % (
            shlex.quote(ROOT),
            shlex.quote(BASELINE),
            shlex.quote(RUN_ID),
            shlex.quote(ROOT),
            shlex.quote(ROOT),
            shlex.quote(TCL.name),
        )
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + shlex.quote(wrapper))
    submit = remote_run(
        client,
        "bsub -n 4 -o %s -e %s.err -J cmr_click_sta_%s %s"
        % (shlex.quote(log), shlex.quote(log), shlex.quote(RUN_ID), shlex.quote(wrapper)),
    )
    jid = job_id(submit)
    print("STA_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "router_click_catalog_sta")

    log_text = remote_run(
        client,
        "cat %s %s.err 2>/dev/null" % (shlex.quote(log), shlex.quote(log)),
    )
    RESULT.mkdir(parents=True)
    (RESULT / "sta.log").write_text(log_text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    fetch_tree(sftp, ROOT + "/reports/sta/" + RUN_ID, RESULT / "sta")
    sftp.close()

    coverage = RESULT / "sta" / "scope.txt"
    paired = RESULT / "sta" / "paired_click_catalog.csv"
    inventory = RESULT / "sta" / "click_inventory.csv"
    required = (coverage, paired, inventory)
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        raise RuntimeError("STA job omitted expected reports: " + ", ".join(missing))

    scope = {}
    for line in coverage.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            scope[key] = value
    with paired.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    no_path = sum(row["no_path"] == "1" for row in rows)
    shortfall_rows = sum(
        row["shortfall_ns"] not in ("NA", "")
        and float(row["shortfall_ns"]) > 0.0
        for row in rows
    )
    pending = int(scope.get("sequential_states_pending_classification", "-1"))
    unmeasured = int(scope.get("sequential_states_classified_but_unmeasured", "-1"))
    sta_done = "CMR_STA_CLICK_CATALOG_DONE" in log_text
    no_errors = not re.search(
        r"(?m)^(Error:|Error-|Fatal:)|CMR_STA_COVERAGE_FAIL|CMR_STA_PATH_ERROR",
        log_text,
    )
    timing_loop_count = len(re.findall(r"OPT-150", log_text))
    auto_arc_disable_count = len(re.findall(r"OPT-314", log_text))
    classification_pass = pending == 0
    coverage_pass = (
        classification_pass
        and unmeasured == 0
        and no_path == 0
        and auto_arc_disable_count == 0
        and sta_done
        and no_errors
    )
    timing_pass = shortfall_rows == 0
    stage2_eligible = coverage_pass and timing_pass
    result = {
        "run_id": RUN_ID,
        "baseline": BASELINE,
        "baseline_ddc_sha256": local_ddc_hash,
        "manifest_rtl_tool_matches": True,
        "source_manifest": manifest,
        "scope": scope,
        "paired_rows": len(rows),
        "no_path_rows": no_path,
        "rtm0_shortfall_rows": shortfall_rows,
        "sequential_states_pending_classification": pending,
        "sequential_states_classified_but_unmeasured": unmeasured,
        "sequential_inventory_classification_pass": classification_pass,
        "timing_loop_messages": timing_loop_count,
        "automatic_timing_arc_disables": auto_arc_disable_count,
        "coverage_pass": coverage_pass,
        "rtm0_timing_pass": timing_pass,
        "stage2_dc_constraint_optimization_eligible": stage2_eligible,
        "production_sdc_changed": False,
        "top_level_io_signed_off": False,
        "strict_sdf_rerun": False,
        "notes": [
            "This run is measurement-only on the frozen DDC.",
            "Do not promote any production constraint until complete RTC classification and RTM0 coverage pass.",
        ],
    }
    (RESULT / "click_sta_summary.json").write_text(
        json.dumps(result, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(result, indent=2), flush=True)
    if stage2_eligible:
        print("CMR_CLICK_STA_STAGE2_ELIGIBLE", RUN_ID, flush=True)
    else:
        print("CMR_CLICK_STA_STAGE2_BLOCKED", RUN_ID, flush=True)
    print("LOCAL_RESULT", RESULT, flush=True)
    client.close()


if __name__ == "__main__":
    main()
