#!/usr/bin/env python3
"""Frozen-netlist CMR NoC16 TAB/VCTM p50 on the asynchronous fail-fast harness."""
import json
import os
import re
import shlex
from datetime import datetime
from pathlib import Path

from cmr_frozen_run_ids import refuse_overwrite
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_fat_tree_noc16_sdf import connect, wait_job


REPO = Path(__file__).resolve().parents[3]
ROOT = os.environ.get("CMR_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_CMR")
ULTRA = os.environ.get("ULTRA_REMOTE_ROOT", "/home/ghy19/Asynchronous_Router_ultra")
RUN_ID = os.environ.get(
    "CMR_NOC16_RUN_ID",
    datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_thin_async_p50",
)
NETLIST_RUN_ID = os.environ.get(
    "CMR_NOC16_NETLIST_RUN_ID", "20260828_cmr_cfifo_tp_nogrant_p50"
)
RX_CAPTURE_NS = os.environ.get("CMR_NOC16_RX_CAPTURE_NS", "0.09")
STALL_TIMEOUT_NS = os.environ.get("CMR_NOC16_STALL_TIMEOUT_NS", "50000")
HARD_TIMEOUT_NS = os.environ.get("CMR_NOC16_HARD_TIMEOUT_NS", "400000")
SIM_ARGS = os.environ.get("CMR_NOC16_SIM_ARGS", "")
INJECT_MAX_RATE = os.environ.get("CMR_NOC16_INJECT_MAX_RATE", "0") == "1"
STRUCTURAL_ENDPOINTS = os.environ.get("CMR_NOC16_STRUCTURAL_ENDPOINTS", "0") == "1"
THIN_STALL_PROBE = os.environ.get("CMR_NOC16_THIN_STALL_PROBE", "0") == "1"
FUNCTIONAL_STALL_PROBE = os.environ.get("CMR_NOC16_FUNCTIONAL_STALL_PROBE", "0") == "1"
IPM1_ACK_PROBE = os.environ.get("CMR_NOC16_IPM1_ACK_PROBE", "0") == "1"
IPM3_ACK_PROBE = os.environ.get("CMR_NOC16_IPM3_ACK_PROBE", "0") == "1"
PHASE_SELECTOR_PROBE = os.environ.get("CMR_NOC16_PHASE_SELECTOR_PROBE", "0") == "1"
NOFIFO_STALL_PROBE = os.environ.get("CMR_NOC16_NOFIFO_STALL_PROBE", "0") == "1"
P30_PORT5_PROBE = os.environ.get("CMR_NOC16_P30_PORT5_PROBE", "0") == "1"
VCTM_TAIL_PROBE = os.environ.get("CMR_NOC16_VCTM_TAIL_PROBE", "0") == "1"
VCTM_TAIL_TRACE = os.environ.get("CMR_NOC16_VCTM_TAIL_TRACE", "0") == "1"
VCTM_WP07_PROBE = os.environ.get("CMR_NOC16_VCTM_WP07_PROBE", "0") == "1"
ROUTESELAND_X_PROBE = os.environ.get("CMR_NOC16_ROUTESELAND_X_PROBE", "0") == "1"
ROUTESELAND_X_FULL = os.environ.get("CMR_NOC16_ROUTESELAND_X_FULL", "0") == "1"
L2AX_PROBE = os.environ.get("CMR_NOC16_L2AX_PROBE", "0") == "1"
CFIFO05_PROBE = os.environ.get("CMR_NOC16_CFIFO05_PROBE", "0") == "1"
CFIFO06_PROBE = os.environ.get("CMR_NOC16_CFIFO06_PROBE", "0") == "1"
CASES = tuple(
    name for name in os.environ.get(
        "CMR_NOC16_CASES", "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
    ).split(",")
    if name.strip()
)
CASE_FILE_OVERRIDE = os.environ.get("CMR_NOC16_CASE_FILE", "").strip()
CASE_NAME_OVERRIDE = os.environ.get("CMR_NOC16_CASE_NAME", "").strip()
RESULT = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID


