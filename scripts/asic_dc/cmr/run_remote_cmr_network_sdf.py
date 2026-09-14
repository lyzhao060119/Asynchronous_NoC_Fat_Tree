#!/usr/bin/env python3
"""V3.1.0 whole-network logic synthesis and maximum-delay gate simulation.

CMR_NETWORK_DESIGN_ID selects the independent netlist owner. Shared-netlist
designs (boundary packet-replication, two-lane alias) reuse that owner.
Unsupported four-lane top mesh is refused. Dry-run with --check-inputs does
not submit LSF jobs.
"""
from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
EXPERIMENT_SCRIPTS = REPO / "DATE paper" / "experiments" / "scripts"
if str(EXPERIMENT_SCRIPTS) not in sys.path:
    sys.path.insert(0, str(EXPERIMENT_SCRIPTS))
CMR = Path(__file__).resolve().parent
if str(CMR) not in sys.path:
    sys.path.insert(0, str(CMR))

from cmr_frozen_run_ids import refuse_overwrite  # noqa: E402
from date_v3.display_names import display_name  # noqa: E402
from date_v3.network_matrix import (  # noqa: E402
    is_unsupported,
    matrix_row,
    netlist_owner,
)
from v31_emit import generate_network_rtl  # noqa: E402

LARGE_KIND = {
    "PROP256": "prop256",
    "FM256": "mesh256",
    "PROP1024": "prop1024",
    "FM1024": "mesh1024",
}
LEGACY_64 = {
    "THIN64": ("noc64_async", "thin"),
    "PROP64": ("noc64_async", "1222"),
    "PFAT64": ("noc64_async", "1248"),
    "FM64": ("mesh64", "mesh"),
    "SYNC_THIN64": ("noc64_sync", "thin"),
    "SYNC_PROP64": ("noc64_sync", "fat1222"),
}


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="V3.1.0 whole-network synthesis/simulation")
    parser.add_argument("--design", default=os.environ.get("CMR_NETWORK_DESIGN_ID", "PROP256"))
    parser.add_argument("--check-inputs", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--emit-only", action="store_true")
    return parser.parse_args(argv)


def refuse_bad_design(design_id: str) -> str:
    if is_unsupported(design_id):
        row = matrix_row(design_id)
        raise SystemExit(
            "GATE_FAIL unsupported %s: %s"
            % (display_name(design_id), row["unsupported_reason"])
        )
    owner = netlist_owner(design_id)
    if owner != design_id:
        print(
            "SHARED_NETLIST",
            display_name(design_id),
            "uses",
            display_name(owner),
            flush=True,
        )
    return owner


def check_inputs(owner: str) -> None:
    row = matrix_row(owner)
    if not row["synthesis_supported"]:
        raise SystemExit("GATE_FAIL synthesis not supported for %s" % display_name(owner))
    needed = [
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_child.tcl",
        REPO / "scripts/asic_dc/cmr/run_dc_cmr_hier_stitch.tcl",
        REPO / "scripts/asic_dc/cmr/run_gls_cmr_network.sh",
        REPO / "sim/AsyncNoC/testbench/tb_noc_async_keycase.sv",
        REPO / "sim/AsyncNoC/testbench/gen_noc_scale_port_adapter.py",
    ]
    missing = [str(path) for path in needed if not path.is_file()]
    if missing:
        raise SystemExit("missing driver files: " + ", ".join(missing))
    gls = (REPO / "scripts/asic_dc/cmr/run_gls_cmr_network.sh").read_text(encoding="utf-8")
    if "+notimingcheck" in gls and "forbidden" not in gls:
        raise SystemExit("network GLS shell must forbid +notimingcheck")
    tb = (REPO / "sim/AsyncNoC/testbench/tb_noc_async_keycase.sv").read_text(encoding="utf-8")
    for needle in ("V3_METRICS_CSV", "head_inject_req_ps", "warmup_original_events", "TB_X_FAIL"):
        if needle not in tb:
            raise SystemExit("unified testbench missing %s" % needle)
    print("CHECK_INPUTS_PASS", display_name(owner), flush=True)


def delegate_legacy(owner: str, profile: str, adapter: str) -> int:
    env_map = {
        "noc64_async": "CMR_FAT_LANE_PROFILE",
        "mesh64": None,
        "noc64_sync": "CMR_SYNC64_PROFILE",
    }
    key = env_map[adapter]
    if key:
        os.environ[key] = profile
    if adapter == "noc64_async":
        os.environ["CMR_Q64_PROFILE"] = profile
        os.environ["CMR_HIER_KIND"] = profile if profile != "1222" else "1222"
        from run_remote_cmr_hier_dc import main as hier_main

        hier_main()
        return 0
    if adapter == "mesh64":
        os.environ["CMR_HIER_KIND"] = "mesh"
        from run_remote_cmr_hier_dc import main as hier_main

        hier_main()
        return 0
    if adapter == "noc64_sync":
        os.environ["CMR_SYNC64_PROFILE"] = "thin" if owner == "SYNC_THIN64" else "fat1222"
        from run_remote_cmr_sync_noc64_sdf import main as sync_main

        sync_main()
        return 0
    raise SystemExit("unknown legacy adapter %s" % adapter)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    design_id = args.design.strip()
    os.environ["CMR_NETWORK_DESIGN_ID"] = design_id
    owner = refuse_bad_design(design_id)
    check_inputs(owner)
    if args.check_inputs and not args.emit_only:
        print("DRY_CHECK", display_name(owner), flush=True)
        return 0
    run_id = os.environ.get("CMR_NETWORK_RUN_ID") or os.environ.get("CMR_HIER_STITCH_RUN_ID")
    if not run_id:
        run_id = datetime.now().strftime("%Y%m%d_%H%M%S") + "_cmr_v31_" + owner.lower()
        os.environ["CMR_NETWORK_RUN_ID"] = run_id
        os.environ["CMR_HIER_STITCH_RUN_ID"] = run_id
    refuse_overwrite(run_id, action="network-sdf")
    if args.dry_run:
        print("DRY_RUN", run_id, display_name(owner), flush=True)
        return 0
    generate_network_rtl(owner)
    if args.emit_only:
        print("EMIT_ONLY", display_name(owner), flush=True)
        return 0
    if owner in LEGACY_64:
        adapter, profile = LEGACY_64[owner]
        return delegate_legacy(owner, profile, adapter)
    if owner not in LARGE_KIND:
        raise SystemExit("no whole-network driver for %s" % display_name(owner))
    os.environ["CMR_HIER_KIND"] = LARGE_KIND[owner]
    os.environ.setdefault("CMR_HIER_STITCH_RUN_ID", run_id)
    from run_remote_cmr_hier_dc import main as hier_main

    hier_main()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
