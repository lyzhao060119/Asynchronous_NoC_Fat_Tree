#!/usr/bin/env python3
"""DATE V3 Phase 2: emit, geometry, DC, R-U5 MAXIMUM-SDF, PT-PX.  No P&R.

Reuses frozen 20260830 Thin/Fat/PROP hop netlists.  New run IDs are used for
PFAT, TopMesh, FlatMesh, and isolated Sync routers.
"""
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

from cmr_primitive_geometries import HOP_PPA_RUN_ID, all_primitives, lookup
from cmr_frozen_run_ids import refuse_overwrite


HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
SBT = os.environ.get("SBT_CMD", "sbt.bat" if os.name == "nt" else "sbt")
EXP_SCRIPTS = REPO / "DATE paper" / "experiments" / "scripts"
if str(EXP_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(EXP_SCRIPTS))


def delay_env(base: dict[str, str] | None = None) -> dict[str, str]:
    env = (base or os.environ).copy()
    env["PYTHONUNBUFFERED"] = "1"
    env["ASYNC_PRIMITIVES"] = "asic"
    env["CMR_SKIP_LOCAL_SMOKE"] = "1"
    env["CMR_RCU_MATCHED_DELAY_STEPS"] = "1"
    env["CMR_RCU_MATCHED_DELAY_UNIT_PS"] = "50"
    env["CMR_RCU_MATCHED_BUF_STAGES"] = "0"
    env["CMR_OPM_ACKIN_DELAY_STEPS"] = "1"
    env["CMR_OPM_ACKIN_DELAY_UNIT_PS"] = "50"
    env["CMR_LANE01_BUF_STAGES"] = "0"
    env["CMR_SKIP_EMIT"] = "1"
    env["CMR_DC_ONLY"] = "1"
    env["CMR_HOP_SDF_ONLY"] = "1"
    env.setdefault("CMR_JOB_POLLS", "720")
    env.pop("CMR_DC_SEED_RUN_ID", None)
    env.pop("CMR_OPM_ACKIN_USE_BUF", None)
    return env


def run(cmd: list[str], *, env: dict[str, str] | None = None, cwd: Path | None = None) -> None:
    print("RUN", " ".join(cmd), flush=True)
    subprocess.check_call(cmd, cwd=cwd or REPO, env=env or os.environ.copy())


def local_emit_and_check() -> None:
    emit_env = delay_env()
    emit_env.pop("CMR_SKIP_EMIT", None)
    run([sys.executable, str(HERE / "gen_cmr_hop_dut_bind.py")])
    run([SBT, "runMain", "Router_Architecture.CMR.CMRPrimitiveMatrixEmitMain"], env=emit_env)
    run(
        [SBT, "runMain", "Router_Architecture.sync_cmr.SyncCmrPrimitiveMatrixEmitMain"],
        env=emit_env,
    )
    run(
        [
            sys.executable,
            str(HERE / "check_cmr_router_geometry.py"),
            "--root",
            str(REPO / "generated_cmr"),
        ]
    )
    run(
        [
            sys.executable,
            str(HERE / "check_cmr_router_geometry.py"),
            "--sync",
            "--sync-root",
            str(REPO / "generated_sync_cmr"),
        ]
    )
    if os.environ.get("CMR_SKIP_MESH_TEST", "0") != "1":
        run(
            [
                SBT,
                "testOnly",
                "Router_Architecture.algorithm.RoutingLogicMeshSpec",
                "Router_Architecture.CMR.CMRTopMeshGeometrySpec",
            ]
        )


def dc_one(geom: dict) -> None:
    refuse_overwrite(geom["dc_id"], action="dc")
    env = delay_env()
    env["CMR_RUN_ID"] = geom["dc_id"]
    env["CMR_SYNC_ROUTER_RUN_ID"] = geom["dc_id"]
    env["CMR_HOP_KIND"] = geom["kind"]
    env["CMR_ROUTER_LEVEL"] = str(geom["level"])
    env["CMR_CHILD_LANES"] = str(geom["child"])
    env["CMR_PARENT_LANES"] = str(geom["parent"])
    env["CMR_USE_MESH_ROUTING"] = "1" if geom["mesh"] else "0"
    env["CMR_JOB_POLLS"] = os.environ.get(
        "CMR_JOB_POLLS", "960" if geom["ports"] >= 24 else "720"
    )
    script = HERE / (
        "run_remote_cmr_sync_router.py" if not geom["async"] else "run_remote_cmr_flow.py"
    )
    print(
        "PRIMITIVE_DC kind=%s run=%s async=%s mesh=%s ports=%s"
        % (geom["kind"], geom["dc_id"], geom["async"], geom["mesh"], geom["ports"]),
        flush=True,
    )
    run([sys.executable, "-u", str(script)], env=env)


