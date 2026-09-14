#!/usr/bin/env python3
"""Run a 10,000-packet full-drain c1p4 MAXIMUM-SDF throughput experiment."""
from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import shlex
import time
from datetime import datetime, timezone
from pathlib import Path

from run_remote_cmr_flow import atomic_put_retry, job_id, remote_run, wait_job
from run_remote_cmr_noc16_sdf import connect


REPO = Path(__file__).resolve().parents[3]
ROOT = "/home/ghy19/Asynchronous_Router_CMR"
RUN_ID = os.environ.get("CMR_C1P4_SUSTAINED_RUN_ID", "20260914_cmr_c1p4_sustained_10000pkt_04")
RX_ACK_NS = os.environ.get("CMR_C1P4_RX_ACK_NS", "0.09")
NETLIST_ID = "20260914_cmr_prop_temp_c1p4_rpsdel050_r1"
LOCAL_OUT = REPO / "scripts/asic_dc/cmr/results" / RUN_ID
TB = REPO / "scripts/asic_dc/cmr/tb_cmr_router_c1p4_sustained.sv"
WRAPPER = REPO / "scripts/asic_dc/cmr/run_gls_cmr_router_hop_ppa.sh"
REMOTE_TB = f"{ROOT}/sim/tb/{TB.name}"
REMOTE_WRAPPER = f"{ROOT}/sim/tb/run_gls_cmr_router_c1p4_sustained.sh"
REMOTE_LOG = f"{ROOT}/logs/hop_ppa/{RUN_ID}/gls"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes().replace(b"\r\n", b"\n")).hexdigest()


