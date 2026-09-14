#!/usr/bin/env python3
"""Archive completed 20260914 multicast and c1p4 runs with explicit evidence limits."""
from __future__ import annotations

import csv
import hashlib
import json
import math
import re
import statistics
from pathlib import Path

from run_emergency_multicast import RAW_ROOT, RESULT_ROOT, CASE_DIR, summarize_case

REPO = Path(__file__).resolve().parents[3]
HOP_RUN = "20260914_cmr_c1p4_async_sync_hop_ppa"
HOP_DIR = REPO / "scripts/asic_dc/cmr/results" / HOP_RUN
REGISTRY = REPO / "DATE paper/experiments/registry/runs"
MAIN_RUN = "20260914_prop_temp64_mc_f16_main"
SMOKE_RUN = "20260914_prop_temp64_mc_f16_smoke"
FANOUT_RUN = "20260914_prop_temp64_mc_fanout_m5"
F32_RUN = "20260914_prop_temp64_mc_f32_probe_m5"
F32_M20_RUN = "20260914_prop_temp64_mc_f32_probe_m20"
MID_RUN = "20260914_prop_temp64_mc_f16_knee_mid"
MID_LOADS = (60, 100, 150)
SCHEMES = ("native", "source_repeated_unicast")
LOADS = (5, 10, 20, 40, 80, 120, 180, 260, 360, 500)
MAIN_FIELDS = ("load", "offered_transactions", "completed_transactions", "useful_delivery_rate",
               "mean_completion_latency", "p95_completion_latency", "p99_completion_latency",
               "injected_flits", "link_traversals", "backlog")
FANOUT_FIELDS = ("scheme", "fanout", "mean_completion_latency", "link_traversals",
                 "injected_flits", "useful_delivery_rate")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write_csv(path: Path, fields: tuple[str, ...], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)


def check_case(run: str, row: dict) -> dict:
    local = RESULT_ROOT / run / row["case"]
    runlog = (local / "run.log").read_text(encoding="utf-8", errors="replace")
    stdout = (local / "stdout.log").read_text(encoding="utf-8", errors="replace")
    sdf = (local / "sdf_annotate.log").read_text(encoding="utf-8", errors="replace")
    compilelog = (local / "compile.log").read_text(encoding="utf-8", errors="replace")
    assert "TB_RESULT PASS" in runlog and "missing=0 unexpected=0 timeout=0" in runlog, row
    assert "PROP_TEMP64_GLS_PASS " + row["case"] in stdout, row
    assert re.search(r"Total errors:\s*0\b", sdf) and "Doing SDF annotation ...... Done" in stdout, row
    assert re.search(r"Total errors:\s*0\b", compilelog), row
    assert not re.search(r"TB_RESULT FAIL|Fatal:|Timing violation|TB_X_FAIL|TB_STALL_FAIL", runlog), row
    case = CASE_DIR / (row["case"] + ".case")
    sidecar = CASE_DIR / (row["case"] + ".packets.json")
    return {"run_id": run, "case": row["case"], "case_sha256": sha(case),
            "packet_model_sha256": sha(sidecar), "trace_sha256": row["trace_sha256"],
            "sdf_total_errors": 0, "tb_result": "PASS", "gls_result": "PASS",
            "completed_in_window": row["completed_count"], "window_backlog": row["backlog"]}


