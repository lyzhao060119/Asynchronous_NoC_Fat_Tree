#!/usr/bin/env python3
"""Fail-closed structural audit for the RTL-only PROP_temp64 Static4 topology."""
from __future__ import annotations

import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
DYNAMIC = REPO / "generated_cmr" / "prop_temp64" / "PROP_temp64.v"
STATIC = REPO / "generated_cmr" / "prop_temp64_static4" / "PROP_temp64_static4.v"


def read_nonzero(path: Path) -> str:
    if not path.is_file() or path.stat().st_size == 0:
        raise SystemExit(f"STATIC64_STRUCTURE_FAIL missing/empty {path}")
    return path.read_text(encoding="utf-8", errors="replace")


def top_ports(text: str, module: str) -> list[str]:
    match = re.search(rf"(?ms)^module {re.escape(module)}\((.*?)^\);", text)
    if not match:
        raise SystemExit(f"STATIC64_STRUCTURE_FAIL top module {module} absent")
    ports = []
    for line in match.group(1).splitlines():
        clean = line.split("//", 1)[0].strip().rstrip(",")
        clean = re.sub(r"\s+", " ", clean)
        if clean:
            ports.append(clean)
    return ports


def count_instances(text: str, level: int) -> int:
    return len(re.findall(rf"(?m)^\s+CMRRouter(?:_\d+)? propL{level}_", text))


def require_line(text: str, line: str) -> None:
    if line not in text:
        raise SystemExit(f"STATIC64_STRUCTURE_FAIL missing connection: {line}")


def main() -> int:
    dynamic = read_nonzero(DYNAMIC)
    static = read_nonzero(STATIC)
    if top_ports(dynamic, "PROP_temp64") != top_ports(static, "PROP_temp64_static4"):
        raise SystemExit("STATIC64_STRUCTURE_FAIL top-level port signature differs from Dynamic64")

    counts = [count_instances(static, level) for level in (1, 2, 3)]
    if counts != [16, 16, 16]:
        raise SystemExit(f"STATIC64_STRUCTURE_FAIL router counts L1/L2/L3={counts}")
    if "LaneSelector #(" in static or "LaneSelector.v" in (
        STATIC.parent / "firrtl_black_box_resource_files.f"
    ).read_text(encoding="utf-8", errors="replace"):
        raise SystemExit("STATIC64_STRUCTURE_FAIL dynamic LaneSelector remains")
    if "LaneSelector #(" not in dynamic:
        raise SystemExit("STATIC64_STRUCTURE_FAIL Dynamic64 reference lacks LaneSelector")
    for value in ("1", "2", "4", "8"):
        if not re.search(rf"laneSelect(?:_\d+)? = .* \? 4'h{value} : 4'h0", static):
            raise SystemExit(f"STATIC64_STRUCTURE_FAIL fixed one-hot 4'h{value} absent")

    # Every L1 router keeps a distinct full-duplex channel to every L2 router.
    # Static mapping selects only the first (upward Req/Data) direction and must
    # not delete the reverse L2-output -> L1-parent-input direction.
    l1_l2_links = 0
    for q in range(4):
        for i in range(4):
            child_direction = (~i) & 3
            for k in range(4):
                l1 = f"propL1_q{q}_i{i}"
                l2 = f"propL2_q{q}_k{k}"
                require_line(static,
                    f"assign {l2}_io_inputs_child_{child_direction}_0_HS_Req = {l1}_io_outputs_parent_{k}_HS_Req;")
                require_line(static,
                    f"assign {l1}_io_outputs_parent_{k}_HS_Ack = {l2}_io_inputs_child_{child_direction}_0_HS_Ack;")
                require_line(static,
                    f"assign {l1}_io_inputs_parent_{k}_HS_Req = {l2}_io_outputs_child_{child_direction}_0_HS_Req;")
                require_line(static,
                    f"assign {l2}_io_outputs_child_{child_direction}_0_HS_Ack = {l1}_io_inputs_parent_{k}_HS_Ack;")
                l1_l2_links += 1

    # The L2-L3 fabric must likewise remain full duplex.  Static selection may
    # choose one of these upward outputs, but it must not remove any reverse
    # L3-output -> L2-parent-input path.
    l2_l3_links = 0
    for q in range(4):
        child_direction = (~q) & 3
        for k in range(4):
            for j in range(4):
                l2 = f"propL2_q{q}_k{k}"
                l3 = f"propL3_j{j}_k{k}"
                require_line(static,
                    f"assign {l3}_io_inputs_child_{child_direction}_0_HS_Req = {l2}_io_outputs_parent_{j}_HS_Req;")
                require_line(static,
                    f"assign {l2}_io_outputs_parent_{j}_HS_Ack = {l3}_io_inputs_child_{child_direction}_0_HS_Ack;")
                require_line(static,
                    f"assign {l2}_io_inputs_parent_{j}_HS_Req = {l3}_io_outputs_child_{child_direction}_0_HS_Req;")
                require_line(static,
                    f"assign {l3}_io_outputs_child_{child_direction}_0_HS_Ack = {l2}_io_inputs_parent_{j}_HS_Ack;")
                l2_l3_links += 1
    print(
        "STATIC64_STRUCTURE_PASS "
        f"top_ports={len(top_ports(static, 'PROP_temp64_static4'))} "
        f"routers={sum(counts)} l1={counts[0]} l2={counts[1]} l3={counts[2]} "
        f"l1_l2_full_duplex_links={l1_l2_links} "
        f"l2_l3_full_duplex_links={l2_l3_links} dynamic_selectors=0",
        flush=True,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
