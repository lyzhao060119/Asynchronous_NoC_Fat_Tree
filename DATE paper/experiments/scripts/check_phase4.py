#!/usr/bin/env python3
"""DATE V3 Phase 4 infrastructure gate.

Confirms 5-flit traces, warmup/measurement split, 3 frozen seeds, paired
canonical materialize, and unified TB Tmax columns.  Does not run 11k-event
MAXIMUM-SDF scoreboard (Phases 6-9).
"""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))

from date_v3.paths import REPO  # noqa: E402

NEEDLES = (
    "V3_METRICS_CSV",
    "head_inject_req_ps",
    "event_map",
    "warmup_original_events",
    "tmax_component_ns",
)

TB_FILES = (
    REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc64_async_boundary.sv",
    REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc64_sync_boundary.sv",
    REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc256_async_keycase.sv",
    REPO / "sim" / "AsyncNoC" / "testbench" / "tb_noc_async_keycase.sv",
)

GLS_FILES = (
    REPO / "scripts" / "asic_dc" / "cmr" / "run_gls_cmr_noc64.sh",
    REPO / "scripts" / "asic_dc" / "cmr" / "run_gls_cmr_sync_noc64.sh",
    REPO / "scripts" / "asic_dc" / "cmr" / "run_gls_cmr_network.sh",
)


def _require(path: Path, needles: tuple[str, ...]) -> None:
    if not path.is_file():
        raise AssertionError("missing %s" % path)
    text = path.read_text(encoding="utf-8")
    for needle in needles:
        if needle not in text:
            raise AssertionError("%s missing %s" % (path.name, needle))


def check_tb_and_gls() -> None:
    for path in TB_FILES:
        _require(path, NEEDLES)
    for path in GLS_FILES:
        _require(path, ("V3_METRICS_CSV",))
    tcl = REPO / "sim" / "AsyncNoC" / "run_noc64_sync_boundary.tcl"
    _require(tcl, ("V3_METRICS_CSV", "CLOCK_PERIOD_NS"))
    _require(
        REPO / "sim" / "AsyncNoC" / "run_noc64_async_boundary.tcl",
        ("V3_METRICS_CSV",),
    )
    _require(
        REPO / "sim" / "AsyncNoC" / "run_noc256_async_keycase.tcl",
        ("V3_METRICS_CSV",),
    )
    print("PASS check_tb_and_gls")


def main() -> int:
    check_tb_and_gls()
    from test_traffic_v3 import main as traffic_main

    rc = traffic_main()
    if rc != 0:
        return rc
    print("PHASE4_GATE_PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