def hop_ppa() -> None:
    refuse_overwrite(HOP_PPA_RUN_ID, action="hop-ppa-results")
    env = delay_env()
    env.pop("CMR_DC_ONLY", None)
    env["CMR_HOP_PPA_RUN_ID"] = os.environ.get("CMR_HOP_PPA_RUN_ID", HOP_PPA_RUN_ID)
    env["CMR_HOP_KINDS"] = os.environ.get(
        "CMR_HOP_KINDS", ",".join(g["kind"] for g in all_primitives())
    )
    env["CMR_HOP_MODES"] = os.environ.get(
        "CMR_HOP_MODES", "isolated,stream,idle,contention"
    )
    for geom in all_primitives():
        for name in geom["netlist_envs"]:
            env.setdefault(name, geom["dc_id"])
    print("PRIMITIVE_HOP_PPA", env["CMR_HOP_PPA_RUN_ID"], env["CMR_HOP_KINDS"], flush=True)
    run([sys.executable, "-u", str(HERE / "run_remote_cmr_router_hop_ppa.py")], env=env)


def write_registry() -> None:
    from date_v3.hashutil import load_json, sha256_file, sha256_json
    from date_v3.manifest import new_manifest, save_manifest
    from date_v3.paths import DESIGNS
    from date_v3.registry import upsert_run

    hop_dir = REPO / "scripts" / "asic_dc" / "cmr" / "results" / HOP_PPA_RUN_ID
    metrics = hop_dir / "metrics.csv"
    calibration = hop_dir / "calibration.json"
    summary = hop_dir / "summary.json"
    if not metrics.is_file() or not summary.is_file():
        raise SystemExit("missing hop PPA metrics under %s" % hop_dir)
    cal = load_json(calibration) if calibration.is_file() else {}
    by_kind = {row["kind"]: row for row in cal.get("primitives") or []}
    for geom in all_primitives():
        if geom.get("reuse_dc_id"):
            continue
        design_path = DESIGNS / ("%s.json" % geom["design_id"].lower())
        design = load_json(design_path) if design_path.is_file() else {}
        local_dc = REPO / "scripts" / "asic_dc" / "cmr" / "results" / geom["dc_id"]
        hashes = local_dc / "reports_dc" / "post_hashes.sha256"
        netlist_hash = None
        if hashes.is_file():
            first = hashes.read_text(encoding="utf-8", errors="replace").splitlines()
            if first:
                netlist_hash = first[0].split()[0]
        row = by_kind.get(geom["kind"]) or {}
        manifest = new_manifest(
            run_id=geom["dc_id"],
            status="pass",
            design_id=geom["design_id"],
            benchmark_id="R-U5",
            adapter="dc_sync_router" if not geom["async"] else "dc_cmr_router",
            config_hash=sha256_json(design) if design else None,
            netlist_hash=netlist_hash,
            frozen_structure_ok=True,
            paper_eligible=True,
            physical_class="post-synthesis",
            artifacts={
                "local_dc": str(local_dc).replace("\\", "/"),
                "hop_ppa": str(hop_dir).replace("\\", "/"),
                "metrics_csv": str(metrics).replace("\\", "/"),
                "kind": geom["kind"],
                "area_um2": row.get("total_cell_area_um2"),
                "head_ns": row.get("head_ns"),
                "max_opm_fanin": geom["max_opm_fanin"],
            },
            notes="DATE V3 Phase 2 post-synthesis primitive DC + R-U5 hop PPA. No P&R.",
        )
        save_manifest(manifest)
        upsert_run(manifest)
        print("REGISTRY", manifest["run_id"], geom["kind"], flush=True)
    hop_manifest = new_manifest(
        run_id=HOP_PPA_RUN_ID,
        status="pass",
        design_id="ASYNC_THIN_1X1",
        benchmark_id="R-U5",
        adapter="hop_ppa",
        config_hash=sha256_file(metrics),
        frozen_structure_ok=True,
        paper_eligible=True,
        physical_class="post-synthesis",
        artifacts={
            "metrics_csv": str(metrics).replace("\\", "/"),
            "calibration_json": str(calibration).replace("\\", "/"),
            "summary_json": str(summary).replace("\\", "/"),
            "kinds": [g["kind"] for g in all_primitives()],
        },
        notes=(
            "DATE V3 Phase 2 R-U5 MAXIMUM-SDF + PT-PX for all Router primitives. "
            "Area is DC cell area. No P&R."
        ),
    )
    save_manifest(hop_manifest)
    upsert_run(hop_manifest)
    print("REGISTRY", HOP_PPA_RUN_ID, flush=True)
    cal_dir = REPO / "DATE paper" / "experiments" / "model" / "calibration"
    cal_dir.mkdir(parents=True, exist_ok=True)
    if calibration.is_file():
        target = cal_dir / "20260831_primitive_ru5_post_synthesis.json"
        target.write_text(calibration.read_text(encoding="utf-8"), encoding="utf-8")
        print("CALIBRATION", target, flush=True)