def main() -> None:
    LOCAL_OUT.mkdir(parents=True, exist_ok=True)
    client = connect()
    sftp = client.open_sftp()
    jid = None
    try:
        netlist = f"{ROOT}/outputs/{NETLIST_ID}"
        for name in ("CMRRouter_post.v", "CMRRouter.sdf", "CMRRouter.ddc"):
            result = remote_run(client, f"test -s {shlex.quote(netlist + '/' + name)} && echo FOUND_{name}")
            if f"FOUND_{name}" not in result:
                raise RuntimeError(f"missing frozen netlist artifact: {name}")
        existing = remote_run(client, f"test -e {shlex.quote(REMOTE_LOG + '/run.log')} && echo ALREADY_EXISTS || true")
        if "ALREADY_EXISTS" in existing:
            raise RuntimeError(f"run ID already exists: {RUN_ID}")
        for local, remote in ((TB, REMOTE_TB), (WRAPPER, REMOTE_WRAPPER)):
            existing_hash = remote_run(client, f"sha256sum {shlex.quote(remote)} 2>/dev/null")
            if sha256(local) in existing_hash:
                print("UPLOAD_SKIP_HASHED", remote, flush=True)
                continue
            for attempt in range(5):
                client, sftp, digest = atomic_put_retry(client, sftp, local, remote)
                time.sleep(2)
                observed = remote_run(client, f"sha256sum {shlex.quote(remote)}")
                if digest in observed:
                    print("UPLOAD_OK", remote, digest, flush=True)
                    break
                print("UPLOAD_HASH_RETRY", local.name, attempt + 1, flush=True)
            else:
                raise RuntimeError(f"upload SHA-256 mismatch after retries: {local.name}: {observed}")
        remote_run(client, f"mkdir -p {shlex.quote(REMOTE_LOG)}")
        hash_text = remote_run(
            client,
            "sha256sum " + " ".join(shlex.quote(f"{netlist}/{name}") for name in
                                      ("CMRRouter_post.v", "CMRRouter.sdf", "CMRRouter.ddc")),
        )
        command = (
            f"bsub -n 8 -oo {shlex.quote(REMOTE_LOG + '/lsf.log')} "
            f"env CMR_REMOTE_ROOT={shlex.quote(ROOT)} CMR_RUN_ID={shlex.quote(RUN_ID)} "
            f"CMR_NETLIST_RUN_ID={shlex.quote(NETLIST_ID)} CMR_HOP_KIND=async_fat_1x4 "
            f"CMR_HOP_MODE=sustained CMR_HOP_TB_NAME={TB.name} CMR_HOP_NO_VCD=1 "
            f"CMR_HOP_WORK_BASE=/tmp/cmr_hop_ppa_ghy19 "
            f"CMR_RX_CAPTURE_NS={shlex.quote(RX_ACK_NS)} CMR_TX_SETUP_NS=0.05 "
            f"CMR_ACK_TO_NEXT_REQ_GUARD_NS=0 CMR_HOP_NUM_PACKETS=10000 CMR_HOP_NO_SDF=0 "
            f"bash {shlex.quote(REMOTE_WRAPPER)}"
        )
        response = remote_run(client, command)
        jid = job_id(response)
        print("JOB_SUBMIT", RUN_ID, jid, flush=True)
        try:
            wait_job(client, jid, RUN_ID, polls=240)
        finally:
            for name in ("lsf.log", "compile.log", "run.log", "stdout.log",
                         "sdf_annotate.log", "hop_events.csv", "input_hashes.sha256"):
                try:
                    sftp.get(f"{REMOTE_LOG}/{name}", str(LOCAL_OUT / name))
                except OSError:
                    print("FETCH_MISSING", name, flush=True)
        run = (LOCAL_OUT / "run.log").read_text(encoding="utf-8", errors="replace")
        sdf = (LOCAL_OUT / "sdf_annotate.log").read_text(encoding="utf-8", errors="replace")
        compile_log = (LOCAL_OUT / "compile.log").read_text(encoding="utf-8", errors="replace")
        if not re.search(r"SUSTAINED_RESULT PASS packets=10000 sent=50000 received=50000", run):
            raise RuntimeError("missing full-drain pass marker; see run.log")
        if "PPA_RESULT PASS" not in run or re.search(r"SUSTAINED_FAIL|PPA_RESULT FAIL|Timing violation|Fatal:", run):
            raise RuntimeError("protocol or timing failure; see run.log")
        if not re.search(r"Total errors:\s*0\b", sdf) or re.search(r"Total errors:\s*[1-9]", sdf):
            raise RuntimeError("MAXIMUM-SDF annotation failed; see sdf_annotate.log")
        if re.search(r"Error-\[|Compilation failed", compile_log):
            raise RuntimeError("VCS compilation failed; see compile.log")
        with (LOCAL_OUT / "hop_events.csv").open(newline="", encoding="utf-8") as handle:
            rows = list(csv.DictReader(handle))
        if len(rows) != 1:
            raise RuntimeError("expected one summary CSV row")
        row = rows[0]
        if any(int(row[name]) != count for name, count in
               (("packets", 10000), ("sent_flits", 50000),
                ("received_flits", 50000), ("failures", 0))):
            raise RuntimeError("CSV count mismatch")
        span_ns = (int(row["last_output_req_ps"]) - int(row["first_output_req_ps"])) / 1000.0
        throughput = 1000.0 * 50000 / span_ns
        if abs(float(row["span_ns"]) - span_ns) > 1e-6 or abs(float(row["throughput_mflit_s"]) - throughput) > 1e-5:
            raise RuntimeError("CSV throughput arithmetic mismatch")
        manifest = {
            "run_id": RUN_ID,
            "job_id": jid,
            "netlist_run_id": NETLIST_ID,
            "generated_at_utc": datetime.now(timezone.utc).isoformat(),
            "input_sha256": {"testbench": sha256(TB), "wrapper": sha256(WRAPPER)},
            "remote_netlist_sha256_output": hash_text,
            "sdf_mode": "MAXIMUM",
            "input_port": 0,
            "output_port": 7,
            "downstream_ack_delay_ns": float(RX_ACK_NS),
            "per_flit_setup_ns": 0.05,
            "packet_boundary_extra_gap_ns": 0,
            "full_drain": True,
            "result": row,
        }
        (LOCAL_OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print("C1P4_SUSTAINED_GLS_PASS", RUN_ID, jid, f"{throughput:.6f}", "Mflit/s", flush=True)
    finally:
        sftp.close()
        client.close()


if __name__ == "__main__":
    main()
