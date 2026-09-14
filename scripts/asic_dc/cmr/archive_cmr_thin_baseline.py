#!/usr/bin/env python3
"""Collect the frozen thin NoC16 rollback baseline without touching the netlist.

Reads remote DC reports/hashes for the current CircularFIFO replacement
(20260827_cmr_cfifo_noc16_rd01_eco16_p50_01), hashes current RTL/TB/DC Tcl,
and writes a git-tracked manifest.  Does not resynthesize.  The AsyncFifo
predecessor 20260826_cmr_thin_1lane_rs_dc_01 remains archived beside this run.
"""
from __future__ import annotations

import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

from run_remote_cmr_flow import remote_run, sha256_file
from run_remote_cmr_noc16_sdf import ROOT, connect, fetch_tree


REPO = Path(__file__).resolve().parents[3]
RUN_ID = "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
GLS_RUN_ID = "20260827_cmr_cfifo_noc16_rd01_eco16_full_01"
PREDECESSOR_RUN_ID = "20260826_cmr_thin_1lane_rs_dc_01"
OUT = REPO / "docs" / "timing_baselines"
LOCAL_DC = REPO / "scripts" / "asic_dc" / "cmr" / "results" / RUN_ID

INPUTS = (
    "generated_cmr/noc16/NoC_16nodes.v",
    "generated_cmr/noc16/AddressRegisterUnit.v",
    "generated_cmr/noc16/RouteSelAnd2.v",
    "generated_cmr/noc16/OPMSelector.v",
    "generated_cmr/noc16/HeadPredictor.v",
    "generated_cmr/noc16/WriteCounter.v",
    "generated_cmr/noc16/DelayElement_ASIC.v",
    "generated_cmr/noc16/Mutex2_ASIC.v",
    "generated_cmr/noc16/Mutex4.v",
    "src/main/scala/Router_Architecture/CMR/CMRRouter.scala",
    "src/main/scala/Router_Architecture/CMR/RCU.scala",
    "src/main/scala/Router_Architecture/CMR/OPM.scala",
    "src/main/scala/Router_Architecture/CMR/CMRTypes.scala",
    "src/main/scala/Router_Architecture/common/async/CircularFifo.scala",
    "src/main/resources/ASYNC/DelayElement_ASIC.v",
    "src/main/resources/ASYNC/Mutex2_ASIC.v",
    "src/main/resources/ASYNC/CMR/CircularFIFO.v",
    "src/main/resources/ASYNC/CMR/WriteControlBlock.v",
    "src/main/resources/ASYNC/CMR/ReadControlBlock.v",
    "src/main/resources/ASYNC/CMR/CircularWriteCounter.v",
    "src/main/resources/ASYNC/CMR/CircularReadCounter.v",
    "scripts/asic_dc/cmr/run_dc_cmr_noc16.tcl",
    "scripts/asic_dc/cmr/async_cmr_router.sdc",
    "scripts/asic_dc/async_primitives.tcl",
    "scripts/asic_dc/assert_no_gtech.tcl",
    "scripts/asic_dc/tech_t28ss.tcl",
    "scripts/asic_dc/cmr/run_gls_cmr_noc16.sh",
    "scripts/asic_dc/cmr/tb_cmr_noc16_async_boundary_failfast.sv",
    "sim/AsyncNoC/testbench/tb_noc16_async_boundary.sv",
)


def git(command: list[str]) -> str:
    try:
        return subprocess.check_output(command, cwd=REPO, text=True, errors="replace").strip()
    except (OSError, subprocess.CalledProcessError):
        return "UNAVAILABLE"


def parse_kv(text: str) -> dict[str, str]:
    out = {}
    for line in text.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            out[key.strip()] = value.strip()
    return out


def parse_csv(text: str) -> dict[str, int]:
    out = {}
    for line in text.splitlines()[1:]:
        if "," not in line:
            continue
        name, count = line.split(",", 1)
        try:
            out[name.strip()] = int(count.strip())
        except ValueError:
            out[name.strip()] = count.strip()
    return out


def gls_case(summary_path: Path, name: str) -> dict:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    case = data["cases"][name]
    return {
        "gls_run_id": data["run_id"],
        "case": name,
        "case_sha256": data["case_hashes"][name],
        "job_id": case["job_id"],
        "result_line": case.get("result_line") or "",
        "tb_pass": case["tb_pass"],
        "annotation_errors": case.get("annotation_errors", 0),
        "timing_violation_count": case.get("timing_violation_count", 0),
        "stall_failure": case.get("stall_failure", False),
        "unexpected_failure": case.get("unexpected_failure", False),
        "harness": data.get("harness", "async_failfast"),
        "rx_capture_ns": data.get("rx_capture_ns"),
        "sim_args": data.get("sim_args", ""),
        "structural_endpoints": data.get("structural_endpoints", False),
        "netlist_run_id": data.get("netlist_run_id", RUN_ID),
        "local_summary": str(summary_path.relative_to(REPO)).replace("\\", "/"),
    }