def main() -> None:
    main_rows = [(MAIN_RUN, summarize_case(MAIN_RUN, 16, load, scheme))
                 for load in LOADS for scheme in SCHEMES]
    main_rows += [(MID_RUN, summarize_case(MID_RUN, 16, load, scheme))
                  for load in MID_LOADS for scheme in SCHEMES]
    main_rows.sort(key=lambda x: (x[1]["load"], x[1]["scheme"]))
    fanout_rows = []
    for f in (2, 4, 8, 16, 32):
        run = FANOUT_RUN if f in (2, 4, 8) else MAIN_RUN if f == 16 else F32_RUN
        fanout_rows.extend(summarize_case(run, f, 5, scheme) for scheme in SCHEMES)
    jobs = {}
    for run in (MAIN_RUN, SMOKE_RUN, FANOUT_RUN, F32_RUN, F32_M20_RUN, MID_RUN):
        path = RESULT_ROOT / (run + "_jobs.json")
        for job in json.loads(path.read_text(encoding="utf-8"))["jobs"]:
            jobs[(run, job["case"])] = job["job_id"]
    case_rows = []
    for run, row in (main_rows +
                     [(FANOUT_RUN if row["fanout"] in (2, 4, 8) else F32_RUN, row)
                      for row in fanout_rows if row["fanout"] != 16] +
                     [(F32_M20_RUN, summarize_case(F32_M20_RUN, 32, 20, scheme))
                      for scheme in SCHEMES]):
        entry = check_case(run, row)
        entry.update({"scheme": row["scheme"], "fanout": row["fanout"],
                      "load": row["load"], "lsf_job_id": jobs[(run, row["case"])],
                      "netlist_run_id": "20260913_prop_temp64_asap_uc_m5_200"})
        case_rows.append(entry)
    assert len(case_rows) == 36
    for rows in ([r for _run, r in main_rows], fanout_rows):
        pairs = {}
        for row in rows:
            pairs.setdefault((row["fanout"], row["load"]), set()).add(row["trace_sha256"])
        assert all(len(hashes) == 1 for hashes in pairs.values())

    for scheme in SCHEMES:
        sub = RAW_ROOT / scheme
        subset = [r for _run, r in main_rows if r["scheme"] == scheme]
        write_csv(sub / "multicast_main.csv", MAIN_FIELDS, subset)
        write_csv(RAW_ROOT / ("multicast_main_" + scheme + ".csv"), MAIN_FIELDS, subset)
    write_csv(RAW_ROOT / "multicast_fanout.csv", FANOUT_FIELDS,
              sorted(fanout_rows, key=lambda r: (r["scheme"], r["fanout"])))
    write_csv(RAW_ROOT / "multicast_main_evidence.csv", tuple(main_rows[0][1]),
              [r for _run, r in main_rows])
    write_csv(RAW_ROOT / "multicast_fanout_evidence.csv", tuple(fanout_rows[0]), fanout_rows)
    write_csv(RAW_ROOT / "case_run_job_hash.csv", tuple(case_rows[0]), case_rows)

    hop = json.loads((HOP_DIR / "summary.json").read_text(encoding="utf-8"))
    assert {a["kind"] for a in hop["artifacts"]} == {"async_fat_1x4", "sync_fat_1x4"}
    router = []
    router_jobs = []
    launch_logs = (REPO / ".codex/runs/20260914_cmr_c1p4_async_sync_hop_ppa.out.log",
                   REPO / ".codex/runs/20260914_cmr_c1p4_async_sync_hop_ppa_resume.out.log",
                   REPO / ".codex/runs/20260914_cmr_c1p4_async_sync_hop_ppa_resume2.out.log")
    job_text = "\n".join(path.read_text(encoding="utf-8", errors="replace")
                         for path in launch_logs if path.is_file())
    for a in hop["artifacts"]:
        kind = a["kind"]
        for mode in ("isolated", "stream", "idle", "contention"):
            m = a["modes"][mode]
            local = HOP_DIR / kind / mode
            runlog = (local / "gls/run.log").read_text(encoding="utf-8", errors="replace")
            sdf = (local / "gls/sdf_annotate.log").read_text(encoding="utf-8", errors="replace")
            powerlog = (local / "power/lsf.log").read_text(encoding="utf-8", errors="replace")
            checkpower = (local / "power/check_power.rpt").read_text(encoding="utf-8").strip()
            assert "PPA_RESULT PASS" in runlog and re.search(r"Total errors:\s*0\b", sdf), (kind, mode)
            assert "PPA_POWER_PASS" in powerlog and checkpower.splitlines()[-1] == "0", (kind, mode)
            gls_jobs = re.findall(r"JOB_SUBMIT " + re.escape(kind + "_" + mode + "_gls") + r"\s+(\d+)", job_text)
            power_jobs = re.findall(r"JOB_SUBMIT " + re.escape(kind + "_" + mode + "_ptpx") + r"\s+(\d+)", job_text)
            assert gls_jobs and power_jobs, (kind, mode)
            router_jobs.append({"kind": kind, "mode": mode,
                                "gls_job_id": gls_jobs[-1], "power_job_id": power_jobs[-1],
                                "netlist_run_id": a["netlist_run_id"],
                                "post_hashes": a["post_hashes"].splitlines()[0].split()[0],
                                "check_power_errors": 0, "sdf_errors": 0,
                                "pt_diagnostic": "PT-063 Library Compiler path unset; check_power zero"})
        stream = a["modes"]["stream"]
        packets = {}
        for event in stream["events"]:
            if int(event["flit"]) in (1, 2, 3):
                packets.setdefault(int(event["packet"]), []).append(float(event["output_req_ns"]))
        intervals = [ts[i] - ts[i-1] for ts in packets.values() for i in range(1, len(ts))]
        assert len(intervals) >= 6 and all(x > 0 for x in intervals)
        service = statistics.fmean(intervals)
        power = stream["power"]
        assert power["dynamic_power_w"] is not None and power["leakage_power_w"] is not None
        router.append({"design": "Async c1p4" if kind.startswith("async") else "Sync c1p4",
                       "head_hop_latency_ns": a["modes"]["isolated"]["events"][0]["hop_latency_ns"],
                       "body_service_interval_ns": service, "max_flit_rate_Mflit_s": 1000/service,
                       "cell_area_um2": a["total_cell_area_um2"],
                       "energy_per_flit_pJ": power["energy_per_delivered_flit_j"] * 1e12,
                       "dynamic_power_mW": power["dynamic_power_w"] * 1e3,
                       "leakage_power_mW": power["leakage_power_w"] * 1e3,
                       "stream_delivered_flits": len(stream["events"]),
                       "stream_window_ns": stream["power_window_ns"]["duration"]})
    write_csv(RAW_ROOT / "router_summary.csv", tuple(router[0]), router)
    write_csv(RAW_ROOT / "router_run_job_hash.csv", tuple(router_jobs[0]), router_jobs)
    (RAW_ROOT / "router_ppa_summary.json").write_text(json.dumps(hop, indent=2) + "\n", encoding="utf-8")
    REGISTRY.mkdir(parents=True, exist_ok=True)
    record = {"run_id": "20260914_emergency_multicast_c1p4", "status": "exploratory_post_synthesis",
              "paper_eligible": False, "physical_class": "post-synthesis_MAXIMUM-SDF_PT-PX",
              "raw_dir": str(RAW_ROOT.relative_to(REPO)).replace("\\", "/"),
              "network_netlist": "20260913_prop_temp64_asap_uc_m5_200",
              "multicast_case_count": len(case_rows), "router_mode_count": len(router_jobs),
              "case_run_job_hash": "case_run_job_hash.csv",
              "router_run_job_hash": "router_run_job_hash.csv",
              "reason_not_eligible": ["Link traversals are a packet model estimate, not observed inter-router handshakes",
                                      "No zero-backlog F16/F32 fanout point in the current half-open window",
                                      "Low-load finite-window semantics require follow-up"],
              "failed_run": "20260914_cmr_prop_temp_c1p4_rpsdel050 (actual RCU DEL150; replaced by _r1)"}
    manifest_path = REGISTRY / "20260914_emergency_multicast_c1p4.json"
    manifest_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
    index_path = REGISTRY.parent / "index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    entry = {"run_id": record["run_id"], "design_id": "PROP_temp64",
             "benchmark_id": "MC-REGION-F16", "status": record["status"],
             "paper_eligible": False, "physical_class": record["physical_class"],
             "config_hash": sha(manifest_path), "manifest": str(manifest_path),
             "notes": "; ".join(record["reason_not_eligible"])}
    matches = [item for item in index["runs"] if item.get("run_id") == record["run_id"]]
    assert len(matches) <= 1
    if matches:
        matches[0].update(entry)
    else:
        index["runs"].append(entry)
    index_path.write_text(json.dumps(index, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("EMERGENCY_ARCHIVE_PASS", len(case_rows), "multicast", len(router_jobs), "router modes", RAW_ROOT)


if __name__ == "__main__":
    main()
