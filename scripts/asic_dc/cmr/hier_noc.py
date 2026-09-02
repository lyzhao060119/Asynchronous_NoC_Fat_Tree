"""Unique-router inventory for hierarchical NoC64 / mesh64 DC.

Same-level nodes share buffer/mutex/delay/OPM structure.  Coordinates stay
compile-time AABB constants inside RoutingLogic — they are not runtime ports.
Each unique Chisel `CMRRouter` / `CMRRouter_N` module is one hop-sized DC job.
The top netlist only instantiates those compiled refs (set_dont_touch / link).
"""
from __future__ import annotations

import re
from typing import Any

ROUTER_MODULE_RE = re.compile(r"^module\s+(CMRRouter(?:_\d+)?)\b", re.M)
ANY_MODULE_RE = re.compile(r"^module\s+\w+", re.M)
IPM_RE = re.compile(r"^\s+\S+\s+InputPortModules_\d+\s*\(", re.M)
ADAPTER_RE = re.compile(r"LanePhaseAdapter\s*#")
INST_RE = re.compile(r"^\s+(CMRRouter(?:_\d+)?)\s+(\w+)\s*\(", re.M)


def iter_router_modules(verilog: str) -> list[tuple[str, str]]:
    starts = [(m.start(), m.group(1)) for m in ROUTER_MODULE_RE.finditer(verilog)]
    module_starts = [m.start() for m in ANY_MODULE_RE.finditer(verilog)]
    out = []
    for start, name in starts:
        end = next((pos for pos in module_starts if pos > start), len(verilog))
        out.append((name, verilog[start:end]))
    return out


def unique_router_jobs(verilog: str) -> list[dict[str, Any]]:
    jobs = []
    seen: set[str] = set()
    for name, body in iter_router_modules(verilog):
        if name in seen:
            continue
        seen.add(name)
        ports = len(IPM_RE.findall(body))
        adapters = len(ADAPTER_RE.findall(body))
        jobs.append(
            {
                "ref": name,
                "expected_ports": ports,
                "expected_adapters": adapters,
                "expected_path_latches": 4 * ports,
            }
        )
    jobs.sort(key=lambda row: row["ref"])
    return jobs


def child_run_id(parent_run_id: str, index: int, ref: str) -> str:
    safe = ref.replace("CMRRouter", "r").replace("_", "")
    return "%s_c%02d_%s" % (parent_run_id, index, safe)


def instance_paths(verilog: str) -> list[dict[str, str]]:
    """Map instance names to their CMRRouter* refs."""
    return [{"ref": m.group(1), "inst": m.group(2)} for m in INST_RE.finditer(verilog)]