def harvest_sr_lines(run_log):
    sr_lines = [line for line in run_log.splitlines() if "THIN_SR_" in line]
    overlap = [line for line in sr_lines if "THIN_SR_OVERLAP " in line]
    miss = [line for line in sr_lines if "THIN_SR_MISS " in line]
    clr = [line for line in sr_lines if "THIN_SR_CLR " in line]
    last_idx = None
    for idx, line in enumerate(sr_lines):
        if re.search(r"dest=0*3003\b", line):
            last_idx = idx
    if last_idx is None:
        for idx, line in enumerate(sr_lines):
            if " br=3 " in line and "THIN_SR_EDGE " in line and " S=1 " in line:
                last_idx = idx
    window = []
    if last_idx is not None:
        lo = max(0, last_idx - 12)
        hi = min(len(sr_lines), last_idx + 13)
        window = sr_lines[lo:hi]
    return {
        "edge_count": sum(1 for line in sr_lines if "THIN_SR_EDGE " in line),
        "overlap_count": len(overlap),
        "miss_count": len(miss),
        "clr_count": len(clr),
        "overlap": overlap[-80:],
        "miss": miss[-40:],
        "clr": clr[-20:],
        "last_packet_window": window,
    }


def main():
    refuse_overwrite(RUN_ID, action="thin-async-gls")
    client = connect()
    remote_run(client, "mkdir -p %s/sim/tb %s/scripts %s/logs/gls/%s %s/results/%s/csv" % (
        ROOT, ROOT, ROOT, RUN_ID, ROOT, RUN_ID
    ))
    remote_run(client,
        "cp %s/sim/tb/async_noc16_port_adapter.sv %s/sim/tb/; "
        "cp %s/sim/tb/tb_noc16_async_boundary.sv "
        "%s/sim/tb/tb_noc16_async_boundary.ultra_reference.sv" %
        (ULTRA, ROOT, ULTRA, ROOT)
    )
    probe = remote_run(client,
        "test -s %s/outputs/%s/NoC_16nodes_post.v && "
        "test -s %s/outputs/%s/NoC_16nodes.sdf && echo OK" %
        (ROOT, NETLIST_RUN_ID, ROOT, NETLIST_RUN_ID))
    if "OK" not in probe:
        raise RuntimeError("missing frozen netlist " + NETLIST_RUN_ID)

    local_files = {
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh":
            ROOT + "/scripts/run_gls_cmr_noc16.sh",
        REPO / "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv":
            ROOT + "/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv",
        REPO / "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv":
            ROOT + "/sim/tb/tb_noc16_async_boundary.sv",
    }
    if STRUCTURAL_ENDPOINTS:
        local_files.update({
            REPO / "sim/AsyncNoC/async_endpoint_source_turnaround_delay.sv":
                ROOT + "/sim/tb/async_endpoint_source_turnaround_delay.sv",
            REPO / "src/main/resources/ASYNC/AsyncEndpointAckDelay.v":
                ROOT + "/sim/tb/async_endpoint_ack_delay.sv",
            REPO / "sim/AsyncNoC/async_endpoint_bank20.sv":
                ROOT + "/sim/tb/async_endpoint_bank20.sv",
            REPO / "sim/AsyncNoC/async_noc16_boundary_dut.sv":
                ROOT + "/sim/tb/async_noc16_boundary_dut.sv",
            REPO / "src/main/resources/ASYNC/MousetrapStage.v":
                ROOT + "/sim/tb/MousetrapStage.v",
            REPO / "src/main/resources/ASYNC/DLatchBank.v":
                ROOT + "/sim/tb/DLatchBank.v",
        })
    if THIN_STALL_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_core8_stall_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_thin_core8_stall_probe.sv"
    if FUNCTIONAL_STALL_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_functional_stall_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_functional_stall_probe.sv"
    if IPM1_ACK_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_ipm1_ack_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv"
    if IPM3_ACK_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_ipm3_ack_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_thin_ipm3_ack_probe.sv"
    if PHASE_SELECTOR_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_phase_selector_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_thin_phase_selector_probe.sv"
    if NOFIFO_STALL_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_thin_nofifo_stall_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_thin_nofifo_stall_probe.sv"
    if P30_PORT5_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_p30_port5_x_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_p30_port5_x_probe.sv"
    if VCTM_TAIL_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_vctm_tail_stall_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_vctm_tail_stall_probe.sv"
    if VCTM_TAIL_TRACE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_vctm_tail_release_trace.sv"] = \
            ROOT + "/sim/tb/tb_cmr_vctm_tail_release_trace.sv"
    if VCTM_WP07_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_vctm_wp07_mat_routesel.sv"] = \
            ROOT + "/sim/tb/tb_cmr_vctm_wp07_mat_routesel.sv"
    if ROUTESELAND_X_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_routeseland_first_x.sv"] = \
            ROOT + "/sim/tb/tb_cmr_routeseland_first_x.sv"
    if L2AX_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_l2_opm1_reqin3_first_x.sv"] = \
            ROOT + "/sim/tb/tb_cmr_l2_opm1_reqin3_first_x.sv"
    if CFIFO05_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_cfifo05_zero_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_cfifo05_zero_probe.sv"
    if CFIFO06_PROBE:
        local_files[REPO / "scripts/asic_dc/cmr/tb_cmr_cfifo06_internal_probe.sv"] = \
            ROOT + "/sim/tb/tb_cmr_cfifo06_internal_probe.sv"
    sftp = client.open_sftp()
    for source, destination in local_files.items():
        atomic_put(client, sftp, source, destination)
    sftp.close()
    remote_run(client, "sed -i 's/\\r$//' %s/scripts/run_gls_cmr_noc16.sh; "
                       "chmod +x %s/scripts/run_gls_cmr_noc16.sh" % (ROOT, ROOT))

    if CASE_FILE_OVERRIDE:
        case_name = CASE_NAME_OVERRIDE or Path(CASE_FILE_OVERRIDE).stem
        remote_cases = {case_name: CASE_FILE_OVERRIDE}
    else:
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

        wrapper = ROOT + "/logs/gls/%s/async_%s.sh" % (RUN_ID, name)
        body = (
            "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
            "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
            "CMR_NOC16_NETLIST_RUN_ID=%s CMR_NOC16_CASE_NAME=%s "
            "CMR_NOC16_CASE_FILE=%s CMR_NOC16_RX_CAPTURE_NS=%s "
            "CMR_NOC16_STALL_TIMEOUT_NS=%s CMR_NOC16_HARD_TIMEOUT_NS=%s "
            "CMR_NOC16_SIM_ARGS=%s "
            "CMR_NOC16_INJECT_MAX_RATE=%s "
            "CMR_NOC16_STRUCTURAL_ENDPOINTS=%s "
            "CMR_NOC16_SKIP_GLS=0 CMR_NOC16_UNEXPECTED_PROBE=0 "
            "CMR_NOC16_THIN_STALL_PROBE=%s "
            "CMR_NOC16_FUNCTIONAL_STALL_PROBE=%s "
            "CMR_NOC16_IPM1_ACK_PROBE=%s "
            "CMR_NOC16_IPM3_ACK_PROBE=%s "
            "CMR_NOC16_PHASE_SELECTOR_PROBE=%s "
            "CMR_NOC16_NOFIFO_STALL_PROBE=%s "
            "CMR_NOC16_P30_PORT5_PROBE=%s "
            "CMR_NOC16_VCTM_TAIL_PROBE=%s "
            "CMR_NOC16_VCTM_TAIL_TRACE=%s "
            "CMR_NOC16_VCTM_WP07_PROBE=%s "
            "CMR_NOC16_ROUTESELAND_X_PROBE=%s "
            "CMR_NOC16_ROUTESELAND_X_FULL=%s "
            "CMR_NOC16_L2AX_PROBE=%s CMR_NOC16_CFIFO05_PROBE=%s CMR_NOC16_CFIFO06_PROBE=%s\n"
            "exec bash %s/scripts/run_gls_cmr_noc16.sh\n" %
            (ROOT, RUN_ID, NETLIST_RUN_ID, name, path,
             RX_CAPTURE_NS, STALL_TIMEOUT_NS, HARD_TIMEOUT_NS,
             shlex.quote(SIM_ARGS),
             "1" if INJECT_MAX_RATE else "0",
             "1" if STRUCTURAL_ENDPOINTS else "0",
             "1" if THIN_STALL_PROBE else "0",
             "1" if FUNCTIONAL_STALL_PROBE else "0",
             "1" if IPM1_ACK_PROBE else "0",
             "1" if IPM3_ACK_PROBE else "0",
             "1" if PHASE_SELECTOR_PROBE else "0",
             "1" if NOFIFO_STALL_PROBE else "0",
             "1" if P30_PORT5_PROBE else "0",
             "1" if VCTM_TAIL_PROBE else "0",
             "1" if VCTM_TAIL_TRACE else "0",
             "1" if VCTM_WP07_PROBE else "0",
             "1" if ROUTESELAND_X_PROBE else "0",
             "1" if ROUTESELAND_X_FULL else "0",
             "1" if L2AX_PROBE else "0", "1" if CFIFO05_PROBE else "0", "1" if CFIFO06_PROBE else "0", ROOT)
        )
        sftp = client.open_sftp()
        atomic_put_bytes(client, sftp, body.encode(), wrapper)
        sftp.close()
        remote_run(client, "chmod +x " + wrapper)
        submit = remote_run(client,
            "bsub -n 8 -o %s/logs/gls/%s/async_%s.bsub.log "
            "-e %s/logs/gls/%s/async_%s.bsub.err -J cmr_async_%s_%s %s" %
            (ROOT, RUN_ID, name, ROOT, RUN_ID, name, RUN_ID, name, wrapper))
        match = re.search(r"Job <(\d+)>", submit)
        if not match:
            raise RuntimeError("submit failed: " + submit)
        jobs[name] = match.group(1)
        print("ASYNC_JOB", name, match.group(1), flush=True)

    for name, jid in jobs.items():
        client = wait_job(client, jid, "async_" + name, polls=480, allow_exit=True)

    all_pass = True
    status = {
        "run_id": RUN_ID,
        "harness": "async_failfast",
        "netlist_run_id": NETLIST_RUN_ID,
        "rx_capture_ns": RX_CAPTURE_NS,
        "stall_timeout_ns": STALL_TIMEOUT_NS,
        "hard_timeout_ns": HARD_TIMEOUT_NS,
        "sim_args": SIM_ARGS,
        "inject_max_rate": INJECT_MAX_RATE,
        "structural_endpoints": STRUCTURAL_ENDPOINTS,
        "thin_stall_probe": THIN_STALL_PROBE,
        "functional_stall_probe": FUNCTIONAL_STALL_PROBE,
        "ipm1_ack_probe": IPM1_ACK_PROBE,
        "ipm3_ack_probe": IPM3_ACK_PROBE,
        "phase_selector_probe": PHASE_SELECTOR_PROBE,
        "nofifo_stall_probe": NOFIFO_STALL_PROBE,
        "p30_port5_probe": P30_PORT5_PROBE,
        "vctm_tail_probe": VCTM_TAIL_PROBE,
        "vctm_tail_trace": VCTM_TAIL_TRACE,
        "vctm_wp07_probe": VCTM_WP07_PROBE,
        "routeseland_x_probe": ROUTESELAND_X_PROBE,
        "routeseland_x_full": ROUTESELAND_X_FULL,
        "l2ax_probe": L2AX_PROBE,
        "cfifo05_probe": CFIFO05_PROBE,
        "case_hashes": case_hashes,
        "cases": {},
    }
    for name, jid in jobs.items():
        base = ROOT + "/logs/gls/%s/sdf/%s" % (RUN_ID, name)
        run_log = remote_run(client, "cat %s/run.log 2>/dev/null" % base)
        annotate = remote_run(client, "cat %s/sdf_annotate.log 2>/dev/null" % base)
        errors = re.search(r"Total errors:\s*(\d+)", annotate)
        snap_lines = [line for line in run_log.splitlines() if "THIN_STALL_SNAP " in line]
        nofifo_snap = [line for line in run_log.splitlines() if "NOFIFO_STALL_" in line]
        func_snap = [line for line in run_log.splitlines() if line.startswith("FUNC_STALL_")]
        ack_retreat = [line for line in run_log.splitlines() if "FUNC_ACK_RETREAT " in line]
        wp_win = [line for line in run_log.splitlines() if line.startswith("WP_WIN ")]
        p5x = [line for line in run_log.splitlines() if line.startswith("P5X_")]
        vctm = [line for line in run_log.splitlines() if line.startswith("VCTM_")]
        wp05 = [line for line in run_log.splitlines() if line.startswith("VCTM_WP05")]
        wp06 = [line for line in run_log.splitlines() if line.startswith("VCTM_WP06")]
        wp07 = [line for line in run_log.splitlines() if line.startswith("VCTM_WP07")]
        routeseland_x = [line for line in run_log.splitlines()
                         if line.startswith("ROUTESELAND_")]
        l2ax = [line for line in run_log.splitlines() if line.startswith("L2AX_")]
        tchk = [line for line in run_log.splitlines()
                if "Timing violation" in line or "timing violation" in line]
        ipm1_retreat = [line for line in run_log.splitlines() if "IPM1_ACK_RETREAT " in line]
        ipm3_retreat = [line for line in run_log.splitlines() if "IPM3_ACK_RETREAT " in line]
        sr = harvest_sr_lines(run_log) if THIN_STALL_PROBE else {
            "edge_count": 0, "overlap_count": 0, "miss_count": 0, "clr_count": 0,
            "overlap": [], "miss": [], "clr": [], "last_packet_window": [],
        }
        result_line = next(
            (line for line in run_log.splitlines()
             if "TB_RESULT " in line or "TB_STALL_FAIL t=" in line
             or "TB_HARD_TIMEOUT t=" in line or "TB_UNEXPECTED_FAIL" in line
             or "TB_X_FAIL" in line),
            None,
        )
        entry = {
            "job_id": jid,
            "tb_pass": "TB_RESULT PASS" in run_log,
            "annotation_done": "Doing SDF annotation ...... Done" in run_log,
            "annotation_errors": int(errors.group(1)) if errors else None,
            "ifnsdfa": "IFNSDFA" in run_log,
            "unexpected_failure": "TB_UNEXPECTED_FAIL" in run_log,
            "stall_failure": "TB_STALL_FAIL" in run_log,
            "hard_timeout": "TB_HARD_TIMEOUT" in run_log,
            "timing_violation_count": run_log.count("Timing violation"),
            "result_line": result_line,
            "snap_lines": snap_lines,
            "nofifo_snap": nofifo_snap,
            "func_snap": func_snap[:40],
            "ack_retreat": ack_retreat[:20],
            "wp_win": wp_win[:80],
            "p5x": p5x[:80],
            "vctm": vctm[:120],
            "wp05": wp05,
            "wp06": wp06,
            "wp07": wp07,
            "routeseland_x": routeseland_x,
            "l2ax": l2ax,
            "tchk": tchk[:40],
            "ipm1_retreat": ipm1_retreat[:12],
            "ipm3_retreat": ipm3_retreat[:12],
            "sr": sr,
        }
        passed = (
            entry["tb_pass"]
            and entry["annotation_done"]
            and entry["annotation_errors"] == 0
            and not entry["ifnsdfa"]
            and not entry["unexpected_failure"]
            and not entry["stall_failure"]
            and not entry["hard_timeout"]
            and entry["timing_violation_count"] == 0
        )
        all_pass &= passed
        status["cases"][name] = entry
        print("ASYNC_CASE", name, "PASS" if passed else "FAIL", result_line, flush=True)
        for snap in snap_lines:
            print(snap, flush=True)
        for line in nofifo_snap:
            print(line, flush=True)
        for line in func_snap[:24]:
            print(line, flush=True)
        for line in [x for x in wp_win if "ones=0" in x or "ones=2" in x or "ones=3" in x][:24]:
            print(line, flush=True)
        for line in [x for x in wp_win if "t=257" in x or "t=256" in x or "t=258" in x][:24]:
            print(line, flush=True)
        for line in wp_win[:8]:
            print(line, flush=True)
        for line in wp_win[-12:]:
            print(line, flush=True)
        for line in ack_retreat[:8] + ipm1_retreat[:8] + ipm3_retreat[:8]:
            print(line, flush=True)
        for line in p5x:
            print(line, flush=True)
        for line in vctm:
            print(line, flush=True)
        for line in wp05:
            print(line, flush=True)
        for line in wp06:
            print(line, flush=True)
        for line in wp07:
            print(line, flush=True)
        for line in routeseland_x:
            print(line, flush=True)
        for line in l2ax:
            print(line, flush=True)
        for line in tchk:
            print(line, flush=True)
        # #region agent log
        debug_log = REPO / "debug-949621.log"
        with debug_log.open("a", encoding="utf-8") as handle:
            payload = {
                "sessionId": "949621",
                "runId": RUN_ID,
                "hypothesisId": "H1-H5",
                "location": "run_remote_cmr_noc16_async_sdf.py:harvest",
                "message": "l2ax_acklatch_harvest",
                "data": {
                    "first_x": [ln for ln in l2ax if ln.startswith("L2AX_FIRST_X")],
                    "snaps_293": [ln for ln in l2ax if "t_ns=293" in ln or "t_ns=295" in ln],
                    "tchk": tchk[:20],
                },
                "timestamp": int(datetime.now().timestamp() * 1000),
            }
            handle.write(json.dumps(payload, ensure_ascii=True) + "\n")
        # #endregion
        if vctm:
            debug_log = REPO / "debug-949621.log"
            with debug_log.open("a", encoding="utf-8") as handle:
                for line in vctm:
                    hid = "V1"
                    if "H=V2" in line:
                        hid = "V2"
                    elif "H=V3" in line:
                        hid = "V3"
                    elif "H=V6" in line or "VCTM_RI" in line:
                        hid = "V6"
                    elif "H=V4" in line or "path_zero=1" in line:
                        hid = "V4"
                    elif "H=V5" in line:
                        hid = "V5"
                    handle.write(json.dumps({
                        "sessionId": "949621",
                        "runId": RUN_ID,
                        "hypothesisId": hid,
                        "location": "tb_cmr_vctm_tail_stall_probe.sv",
                        "message": line,
                        "data": {"case": name},
                        "timestamp": int(datetime.now().timestamp() * 1000),
                    }) + "\n")
        if p5x:
            debug_log = REPO / "debug-949621.log"
            with debug_log.open("a", encoding="utf-8") as handle:
                for line in p5x:
                    hid = "H1"
                    if "H=H5" in line or "P5X_EARLY" in line:
                        hid = "H5"
                    elif "H=H3" in line or "P5X_ONES0" in line:
                        hid = "H3"
                    elif "H=H2" in line or "P5X_ACK" in line:
                        hid = "H2"
                    elif "H6" in line:
                        hid = "H6"
                    handle.write(json.dumps({
                        "sessionId": "949621",
                        "runId": RUN_ID,
                        "hypothesisId": hid,
                        "location": "tb_cmr_p30_port5_x_probe.sv",
                        "message": line,
                        "data": {"case": name},
                        "timestamp": int(datetime.now().timestamp() * 1000),
                    }) + "\n")
        if THIN_STALL_PROBE:
            print("THIN_SR_COUNTS edges=%d overlap=%d miss=%d clr=%d" % (
                sr["edge_count"], sr["overlap_count"], sr["miss_count"], sr["clr_count"]
            ), flush=True)
            for line in sr["overlap"] + sr["miss"] + sr["clr"] + sr["last_packet_window"]:
                print(line, flush=True)

    RESULT.mkdir(parents=True, exist_ok=True)
    (RESULT / "summary.json").write_text(json.dumps(status, indent=2) + "\n", encoding="utf-8")
    sftp = client.open_sftp()
    for name in jobs:
        for fname in ("run.log", "result.csv", "compile.log", "sdf_annotate.log",
                      "events.csv", "latency.csv"):
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