def compact_cases(summary_path: Path) -> list[dict]:
    data = json.loads(summary_path.read_text(encoding="utf-8"))
    rows = []
    for name, case in data["cases"].items():
        result = case.get("result_line") or ""
        delivered = None
        match = re.search(r"delivered=(\d+)", result)
        if match:
            delivered = int(match.group(1))
        rows.append({
            "case": name,
            "pass": bool(case["tb_pass"] and case.get("annotation_errors") == 0
                         and case.get("timing_violation_count") == 0
                         and not case.get("stall_failure")
                         and not case.get("unexpected_failure")),
            "delivered": delivered,
            "result_line": result,
            "case_sha256": data["case_hashes"].get(name),
            "job_id": case.get("job_id"),
        })
    return rows


def fetch_gls_hashes(client) -> str:
    chunks = []
    for gls_id in (GLS_RUN_ID, RUN_ID):
        chunks.append(remote_run(
            client,
            "echo '=== GLS_RUN %s ==='; "
            "echo '=== VCTM_p50 ==='; "
            "cat %s/logs/gls/%s/sdf/VCTM-MC5-NM-3f-r0p50/input_hashes.log 2>/dev/null; "
            "echo '=== TAB_p50 ==='; "
            "cat %s/logs/gls/%s/sdf/TAB-NET-UR-3f-r0p50/input_hashes.log 2>/dev/null"
            % (gls_id, ROOT, gls_id, ROOT, gls_id),
        ))
    return "\n".join(chunks)


