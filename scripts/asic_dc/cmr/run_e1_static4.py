#!/usr/bin/env python3
"""Launch DATE 2027 E1 Static4 RTL validation without synthesis."""
from __future__ import annotations

import base64
import argparse
import hashlib
import json
import os
import re
import shlex
import sys
import tarfile
import time
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
sys.path.insert(0, str(HERE))

import run_remote_prop_temp64 as prop_remote  # noqa: E402
from run_remote_prop_temp64 import remote, upload  # noqa: E402
from run_remote_cmr_fat_tree_noc16_sdf import connect, job_id  # noqa: E402

GEN = REPO / "generated_cmr" / "router_l1_c1_p4_static4"
TB = HERE / "tb_cmr_router_multi_lane_agg.sv"
BIND = HERE / "hop_binds" / "async_ports_c1_p4.vi"
WRAPPER = HERE / "run_e1_static4_rtl.sh"
PRJTEMP = "/prjtemp/ghy19/date2027_e1"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def structural_gate() -> list[Path]:
    top = GEN / "CMRRouter.v"
    if not top.is_file():
        raise SystemExit("emit Static4 RTL before launching")
    text = top.read_text(encoding="utf-8", errors="replace")
    required = (
        "laneSelect = InputPortModules_0_io_PathEnabled_3 ? 4'h1 : 4'h0",
        "laneSelect_1 = InputPortModules_1_io_PathEnabled_3 ? 4'h2 : 4'h0",
        "laneSelect_2 = InputPortModules_2_io_PathEnabled_3 ? 4'h4 : 4'h0",
        "laneSelect_3 = InputPortModules_3_io_PathEnabled_3 ? 4'h8 : 4'h0",
    )
    if any(marker not in text for marker in required):
        raise SystemExit("Static4 fixed input-to-lane mapping gate failed")
    if len(re.findall(r"LanePhaseAdapterDFF\s*#\(\.LANES\(4\)\)", text)) != 4:
        raise SystemExit("Static4 must retain four c1p4 phase adapters")
    if re.search(r"LaneSelector\s*#\(\.LANES\(4\)\)", text):
        raise SystemExit("Static4 unexpectedly retained availability selector")
    for lane in range(4):
        for direction in ("inputs", "outputs"):
            if f"io_{direction}_parent_{lane}_HS_Req" not in text:
                raise SystemExit("Static4 lost a physical parent lane")
    files = [top]
    for raw in (GEN / "firrtl_black_box_resource_files.f").read_text().splitlines():
        path = Path(raw.strip())
        if path.name and path.name not in {p.name for p in files}:
            files.append(GEN / path.name)
    for path in (*files, TB, BIND, WRAPPER):
        if not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f"missing/empty E1 input: {path}")
    print(f"E1_STATIC4_STRUCTURE_PASS rtl_files={len(files)} parent_lanes=4 adapters=4 mapping=0,1,2,3", flush=True)
    return files


def wait(client, jid: str, root: str, stage: str, marker: str):
    for index in range(180):
        client, out = remote(client, f"bjobs -a {jid} -noheader -o 'jobid stat job_name exec_host' 2>/dev/null || true; tail -n 8 {root}/logs/{stage}/stage.log 2>/dev/null || true; test -s {root}/logs/{stage}/run.log && echo E1_RUN_LOG_NONZERO || true")
        compact = " | ".join(line.strip() for line in out.splitlines() if line.strip() and "ModuleCmd_Load" not in line)
        print(f"E1_POLL {index} {compact}", flush=True)
        if re.search(rf"(?m)^{jid}\s+EXIT\b", out):
            raise RuntimeError(f"E1 {stage} job EXIT")
        if re.search(rf"(?m)^{jid}\s+DONE\b", out):
            if marker not in out or "E1_RUN_LOG_NONZERO" not in out:
                raise RuntimeError(f"E1 {stage} DONE without acceptance marker")
            return client
        time.sleep(10)
    raise RuntimeError(f"E1 {stage} timed out")