def freeze_new_run_ids() -> None:
    path = HERE / "cmr_frozen_run_ids.py"
    text = path.read_text(encoding="utf-8")
    new_ids = [row["dc_id"] for row in all_primitives() if not row.get("reuse_dc_id")]
    new_ids.append(HOP_PPA_RUN_ID)
    if all(run_id in text for run_id in new_ids):
        return
    marker = "FROZEN_WRITE_RUN_IDS = FROZEN_HOP_NETLIST_RUN_IDS | {"
    if marker not in text:
        print("WARN could not freeze new run IDs in cmr_frozen_run_ids.py", flush=True)
        return
    extra = "".join('    "%s",\n' % run_id for run_id in new_ids)
    text = text.replace(marker, marker + "\n" + extra.rstrip() + "\n", 1)
    path.write_text(text, encoding="utf-8")
    print("FROZE", ",".join(new_ids), flush=True)


def main() -> None:
    skip_emit = os.environ.get("CMR_MATRIX_SKIP_EMIT", "0") == "1"
    skip_dc = os.environ.get("CMR_MATRIX_SKIP_DC", "0") == "1"
    skip_hop = os.environ.get("CMR_MATRIX_SKIP_HOP", "0") == "1"
    only = [
        name.strip()
        for name in os.environ.get("CMR_MATRIX_ONLY", "").split(",")
        if name.strip()
    ]
    geoms = all_primitives()
    if only:
        geoms = [lookup(name) for name in only]
    if not skip_emit:
        local_emit_and_check()
    if not skip_dc:
        jobs = []
        for geom in geoms:
            if geom.get("reuse_dc_id"):
                print("PRIMITIVE_REUSE_DC", geom["kind"], geom["dc_id"], flush=True)
                continue
            if os.environ.get("CMR_MATRIX_PARALLEL", "1") == "1":
                env = delay_env()
                env["CMR_RUN_ID"] = geom["dc_id"]
                env["CMR_SYNC_ROUTER_RUN_ID"] = geom["dc_id"]
                env["CMR_HOP_KIND"] = geom["kind"]
                env["CMR_ROUTER_LEVEL"] = str(geom["level"])
                env["CMR_CHILD_LANES"] = str(geom["child"])
                env["CMR_PARENT_LANES"] = str(geom["parent"])
                env["CMR_USE_MESH_ROUTING"] = "1" if geom["mesh"] else "0"
                env["CMR_JOB_POLLS"] = os.environ.get(
                    "CMR_JOB_POLLS", "960" if geom["ports"] >= 24 else "720"
                )
                script = HERE / (
                    "run_remote_cmr_sync_router.py"
                    if not geom["async"]
                    else "run_remote_cmr_flow.py"
                )
                print("PRIMITIVE_DC_START", geom["kind"], geom["dc_id"], flush=True)
                jobs.append(
                    (
                        geom,
                        subprocess.Popen(
                            [sys.executable, "-u", str(script)],
                            cwd=REPO,
                            env=env,
                        ),
                    )
                )
            else:
                dc_one(geom)
        failures = []
        for geom, proc in jobs:
            code = proc.wait()
            print("PRIMITIVE_DC_DONE", geom["kind"], geom["dc_id"], "code", code, flush=True)
            if code != 0:
                failures.append(geom["kind"])
        if failures:
            raise SystemExit("DC failed for %s" % ",".join(failures))
    if not skip_hop:
        hop_ppa()
        write_registry()
        freeze_new_run_ids()
    print("PRIMITIVE_MATRIX_PASS", flush=True)


if __name__ == "__main__":
    main()