def main() -> None:
    client = connect()
    remote_dc = "%s/reports/dc/%s" % (ROOT, RUN_ID)
    remote_out = "%s/outputs/%s" % (ROOT, RUN_ID)
    remote_log = "%s/logs/dc/%s.log" % (ROOT, RUN_ID)
    LOCAL_DC.mkdir(parents=True, exist_ok=True)
    sftp = client.open_sftp()
    fetch_tree(sftp, remote_dc, LOCAL_DC / "reports_dc")
    sftp.close()

    structure_text = remote_run(client, "cat %s/cmr_noc16_structure.rpt" % remote_dc)
    hashes_text = remote_run(client, "cat %s/post_hashes.sha256" % remote_dc)
    primitives_text = remote_run(client, "cat %s/async_primitives.csv" % remote_dc)
    dc_keys = remote_run(
        client,
        "grep -E 'CMR_NOC16_LATCH_PRE|CMR_NOC16_STRUCTURE|CMR_NOC16_DC_PASS|"
        "CMR_NOC16_DC_FAIL|CMR_WP_REQ_DEL250|CMR_CFIFO_|GTECH=|Job <|Subject:' %s"
        % remote_log,
    )
    ls_out = remote_run(client, "ls -l %s" % remote_out)
    fifo_counts = remote_run(
        client,
        "cd %s; "
        "echo DEL150_INST $(grep -c 'DEL150D1BWP12T30P140' NoC_16nodes_post.v); "
        "echo DEL250_INST $(grep -c 'DEL250D1BWP12T30P140' NoC_16nodes_post.v); "
        "echo OUTREQDELAY $(grep -c 'outReqDelay' NoC_16nodes_post.v); "
        "echo MATCHEDDELAY $(grep -c 'MatchedDelay' NoC_16nodes_post.v); "
        "echo ACKINDELAY $(grep -c 'AckinDelay' NoC_16nodes_post.v); "
        "echo DFIRE $(grep -c 'Dfire' NoC_16nodes_post.v); "
        "echo ADAPTER $(grep -c 'LanePhaseAdapter' NoC_16nodes_post.v); "
        "echo CIRCULAR $(grep -c 'CircularFifo' NoC_16nodes_post.v); "
        "echo WP_ECO $(grep -c 'wp_hs02_req_dly' NoC_16nodes_post.v); "
        "echo CFIFO_HS02 $(grep -c 'cfifo_hs02_ack_counter_buf' NoC_16nodes_post.v); "
        "echo CFIFO_RD01 $(grep -c 'cfifo_rd01_reqout_buf' NoC_16nodes_post.v)"
        % remote_out,
    )
    gls_hashes = fetch_gls_hashes(client)
    client.close()

    (LOCAL_DC / "dc_keys.log").write_text(dc_keys, encoding="utf-8")
    (LOCAL_DC / "outputs_ls.txt").write_text(ls_out, encoding="utf-8")
    (LOCAL_DC / "fifo_counts.txt").write_text(fifo_counts, encoding="utf-8")
    (LOCAL_DC / "gls_input_hashes.log").write_text(gls_hashes, encoding="utf-8")

    structure = parse_kv(structure_text)
    primitives = parse_csv(primitives_text)
    post_hashes = {}
    for line in hashes_text.splitlines():
        parts = line.split()
        if len(parts) >= 2 and len(parts[0]) == 64 and all(c in "0123456789abcdef" for c in parts[0]):
            post_hashes[parts[1].split("/")[-1]] = parts[0]

    fifo_map = {}
    for line in fifo_counts.splitlines():
        bits = line.split()
        if len(bits) == 2:
            fifo_map[bits[0]] = int(bits[1]) if bits[1].isdigit() else bits[1]

    local_hashes = {}
    missing = []
    for relative in INPUTS:
        path = REPO / relative
        if path.is_file():
            local_hashes[relative] = sha256_file(path)
        else:
            missing.append(relative)

    results = REPO / "scripts" / "asic_dc" / "cmr" / "results"
    full_summary = results / GLS_RUN_ID / "summary.json"
    tab_p50 = gls_case(full_summary, "TAB-NET-UR-3f-r0p50")
    vctm_p50 = gls_case(full_summary, "VCTM-MC5-NM-3f-r0p50")
    all_rows = compact_cases(full_summary)
    tab_rows = [row for row in all_rows if row["case"].startswith("TAB")]
    vctm_rows = [row for row in all_rows if row["case"].startswith("VCTM")]
    if tab_p50.get("netlist_run_id") not in (RUN_ID, None):
        raise SystemExit("full GLS netlist_run_id %s != %s" % (tab_p50.get("netlist_run_id"), RUN_ID))
    if not tab_p50["tb_pass"] or tab_p50["annotation_errors"] != 0 or tab_p50["timing_violation_count"] != 0:
        raise SystemExit("canonical TAB p50 is not a clean PASS")
    if not vctm_p50["tb_pass"] or vctm_p50["annotation_errors"] != 0 or vctm_p50["timing_violation_count"] != 0:
        raise SystemExit("canonical VCTM p50 is not a clean PASS")
    if not all(row["pass"] for row in tab_rows + vctm_rows):
        raise SystemExit("rate sweep contains a non-PASS case")
    if len(tab_rows) != 10 or len(vctm_rows) != 10:
        raise SystemExit("expected 10 TAB + 10 VCTM sweep cases, got %d/%d" % (len(tab_rows), len(vctm_rows)))

    dc_key_lines = [
        line.strip() for line in dc_keys.splitlines()
        if line.startswith((
            "CMR_NOC16_LATCH_PRE ",
            "CMR_NOC16_STRUCTURE ",
            "CMR_NOC16_DC_PASS ",
            "CMR_WP_REQ_DEL250 disabled",
            "CMR_CFIFO_",
            "Subject:",
            "Job <",
        ))
    ]
    gls_hash_map = {"vctm_p50": {}, "tab_p50": {}}
    section = None
    for line in gls_hashes.splitlines():
        if line.startswith("=== VCTM"):
            section = "vctm_p50"
        elif line.startswith("=== TAB"):
            section = "tab_p50"
        elif section and line[:2].isalnum() and "  " in line:
            digest, path = line.split(None, 1)
            gls_hash_map[section][path.split("/")[-1]] = digest

    del150_total = int(primitives.get("DEL150_delay", fifo_map.get("DEL150_INST", 0)))
    rcu_del = int(structure.get("RCU_DEL150_COUNT", 0))
    fifo_del = int(fifo_map.get("OUTREQDELAY", 0))
    fifo_dfire = max(0, del150_total - rcu_del - fifo_del)

    expected_structure = {
        "ROUTER": 5,
        "FIFO": 8,
        "ASYNC_FIFO": 0,
        "CIRCULAR_FIFO": 8,
        "IPM": 25,
        "OPM": 25,
        "MUTEX4": 25,
        "MUTEX2": 75,
        "ADAPTER": 0,
        "RCU_DE": 25,
        "RCU_DEL150": 100,
        "OPM_ACKIN_DE": 25,
        "OPM_ACKIN_DEL250": 25,
        "FIFO_DEL150": 0,
        "FIFO_DFIRE_DEL150": 0,
        "DEL150_TOTAL": 100,
        "WP_REQ_DEL250": 0,
        "ACK_FEEDBACK_BUF": 0,
        "CFIFO_HS02_BUF": 24,
        "CFIFO_RD01_BUF": 512,
        "CLEAR": 6669,
        "SET": 498,
    }
    counts = {
        "ROUTER": int(structure.get("ROUTER_COUNT", 0)),
        "FIFO": int(structure.get("INTERLEVEL_FIFO_COUNT", 0)),
        "EXPECTED_FIFO": int(structure.get("EXPECTED_INTERLEVEL_FIFO_COUNT", 0)),
        "ASYNC_FIFO": int(structure.get("ASYNC_FIFO_COUNT", 0)),
        "CIRCULAR_FIFO": int(structure.get("CIRCULAR_FIFO_COUNT", 0)),
        "IPM": int(structure.get("IPM_COUNT", 0)),
        "OPM": int(structure.get("OPM_COUNT", 0)),
        "MUTEX4": int(structure.get("MUTEX4_COUNT", 0)),
        "MUTEX2": int(structure.get("MUTEX2_COUNT", 0)),
        "ADAPTER": int(structure.get("LANE_PHASE_ADAPTER_COUNT", 0)),
        "RCU_DE": int(structure.get("RCU_DELAY_ELEMENT_COUNT", 0)),
        "RCU_DEL150": rcu_del,
        "OPM_ACKIN_DE": int(structure.get("OPM_ACKIN_DELAY_ELEMENT_COUNT", 0)),
        "OPM_ACKIN_DEL250": int(structure.get("OPM_ACKIN_DEL250_COUNT", 0)),
        "FIFO_DEL150": fifo_del,
        "FIFO_DFIRE_DEL150": fifo_dfire,
        "DEL150_TOTAL": del150_total,
        "WP_REQ_DEL250": int(structure.get("WP_REQ_DEL250_COUNT", 0)),
        "HS01_HEAD_BUF": int(structure.get("HS01_HEAD_BUFFER_COUNT", 0)),
        "HS01_TAIL_BUF": int(structure.get("HS01_TAIL_BUFFER_COUNT", 0)),
        "ACK_FEEDBACK_BUF": int(structure.get("ACK_FEEDBACK_BUFFER_COUNT", 0)),
        "CFIFO_HS02_BUF": int(structure.get("CFIFO_HS02_ACK_COUNTER_BUFFER_COUNT", 0)),
        "CFIFO_RD01_BUF": int(structure.get("CFIFO_RD01_REQOUT_BUFFER_COUNT", 0)),
        "CLEAR": int(structure.get("RESET_LATCH_COUNT", 0)),
        "SET": int(structure.get("SET_RESET_LATCH_COUNT", 0)),
        "SR": int(structure.get("SR_LATCH_COUNT", 0)),
        "PATH_LATCH_CLEAR": int(structure.get("PATH_LATCH_CLEAR_COUNT", 0)),
        "V2_CLOSE_EVENT": int(structure.get("V2_CLOSE_EVENT_COUNT", 0)),
        "HANDSHAKE_COMPLETE": int(structure.get("HANDSHAKE_COMPLETE_COUNT", 0)),
    }
    mismatches = {k: {"actual": counts[k], "expected": v} for k, v in expected_structure.items() if counts.get(k) != v}
    if mismatches:
        raise SystemExit("structure mismatch vs thin freeze: %s" % json.dumps(mismatches))
    if "CMR_NOC16_DC_PASS" not in dc_keys:
        raise SystemExit("frozen DC log is missing CMR_NOC16_DC_PASS")

    manifest = {
        "schema": "cmr-thin-timing-baseline-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "baseline_run_id": RUN_ID,
        "role": "rollback point for thin NoC16 timing steps C–F; do not mutate this netlist",
        "predecessor_run_id": PREDECESSOR_RUN_ID,
        "dut": {
            "topology": "thin NoC16",
            "lanes": 1,
            "circular_fifo": True,
            "lane_phase_adapter": 0,
            "interlevel_fifo": "CircularFIFO DEPTH=4 (eight L1–L2 links)",
            "library": "T28SS tcbn28hpcplus BWP12T30P140",
            "pvt_sta_gls": "ssg0p81v125c / SDF MAXIMUM",
            "sdc": "async_cmr_router.sdc is a clock stub; NoC16 DC does not source a production RTC SDC",
            "cfifo_eco": "TCF-HS-02 3×BUFFD0 on ReadCounter XNOR A1; TCF-RD-01 16×BUFFD0 on Reqout XOR A*",
        },
        "git_head_at_archive": git(["git", "rev-parse", "HEAD"]),
        "remote": {
            "root": ROOT,
            "dc_log": "%s/logs/dc/%s.log" % (ROOT, RUN_ID),
            "reports_dc": "%s/reports/dc/%s" % (ROOT, RUN_ID),
            "outputs": "%s/outputs/%s" % (ROOT, RUN_ID),
        },
        "artifact_paths": {
            "post_v": "%s/outputs/%s/NoC_16nodes_post.v" % (ROOT, RUN_ID),
            "ddc": "%s/outputs/%s/NoC_16nodes.ddc" % (ROOT, RUN_ID),
            "sdf": "%s/outputs/%s/NoC_16nodes.sdf" % (ROOT, RUN_ID),
            "sdc_out": "%s/outputs/%s/NoC_16nodes.sdc" % (ROOT, RUN_ID),
            "local_dc_reports": str((LOCAL_DC / "reports_dc").relative_to(REPO)).replace("\\", "/"),
        },
        "post_artifact_sha256": post_hashes,
        "dc_job_id": next(
            (re.search(r"Job (\d+):", line).group(1) for line in dc_key_lines if re.search(r"Job (\d+):", line)),
            "",
        ),
        "dc_log_keys": dc_key_lines,
        "structure_counts": counts,
        "structure_rpt_raw": structure,
        "async_primitives": primitives,
        "post_v_cell_scan": fifo_map,
        "workspace_inputs_sha256": local_hashes,
        "missing_inputs": missing,
        "equivalence_policy": {
            "rollback_identity": "remote post.v / ddc / sdf SHA-256 for this run_id",
            "required_structure": [
                "ROUTER=5 FIFO=8 ASYNC_FIFO=0 CIRCULAR_FIFO=8 IPM=25 OPM=25",
                "MUTEX4=25 MUTEX2=75 ADAPTER=0",
                "RCU_DEL150=100 OPM_ACKIN_DEL250=25 FIFO_DEL150=0 FIFO_DFIRE_DEL150=0",
                "DEL150_TOTAL=100 WP_REQ_DEL250=0 ACK_FEEDBACK_BUF=0",
                "CFIFO_HS02_BUF=24 CFIFO_RD01_BUF=512 CLEAR=6669 SET=498",
            ],
            "required_gls": "strict SDF MAXIMUM TAB p50 + VCTM p50 PASS, annotation_errors=0, timing_violation_count=0",
            "note": "workspace_inputs_sha256 is the archive-time source tree; later edits do not change the frozen netlist. Failed timing candidates must reuse this DDC, not a new emit.",
        },
        "gls": {
            "canonical_tab_p50": tab_p50,
            "canonical_vctm_p50": vctm_p50,
            "tab_rate_sweep_p02_p90": {
                "run_id": GLS_RUN_ID,
                "all_pass": True,
                "cases": tab_rows,
            },
            "vctm_rate_sweep_p02_p90": {
                "run_id": GLS_RUN_ID,
                "all_pass": True,
                "cases": vctm_rows,
            },
            "same_run_p50": {
                "run_id": RUN_ID,
                "jobs": {"TAB": "11440901", "VCTM": "11441001"},
                "note": "DC-job sibling p50 also PASS; full sweep below is the archived rate evidence",
            },
            "not_evidence": [
                "20260826_cmr_cfifo_noc16_p50_01 TAB p50 UNEXPECTED at 2376 ns (pre-RD01 ECO); not this baseline",
                "20260827_cmr_cfifo_noc16_rd01_p50_02 DC FAIL TCF-RD-01 slack -19.4 ps at 14 buffer stages",
            ],
        },
        "gls_input_sha256": gls_hash_map,
        "dc_env": {
            "ASYNC_PRIMITIVES": "asic",
            "ASYNC_DELAY_PROFILE": "P150_BASELINE (unset; AsyncDelay default)",
            "CMR_USE_CIRCULAR_FIFO": "1",
            "CMR_BYPASS_INTERLEVEL_FIFO": "0",
            "CMR_ACK_FEEDBACK_BUFFER_STAGES": "0",
            "CMR_WP_REQ_DEL250_ENABLE": "0",
        },
    }
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("cmr_noc16_structure.rpt", "post_hashes.sha256", "async_primitives.csv"):
        src = LOCAL_DC / "reports_dc" / name
        if src.is_file():
            (OUT / ("%s_%s" % (RUN_ID, name))).write_bytes(src.read_bytes())
    target = OUT / ("%s_baseline_manifest.json" % RUN_ID)
    target.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(target)
    print("STRUCTURE", json.dumps(manifest["structure_counts"]))
    print("POST_HASHES", json.dumps(post_hashes, indent=2))


if __name__ == "__main__":
    main()