def show_status(client, run_id: str):
    root = f"{PRJTEMP}/{run_id}"
    client, out = remote(client, f"""
echo E1_STATUS_ROOT={root}
bjobs -a -J 'e1*' -noheader -o 'jobid stat job_name exec_host' 2>/dev/null | tail -20 || true
for stage in compile-smoke full; do
  echo E1_STAGE=$stage
  ls -lh {root}/logs/$stage/stage.log {root}/logs/$stage/run.log {root}/logs/$stage/aggregate.csv {root}/$stage.lsf {root}/$stage.err 2>/dev/null || true
  tail -n 12 {root}/logs/$stage/stage.log 2>/dev/null || true
  grep -E 'AGG_(RESULT|LANE)|PPA_RESULT|Fatal:|ERROR:' {root}/logs/$stage/run.log 2>/dev/null | tail -12 || true
  tail -n 12 {root}/$stage.err 2>/dev/null || true
done
""")
    print(out, flush=True)
    return client


def dynamic_preflight(client):
    netlist = "20260914_cmr_prop_temp_c1p4_rpsdel050_r1"
    base = f"/home/ghy19/Asynchronous_Router_CMR/outputs/{netlist}"
    client, out = remote(client, f"""
set -e
stat -c 'SIZE:%s:%n' {base}/CMRRouter.ddc {base}/CMRRouter_post.v {base}/CMRRouter.sdf
sha256sum {base}/CMRRouter.ddc {base}/CMRRouter_post.v {base}/CMRRouter.sdf
grep -E '^CMR_DC_PASS' /home/ghy19/Asynchronous_Router_CMR/logs/dc/{netlist}.log | tail -1
""")
    expected = (
        "f92f29ba6db2757b568328f06b307a8d6db4b3e9dac937c11f175c87f2cdc999",
        "3f1e48e8f986b0aa165a34b44204f222080c1bf0d6bec4c0013723ddac46c64f",
        "fbc006267ca0fb9e32bc69d460aae1e2c48cab12562cec230c2691b45d07b4c9",
    )
    if not all(value in out for value in expected) or "CMR_DC_PASS" not in out:
        raise RuntimeError("Dynamic-c1p4 frozen-netlist preflight failed")
    print(out, flush=True)
    print(f"E1_DYNAMIC_FROZEN_PASS netlist={netlist}", flush=True)
    return client


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", choices=("launch", "status", "resume-full", "dynamic-preflight"), default="launch")
    parser.add_argument("--run-id")
    args = parser.parse_args()
    if args.action in ("status", "resume-full") and not args.run_id:
        raise SystemExit("--run-id is required for status/resume-full")
    host = os.environ.get("E1_LOGIN_HOST", "192.168.2.9")
    os.environ["C1_HOST"] = host
    prop_remote.LOGIN_HOSTS = (host,)
    if args.action == "status":
        client = connect(attempts=2)
        try:
            show_status(client, args.run_id)
        finally:
            client.close()
        return 0
    if args.action == "dynamic-preflight":
        client = connect(attempts=2)
        try:
            dynamic_preflight(client)
        finally:
            client.close()
        return 0
    if args.action == "resume-full":
        run_id = args.run_id
        local = HERE / "results" / run_id
        state = json.loads((local / "state.json").read_text(encoding="utf-8"))
        root = state["remote_root"]
        client = connect(attempts=2)
        try:
            client = wait(client, state["smoke_job"], root, "compile-smoke", "E1_STATIC4_RTL_SMOKE_PASS")
            cmd = f"env E1_REMOTE_ROOT={root} E1_RUN_ID={run_id} bash {root}/run_e1_static4_rtl.sh full"
            client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24' -o {root}/full.lsf -e {root}/full.err -J e1f_{run_id[-10:]} {cmd}")
            full = job_id(out)
            state["full_job"] = full
            state["stage"] = "rtl_full_submitted"
            (local / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
            print(f"E1_STATIC4_FULL_SUBMITTED run={run_id} job={full}", flush=True)
            client = wait(client, full, root, "full", "E1_STATIC4_RTL_FULL_PASS")
            state["stage"] = "rtl_full_pass"
            (local / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
            print(f"E1_STATIC4_RTL_PASS run={run_id} smoke_job={state['smoke_job']} full_job={full}", flush=True)
        finally:
            client.close()
        return 0
    rtl_files = structural_gate()
    run_id = datetime.now().strftime("%Y%m%d_%H%M%S") + "_date2027_e1_static4_rtl"
    local = HERE / "results" / run_id
    local.mkdir(parents=True, exist_ok=False)
    bundle = local / "e1_static4_rtl.tar.gz"
    with tarfile.open(bundle, "w:gz") as archive:
        for path in rtl_files:
            archive.add(path, arcname=f"rtl/{path.name}")
        archive.add(TB, arcname="src/tb_cmr_router_multi_lane_agg.sv")
        archive.add(BIND, arcname="src/async_ports_c1_p4.vi")
        archive.add(WRAPPER, arcname="run_e1_static4_rtl.sh")
    encoded = local / "e1_static4_rtl.tar.gz.b64"
    encoded.write_bytes(base64.b64encode(bundle.read_bytes()))
    root = f"{PRJTEMP}/{run_id}"
    client = connect(attempts=2)
    state = {"run_id": run_id, "remote_root": root, "created_utc": datetime.now(timezone.utc).isoformat(), "evidence": "RTL simulation only; no DC/SDF", "input_hashes": {str(p.relative_to(REPO)): sha256(p) for p in (*rtl_files, TB, BIND, WRAPPER)}}
    try:
        client, exists = remote(client, f"test -e {shlex.quote(root)} && echo EXISTS || echo NEW")
        if "EXISTS" in exists:
            raise RuntimeError("refusing to overwrite E1 run directory")
        client, _ = remote(client, f"mkdir -p {root}")
        client = upload(client, encoded, f"{root}/e1_static4_rtl.tar.gz.b64")
        digest = sha256(bundle)
        client, out = remote(client, f"set -e; base64 --decode {root}/e1_static4_rtl.tar.gz.b64 > {root}/e1_static4_rtl.tar.gz; echo {digest} ' {root}/e1_static4_rtl.tar.gz' | sha256sum --check; tar -tzf {root}/e1_static4_rtl.tar.gz >/dev/null; tar -xzf {root}/e1_static4_rtl.tar.gz -C {root}; bash -n {root}/run_e1_static4_rtl.sh; chmod +x {root}/run_e1_static4_rtl.sh")
        if f"{root}/e1_static4_rtl.tar.gz: OK" not in out:
            raise RuntimeError("E1 archive SHA gate failed")
        cmd = f"env E1_REMOTE_ROOT={root} E1_RUN_ID={run_id} bash {root}/run_e1_static4_rtl.sh compile-smoke"
        client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24' -o {root}/compile_smoke.lsf -e {root}/compile_smoke.err -J e1s_{run_id[-10:]} {cmd}")
        smoke = job_id(out)
        state["smoke_job"] = smoke
        (local / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"E1_STATIC4_SMOKE_SUBMITTED run={run_id} job={smoke}", flush=True)
        client = wait(client, smoke, root, "compile-smoke", "E1_STATIC4_RTL_SMOKE_PASS")
        cmd = f"env E1_REMOTE_ROOT={root} E1_RUN_ID={run_id} bash {root}/run_e1_static4_rtl.sh full"
        client, out = remote(client, f"bsub -n 8 -m 'node21 node26 node24' -o {root}/full.lsf -e {root}/full.err -J e1f_{run_id[-10:]} {cmd}")
        full = job_id(out)
        state["full_job"] = full
        state["stage"] = "rtl_full_submitted"
        (local / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"E1_STATIC4_FULL_SUBMITTED run={run_id} job={full}", flush=True)
        client = wait(client, full, root, "full", "E1_STATIC4_RTL_FULL_PASS")
        state["stage"] = "rtl_full_pass"
        (local / "state.json").write_text(json.dumps(state, indent=2) + "\n", encoding="utf-8")
        print(f"E1_STATIC4_RTL_PASS run={run_id} smoke_job={smoke} full_job={full}", flush=True)
    finally:
        client.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
