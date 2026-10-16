#!/usr/bin/env python3
"""Measure one SDF-confirmed OPM output pair with an explicit read-only loop cut."""

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
BASELINE = "20260925_cmr_routerl1_dff_sdf_r6"
RUN_ID = os.environ.get(
    "CMR_ROUTER_OPM_LOOPCUT_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_routerl1_opm_loopcut_r1",
)
TCL = CMR / "run_sta_cmr_opm_sdf_guided_loopcut.tcl"
RESULT = CMR / "results" / RUN_ID
BASELINE_DDC_SHA256 = "fb0d5c2ec62674c8553a37881913ce98321bdd30065faabe83b40f32d666fd60"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def parse_scope(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            values[key] = value
    return values


def main() -> None:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+", RUN_ID):
        raise RuntimeError("unsafe run id: " + RUN_ID)
    if RESULT.exists():
        raise RuntimeError("refusing to overwrite local STA result " + str(RESULT))
    if not TCL.is_file():
        raise RuntimeError("missing analysis Tcl " + str(TCL))

    # The manifest guard rejects source drift from r6; this pilot reads the
    # frozen DDC only and never elaborates current mutable RTL.
    from run_remote_cmr_router_sta_click_catalog import verify_frozen_manifest

    manifest = verify_frozen_manifest()
    local_ddc = CMR / "results" / BASELINE / "outputs" / "CMRRouter.ddc"
    if not local_ddc.is_file() or sha256(local_ddc) != BASELINE_DDC_SHA256:
        raise RuntimeError("local frozen DDC hash mismatch")

    client = connect()
    remote_ddc = f"{ROOT}/outputs/{BASELINE}/CMRRouter.ddc"
    remote_probe = remote_run(client, "sha256sum " + shlex.quote(remote_ddc))
    found = re.search(r"\b([0-9a-f]{64})\b", remote_probe)
    if not found or found.group(1) != BASELINE_DDC_SHA256:
        client.close()
        raise RuntimeError("remote frozen DDC hash mismatch: " + remote_probe)

    remote_tcl = f"{ROOT}/scripts/sta/run_sta_cmr_opm_sdf_guided_loopcut_{RUN_ID}.tcl"
    wrapper = f"{ROOT}/logs/sta/{RUN_ID}.sh"
    log = f"{ROOT}/logs/sta/{RUN_ID}.log"
    fresh = remote_run(
        client,
        "test ! -e %s && test ! -e %s && test ! -e %s/reports/sta/%s && echo FRESH"
        % (shlex.quote(wrapper), shlex.quote(log), shlex.quote(ROOT), shlex.quote(RUN_ID)),
    )
    if "FRESH" not in fresh:
        client.close()
        raise RuntimeError("refusing to overwrite remote STA artifacts: " + fresh)

    remote_run(client, "mkdir -p %s/scripts/sta %s/logs/sta %s/reports/sta/%s"
               % (shlex.quote(ROOT), shlex.quote(ROOT), shlex.quote(ROOT), shlex.quote(RUN_ID)))
    sftp = client.open_sftp()
    atomic_put(client, sftp, TCL, remote_tcl)
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_ROUTER_STA_BASELINE=%s CMR_PAIRED_STA_RUN_ID=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s\n"
        % (shlex.quote(ROOT), shlex.quote(BASELINE), shlex.quote(RUN_ID),
           shlex.quote(ROOT), shlex.quote(remote_tcl))
    )
    atomic_put_bytes(client, sftp, body.encode(), wrapper)
    sftp.close()
    remote_run(client, "chmod +x " + shlex.quote(wrapper))
    submit = remote_run(
        client,
        "bsub -n 4 -o %s -e %s.err -J cmr_opm_loopcut_%s %s"
        % (shlex.quote(log), shlex.quote(log), shlex.quote(RUN_ID), shlex.quote(wrapper)),
    )
    jid = job_id(submit)
    print("OPM_LOOPCUT_STA_JOB", jid, "baseline", BASELINE, "run", RUN_ID, flush=True)
    wait_job(client, jid, "routerl1_opm_sdf_guided_loopcut")

    RESULT.mkdir(parents=True)
    sftp = client.open_sftp()
    fetch_tree(sftp, ROOT + "/reports/sta/" + RUN_ID, RESULT / "sta")
    sftp.get(log, str(RESULT / "sta.log"))
    try:
        sftp.get(log + ".err", str(RESULT / "sta.err"))
    except OSError:
        pass
    sftp.close()
    client.close()

    scope_file = RESULT / "sta" / "opm0_sdf_guided_summary.txt"
    paired_file = RESULT / "sta" / "opm0_sdf_guided_c2q.csv"
    required = (scope_file, paired_file, RESULT / "sta.log")
    missing = [str(p) for p in required if not p.is_file()]
    if missing:
        raise RuntimeError("STA run omitted expected report(s): " + ", ".join(missing))
    scope = parse_scope(scope_file)
    log_text = (RESULT / "sta.log").read_text(encoding="utf-8", errors="replace")
    disabled = re.findall(
        r"Warning: Disabling timing arc between pins '([^']+)' and '([^']+)' on cell '([^']+)'",
        log_text,
    )
    measured_names = ("OutputPortModules_0/DataReg_ff_reg[27]", "OutputPortModules_0/io_Reqout_ff_reg")
    measured_arc_disables = [entry for entry in disabled if any(name in entry[2] for name in measured_names)]
    cut_marker = "CMR_STA_LOOP_CUT id=CMR-OPM0-SDF-ACK-RETURN-01" in log_text
    # dc_shell echoes sourced Tcl, including strings such as "CMR_STA_FAIL".
    # Only treat emitted diagnostic lines/our explicit failure marker as errors.
    no_errors = not re.search(
        r"(?m)^(?:Error:|Error-[0-9]+|Fatal:|CMR_STA_FAIL(?:\\s|$))",
        log_text,
    )
    no_path = any(value == "NO_PATH" for key, value in scope.items() if key.endswith("_ns"))
    measured_paths_pass = not no_path and scope.get("data_rise_max_ns", "NO_PATH") != "NO_PATH" and scope.get("req_rise_min_ns", "NO_PATH") != "NO_PATH"
    arc_cut_pass = not measured_arc_disables
    method_pass = cut_marker and no_errors and measured_paths_pass and arc_cut_pass
    try:
        sdf_delta_ps = 1000.0 * (
            float(scope["data_rise_max_ns"]) - float(scope["req_rise_min_ns"])
        )
    except (KeyError, ValueError):
        sdf_delta_ps = None
    sdf_sta_order_agrees = sdf_delta_ps is not None and abs(sdf_delta_ps - 27.0) <= 10.0
    rtm = float(scope["rise_rtm_pct"]) if scope.get("rise_rtm_pct") not in (None, "NA") else None
    timing_closed_at_zero_rtm = rtm is not None and rtm >= 0.0

    with paired_file.open(newline="", encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    ledger = RESULT / "sta" / "loop_cut_ledger.csv"
    with ledger.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=("id", "cell", "from_pin", "to_pin", "feedback_to", "reason", "measured_arcs_preserved", "scope"))
        writer.writeheader()
        writer.writerow({
            "id": "CMR-OPM0-SDF-ACK-RETURN-01",
            "cell": "OutputPortModules_0/FF0_FF3_2_reg",
            "from_pin": "CP",
            "to_pin": "Q",
            "feedback_to": "InputPortModules_3.io_Ackin_0",
            "reason": "SDF probe shows Ackout_2 after the paired Reqout/Dataout events; cut opens the returned acknowledgement loop for the direct CP-to-Q measurement",
            "measured_arcs_preserved": "OutputPortModules_0/DataReg_ff_reg[27].CP->Q;OutputPortModules_0/io_Reqout_ff_reg.CP->Q",
            "scope": "analysis-only frozen r6 DDC",
        })

    summary = {
        "run_id": RUN_ID,
        "baseline": BASELINE,
        "baseline_ddc_sha256": BASELINE_DDC_SHA256,
        "manifest_rtl_tool_matches": True,
        "source_manifest": manifest,
        "analysis_only": True,
        "production_sdc_changed": False,
        "rtl_changed": False,
        "scope": scope,
        "paired_rows": rows,
        "explicit_loop_cut_applied": cut_marker,
        "automatic_arc_disables_total": len(disabled),
        "automatic_measured_arc_disables": measured_arc_disables,
        "no_path": no_path,
        "measured_paths_pass": measured_paths_pass,
        "measured_arcs_preserved": arc_cut_pass,
        "no_errors": no_errors,
        "sta_sdf_event_order_delta_ps": sdf_delta_ps,
        "sta_sdf_event_order_agrees_with_probe": sdf_sta_order_agrees,
        "timing_closed_at_zero_rtm": timing_closed_at_zero_rtm,
        "method_pass": method_pass,
        "pilot_pass": method_pass and sdf_sta_order_agrees,
        "stage2_dc_constraint_optimization_eligible": False,
    }
    (RESULT / "opm0_sdf_guided_sta_summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2), flush=True)
    print("LOCAL_RESULT", RESULT, flush=True)
    if not method_pass or not sdf_sta_order_agrees:
        raise RuntimeError("SDF-guided OPM STA pilot failed its path/loop-cut audit")


if __name__ == "__main__":
    main()
