#!/usr/bin/env python3
"""Submit/collect multi-lane aggregate throughput: c1p1/c1p2/c1p4 (+ Sync c1p4).

Four child sources inject continuously toward parent; Selector picks physical
parent lanes.  Metric: T_agg = delivered_flits / measurement_span.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import os
import re
import shlex
import time
from pathlib import Path

from run_remote_cmr_flow import atomic_put_retry, job_id, remote_run, wait_job
from run_remote_cmr_noc16_sdf import connect


REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
HERE = Path(__file__).resolve().parent
BATCH = os.environ.get("CMR_MULTI_LANE_AGG_BATCH", "20260914_cmr_multi_lane_agg_r1")
PACKETS = int(os.environ.get("CMR_HOP_NUM_PACKETS", "1000"))
RX_ACK_NS = os.environ.get("CMR_RX_CAPTURE_NS", "0.09")
HOSTS = os.environ.get("CMR_DES_BSUB_EXTRA", '-m "node21 node26 node24 node18"')

CONFIGS = (
    {
        "name": "async_c1p1",
        "async": True,
        "kind": "async_thin_1x1",
        "netlist": "20260912_205700_cmr_thin_l1_hop_rpsdel050",
        "tb": "tb_cmr_router_multi_lane_agg.sv",
        "wrapper": "run_gls_cmr_router_hop_ppa.sh",
        "parent_lanes": 1,
    },
    {
        "name": "async_c1p2",
        "async": True,
        "kind": "async_fat_1x2",
        "netlist": "20260912_205700_cmr_fat_l1_hop_rpsdel050",
        "tb": "tb_cmr_router_multi_lane_agg.sv",
        "wrapper": "run_gls_cmr_router_hop_ppa.sh",
        "parent_lanes": 2,
    },
    {
        "name": "async_c1p4",
        "async": True,
        "kind": "async_fat_1x4",
        "netlist": "20260914_cmr_prop_temp_c1p4_rpsdel050_r1",
        "tb": "tb_cmr_router_multi_lane_agg.sv",
        "wrapper": "run_gls_cmr_router_hop_ppa.sh",
        "parent_lanes": 4,
    },
    {
        "name": "sync_c1p4",
        "async": False,
        "kind": "sync_fat_1x4",
        "netlist": "20260914_cmr_sync_prop_temp_c1p4_1p0ns",
        "tb": "tb_sync_cmr_router_multi_lane_agg.sv",
        "wrapper": "run_gls_cmr_sync_router_hop_ppa.sh",
        "parent_lanes": 4,
    },
)

LOCAL_TB = {
    "tb_cmr_router_multi_lane_agg.sv": HERE / "tb_cmr_router_multi_lane_agg.sv",
    "tb_sync_cmr_router_multi_lane_agg.sv": HERE / "tb_sync_cmr_router_multi_lane_agg.sv",
}
LOCAL_WRAPPER = {
    "run_gls_cmr_router_hop_ppa.sh": HERE / "run_gls_cmr_router_hop_ppa.sh",
    "run_gls_cmr_sync_router_hop_ppa.sh": HERE / "run_gls_cmr_sync_router_hop_ppa.sh",
}
BIND_DIR = HERE / "hop_binds"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def selected(names: list[str] | None) -> list[dict]:
    if not names:
        return list(CONFIGS)
    wanted = set(names)
    rows = [c for c in CONFIGS if c["name"] in wanted]
    missing = wanted - {c["name"] for c in rows}
    if missing:
        raise SystemExit("unknown configs: %s" % sorted(missing))
    return rows


def run_id_for(cfg: dict) -> str:
    return "%s_%s_p%d" % (BATCH, cfg["name"], PACKETS)


def local_out(cfg: dict) -> Path:
    return HERE / "results" / run_id_for(cfg)


def upload_file(client, sftp, local: Path, remote: str) -> None:
    existing = remote_run(client, f"sha256sum {shlex.quote(remote)} 2>/dev/null || true")
    if sha256(local) in existing:
        print("UPLOAD_SKIP_HASHED", remote, flush=True)
        return
    for attempt in range(5):
        client, sftp, digest = atomic_put_retry(client, sftp, local, remote)
        time.sleep(1)
        observed = remote_run(client, f"sha256sum {shlex.quote(remote)}")
        if digest in observed:
            print("UPLOAD_OK", remote, digest, flush=True)
            return
        print("UPLOAD_HASH_RETRY", local.name, attempt + 1, flush=True)
    raise RuntimeError("upload SHA mismatch: %s" % local.name)


def ensure_uploads(client, sftp, cfgs: list[dict]) -> None:
    remote_run(client, f"mkdir -p {shlex.quote(ROOT + '/sim/tb/hop_binds')}")
    tbs = {c["tb"] for c in cfgs}
    wraps = {c["wrapper"] for c in cfgs}
    for name in tbs:
        upload_file(client, sftp, LOCAL_TB[name], f"{ROOT}/sim/tb/{name}")
    for name in wraps:
        upload_file(client, sftp, LOCAL_WRAPPER[name], f"{ROOT}/sim/tb/{name}")
    for vi in BIND_DIR.glob("*.vi"):
        upload_file(client, sftp, vi, f"{ROOT}/sim/tb/hop_binds/{vi.name}")


def submit(cfgs: list[dict]) -> None:
    client = connect()
    sftp = client.open_sftp()
    jobs = []
    try:
        ensure_uploads(client, sftp, cfgs)
        for cfg in cfgs:
            rid = run_id_for(cfg)
            netlist = f"{ROOT}/outputs/{cfg['netlist']}"
            if cfg["async"]:
                arts = ("CMRRouter_post.v", "CMRRouter.sdf", "CMRRouter.ddc")
            else:
                arts = ("SyncCmrRouter_post.v", "SyncCmrRouter.sdf", "SyncCmrRouter.ddc")
            for name in arts:
                check = remote_run(client, f"test -s {shlex.quote(netlist + '/' + name)} && echo FOUND")
                if "FOUND" not in check:
                    raise RuntimeError("missing netlist artifact %s/%s" % (cfg["netlist"], name))
            remote_log = f"{ROOT}/logs/hop_ppa/{rid}/gls"
            existing = remote_run(client, f"test -e {shlex.quote(remote_log + '/run.log')} && echo EXISTS || true")
            if "EXISTS" in existing:
                print("SKIP_EXISTS", rid, flush=True)
                jobs.append({"name": cfg["name"], "run_id": rid, "job_id": None, "status": "exists"})
                continue
            remote_run(client, f"mkdir -p {shlex.quote(remote_log)}")
            remote_wrap = f"{ROOT}/sim/tb/{cfg['wrapper']}"
            if cfg["async"]:
                command = (
                    f"bsub -n 8 {HOSTS} -oo {shlex.quote(remote_log + '/lsf.log')} "
                    f"-J {shlex.quote('agg_' + cfg['name'])} "
                    f"env CMR_REMOTE_ROOT={shlex.quote(ROOT)} CMR_RUN_ID={shlex.quote(rid)} "
                    f"CMR_NETLIST_RUN_ID={shlex.quote(cfg['netlist'])} "
                    f"CMR_HOP_KIND={shlex.quote(cfg['kind'])} CMR_HOP_MODE=multi_lane_agg "
                    f"CMR_HOP_TB_NAME={shlex.quote(cfg['tb'])} CMR_HOP_NO_VCD=1 "
                    f"CMR_HOP_WORK_BASE=/tmp/cmr_hop_ppa_ghy19 "
                    f"CMR_RX_CAPTURE_NS={shlex.quote(RX_ACK_NS)} CMR_TX_SETUP_NS=0.05 "
                    f"CMR_ACK_TO_NEXT_REQ_GUARD_NS=0 CMR_HOP_NUM_PACKETS={PACKETS} CMR_HOP_NO_SDF=0 "
                    f"bash {shlex.quote(remote_wrap)}"
                )
            else:
                command = (
                    f"bsub -n 8 {HOSTS} -oo {shlex.quote(remote_log + '/lsf.log')} "
                    f"-J {shlex.quote('agg_' + cfg['name'])} "
                    f"env CMR_REMOTE_ROOT={shlex.quote(ROOT)} CMR_RUN_ID={shlex.quote(rid)} "
                    f"CMR_NETLIST_RUN_ID={shlex.quote(cfg['netlist'])} "
                    f"CMR_HOP_KIND={shlex.quote(cfg['kind'])} CMR_HOP_MODE=multi_lane_agg "
                    f"CMR_HOP_TB_NAME={shlex.quote(cfg['tb'])} "
                    f"CMR_HOP_NUM_PACKETS={PACKETS} CMR_SYNC64_CLOCK_PERIOD_NS=1.0 "
                    f"bash {shlex.quote(remote_wrap)}"
                )
            response = remote_run(client, command)
            jid = job_id(response)
            jobs.append({"name": cfg["name"], "run_id": rid, "job_id": jid, "status": "submitted"})
            print("JOB_SUBMIT", rid, jid, flush=True)
        out = HERE / "results" / (BATCH + "_jobs.json")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps({"batch": BATCH, "packets": PACKETS, "jobs": jobs}, indent=2) + "\n",
                       encoding="utf-8")
    finally:
        sftp.close()
        client.close()


def fetch_one(client, sftp, cfg: dict) -> dict:
    rid = run_id_for(cfg)
    local = local_out(cfg)
    local.mkdir(parents=True, exist_ok=True)
    remote_log = f"{ROOT}/logs/hop_ppa/{rid}/gls"
    for name in ("lsf.log", "compile.log", "run.log", "stdout.log",
                 "sdf_annotate.log", "hop_events.csv", "input_hashes.sha256"):
        try:
            sftp.get(f"{remote_log}/{name}", str(local / name))
        except OSError:
            print("FETCH_MISSING", rid, name, flush=True)
    run_path = local / "run.log"
    if not run_path.is_file():
        return {"name": cfg["name"], "run_id": rid, "status": "PENDING"}
    run = run_path.read_text(encoding="utf-8", errors="replace")
    sdf = (local / "sdf_annotate.log").read_text(encoding="utf-8", errors="replace") if (local / "sdf_annotate.log").is_file() else ""
    m = re.search(
        r"AGG_RESULT PASS .* throughput_gflit_s=([0-9.]+)",
        run,
    )
    ok = (
        "AGG_RESULT PASS" in run
        and "PPA_RESULT PASS" in run
        and bool(re.search(r"Total errors:\s*0\b", sdf))
        and not re.search(r"AGG_FAIL|PPA_RESULT FAIL|Timing violation|Fatal:", run)
    )
    row = {
        "name": cfg["name"],
        "run_id": rid,
        "async": cfg["async"],
        "parent_lanes": cfg["parent_lanes"],
        "packets_per_source": PACKETS,
        "status": "PASS" if ok else "FAIL",
        "throughput_gflit_s": float(m.group(1)) if m else None,
    }
    print("AGG_STATUS", rid, row["status"], row["throughput_gflit_s"], flush=True)
    return row


def collect(cfgs: list[dict], wait: bool) -> None:
    client = connect()
    sftp = client.open_sftp()
    rows = []
    try:
        jobs_path = HERE / "results" / (BATCH + "_jobs.json")
        job_map = {}
        if jobs_path.is_file():
            for job in json.loads(jobs_path.read_text(encoding="utf-8"))["jobs"]:
                job_map[job["name"]] = job.get("job_id")
        if wait:
            for cfg in cfgs:
                jid = job_map.get(cfg["name"])
                if jid:
                    wait_job(client, jid, run_id_for(cfg), polls=240)
        for cfg in cfgs:
            rows.append(fetch_one(client, sftp, cfg))
    finally:
        sftp.close()
        client.close()
    summarize_rows(rows)


def summarize_rows(rows: list[dict]) -> None:
    by_name = {r["name"]: r for r in rows}
    out_dir = HERE / "results" / BATCH
    out_dir.mkdir(parents=True, exist_ok=True)
    csv_path = out_dir / "aggregate_throughput.csv"
    with csv_path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=["name", "run_id", "async", "parent_lanes", "packets_per_source",
                        "status", "throughput_gflit_s"],
        )
        writer.writeheader()
        writer.writerows(rows)
    t1 = by_name.get("async_c1p1", {}).get("throughput_gflit_s")
    t2 = by_name.get("async_c1p2", {}).get("throughput_gflit_s")
    t4 = by_name.get("async_c1p4", {}).get("throughput_gflit_s")
    ts = by_name.get("sync_c1p4", {}).get("throughput_gflit_s")
    summary = {
        "batch": BATCH,
        "packets_per_source": PACKETS,
        "rows": rows,
        "c1p1_gflit_s": t1,
        "c1p2_gflit_s": t2,
        "c1p4_gflit_s": t4,
        "sync_c1p4_gflit_s": ts,
    }
    if t1 and t4:
        summary["four_lane_scaling_efficiency_pct"] = 100.0 * t4 / (4.0 * t1)
    if t4 and ts:
        summary["async_vs_sync_improvement_pct"] = 100.0 * (t4 / ts - 1.0)
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print("AGG_SUMMARY", json.dumps(summary, indent=2), flush=True)


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=("submit", "collect", "all"))
    p.add_argument("--config", action="append", choices=[c["name"] for c in CONFIGS])
    p.add_argument("--no-wait", action="store_true")
    args = p.parse_args()
    cfgs = selected(args.config)
    if args.action in ("submit", "all"):
        submit(cfgs)
    if args.action in ("collect", "all"):
        collect(cfgs, wait=not args.no_wait)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
