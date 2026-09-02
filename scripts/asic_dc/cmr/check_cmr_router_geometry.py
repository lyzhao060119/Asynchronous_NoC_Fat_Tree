#!/usr/bin/env python3
"""Count LanePhaseAdapter and CMRMutexN widths in an emitted CMRRouter.

Chisel emits one OPM/ContinuousLaneSelector module per SourceCount/lane
width and instantiates it.  Mutex WIDTH therefore appears once per unique
module; instance counts come from OutputPortModules_* and adapters.
"""

from __future__ import annotations

import argparse
import re
from collections import Counter
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]

EXPECTED_NOC64 = {
    "fat_tree_noc64_1248": {
        "adapters": 352,
        "adapter_lanes": {2: 224, 4: 112, 8: 16},
        "mutex_widths": {2, 4, 5, 8, 10, 16, 20},
        "async_fifo": 0,
        "top_ports": 8,
        "dut": "NoC_64nodes.v",
    },
    "fat_tree_noc64_1222": {
        "adapters": 264,
        "adapter_lanes": {2: 264},
        "mutex_widths": {2, 4, 5, 8},
        "async_fifo": 0,
        "top_ports": 2,
        "dut": "NoC_64nodes.v",
    },
    "mesh_noc16_11": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "async_fifo": 0,
        "top_ports": 0,
        "dut": "CMRMeshNoC.v",
        "routers": 16,
    },
    "mesh_noc64_11": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "async_fifo": 0,
        "top_ports": 0,
        "dut": "CMRMeshNoC.v",
        "routers": 64,
    },
    "fat_tree_noc64_thin": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "async_fifo": 0,
        "top_ports": 1,
        "dut": "NoC_64nodes.v",
        "routers": 21,
    },
}

EXPECTED = {
    "router_l1": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "opm_instances": 5,
    },
    "router_l2": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "opm_instances": 5,
    },
    "router_l3": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "opm_instances": 5,
    },
    "router_l1_c1_p1_mesh": {
        "adapters": 0,
        "adapter_lanes": {},
        "mutex_widths": {4},
        "opm_instances": 5,
    },
    "router_l1_c1_p2": {
        "adapters": 4,
        "adapter_lanes": {2: 4},
        "mutex_widths": {2, 4, 5},
        "opm_instances": 6,
    },
    "router_l2_c2_p2": {
        "adapters": 40,
        "adapter_lanes": {2: 40},
        "mutex_widths": {2, 8},
        "opm_instances": 10,
    },
    "router_l3_c2_p2": {
        "adapters": 40,
        "adapter_lanes": {2: 40},
        "mutex_widths": {2, 8},
        "opm_instances": 10,
    },
    "router_l1_c2_p2_mesh": {
        "adapters": 40,
        "adapter_lanes": {2: 40},
        "mutex_widths": {2, 8},
        "opm_instances": 10,
    },
    "router_l2_c2_p4": {
        "adapters": 48,
        "adapter_lanes": {2: 40, 4: 8},
        "mutex_widths": {2, 4, 8, 10},
        "opm_instances": 12,
    },
    "router_l3_c4_p8": {
        "adapters": 96,
        "adapter_lanes": {4: 80, 8: 16},
        "mutex_widths": {4, 8, 16, 20},
        "opm_instances": 24,
    },
}

EXPECTED_SYNC = {
    "router_l1": {"selectors": 0, "ports": 5, "mutex_widths": set()},
    "router_l2_c2_p2": {"selectors": 40, "ports": 10, "mutex_widths": set()},
}


def parse_router(text: str) -> dict:
    adapter_lanes = [
        int(match)
        for match in re.findall(
            r"LanePhaseAdapter\s*#\s*\(\s*\.\s*LANES\s*\(\s*(\d+)\s*\)",
            text,
        )
    ]
    mutex_widths = {
        int(match)
        for match in re.findall(
            r"CMRMutexN\s*#\s*\(\s*\.\s*WIDTH\s*\(\s*(\d+)\s*\)",
            text,
        )
    }
    if re.search(r"\bMutex4\s+\w+", text):
        mutex_widths.add(4)
    if re.search(r"\bMutex2\s+\w+", text):
        mutex_widths.add(2)
    opm_instances = re.findall(
        r"^\s*(OPM(?:_\d+)?)\s+OutputPortModules_\d+\s*\(",
        text,
        re.M,
    )
    return {
        "adapters": len(adapter_lanes),
        "adapter_lanes": dict(Counter(adapter_lanes)),
        "mutex_widths": mutex_widths,
        "opm_instances": len(opm_instances),
        "opm_types": dict(Counter(opm_instances)),
    }


def check_dir(generated: Path, name: str) -> None:
    verilog = generated / "CMRRouter.v"
    if not verilog.is_file():
        raise SystemExit(f"missing {verilog}")
    observed = parse_router(verilog.read_text(encoding="utf-8", errors="replace"))
    expected = EXPECTED[name]
    print(
        f"{name} ADAPTER={observed['adapters']} "
        f"LANES={observed['adapter_lanes']} "
        f"MUTEX_W={sorted(observed['mutex_widths'])} "
        f"OPM={observed['opm_instances']} {observed['opm_types']}"
    )
    if observed["adapters"] != expected["adapters"]:
        raise SystemExit(
            f"{name}: ADAPTER {observed['adapters']} != {expected['adapters']}"
        )
    if observed["adapter_lanes"] != expected["adapter_lanes"]:
        raise SystemExit(
            f"{name}: LANES {observed['adapter_lanes']} != {expected['adapter_lanes']}"
        )
    if observed["mutex_widths"] != expected["mutex_widths"]:
        raise SystemExit(
            f"{name}: MUTEX widths {observed['mutex_widths']} != {expected['mutex_widths']}"
        )
    if observed["opm_instances"] != expected["opm_instances"]:
        raise SystemExit(
            f"{name}: OPM instances {observed['opm_instances']} != {expected['opm_instances']}"
        )


def check_noc64(generated: Path, name: str) -> None:
    expected = EXPECTED_NOC64[name]
    verilog = generated / expected.get("dut", "NoC_64nodes.v")
    if not verilog.is_file():
        raise SystemExit(f"missing {verilog}")
    text = verilog.read_text(encoding="utf-8", errors="replace")
    observed = parse_router(text)
    fifo = len(re.findall(r"\bAsyncFifo\b", text)) + len(re.findall(r"\bCircularFifo\b", text))
    top_ports = len(set(re.findall(r"io_top_input_(\d+)_", text)))
    print(
        f"{name} ADAPTER={observed['adapters']} "
        f"LANES={observed['adapter_lanes']} "
        f"MUTEX_W={sorted(observed['mutex_widths'])} "
        f"FIFO={fifo} TOP={top_ports}"
    )
    if observed["adapters"] != expected["adapters"]:
        raise SystemExit(f"{name}: ADAPTER {observed['adapters']} != {expected['adapters']}")
    if observed["adapter_lanes"] != expected["adapter_lanes"]:
        raise SystemExit(f"{name}: LANES {observed['adapter_lanes']} != {expected['adapter_lanes']}")
    if observed["mutex_widths"] != expected["mutex_widths"]:
        raise SystemExit(
            f"{name}: MUTEX widths {observed['mutex_widths']} != {expected['mutex_widths']}"
        )
    if fifo != expected["async_fifo"]:
        raise SystemExit(f"{name}: FIFO {fifo} != {expected['async_fifo']} (bypass required)")
    if top_ports != expected["top_ports"]:
        raise SystemExit(f"{name}: top ports {top_ports} != {expected['top_ports']}")
    if "routers" in expected:
        if "mesh" in name:
            router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+meshR_", text, re.M))
        else:
            router_count = len(re.findall(r"^\s+CMRRouter(?:_\d+)?\s+routers?L", text, re.M))
        if router_count != expected["routers"]:
            raise SystemExit(f"{name}: routers {router_count} != {expected['routers']}")


def check_sync_dir(generated: Path, name: str) -> None:
    verilog = generated / "SyncCmrRouter.v"
    if not verilog.is_file():
        raise SystemExit(f"missing {verilog}")
    text = verilog.read_text(encoding="utf-8", errors="replace")
    selectors = len(
        re.findall(r"^\s*SyncLaneSelector(?:_\d+)?\s+\w+\s*\(", text, re.M)
    )
    mutex = len(re.findall(r"^\s*Mutex[0-9]+\s+\w+\s*\(", text, re.M)) + len(
        re.findall(r"^\s*CMRMutexN(?:_\d+)?\s+\w+\s*\(", text, re.M)
    )
    delay = len(re.findall(r"\bDelayElement\b", text))
    adapters = len(re.findall(r"\bLanePhaseAdapter\b", text))
    expected = EXPECTED_SYNC[name]
    print(
        f"sync_{name} SELECTOR={selectors} MUTEX={mutex} DELAY={delay} "
        f"ADAPTER={adapters}"
    )
    if selectors != expected["selectors"]:
        raise SystemExit(
            f"sync {name}: SELECTOR {selectors} != {expected['selectors']}"
        )
    if mutex != 0 or delay != 0 or adapters != 0:
        raise SystemExit(
            f"sync {name}: async leak mutex={mutex} delay={delay} adapter={adapters}"
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=REPO / "generated_cmr")
    parser.add_argument("--sync-root", type=Path, default=REPO / "generated_sync_cmr")
    parser.add_argument("--noc64", action="store_true", help="also check emitted NoC64 / mesh DUT")
    parser.add_argument("--sync", action="store_true", help="check isolated SyncCmrRouter emits")
    parser.add_argument("names", nargs="*")
    args = parser.parse_args()
    names = args.names if args.names else ([] if args.sync else list(EXPECTED))
    for name in names:
        if name not in EXPECTED:
            raise SystemExit(f"unknown geometry {name}")
        check_dir(args.root / name, name)
    if args.noc64:
        for name in EXPECTED_NOC64:
            dut = EXPECTED_NOC64[name].get("dut", "NoC_64nodes.v")
            if not (args.root / name / dut).is_file() and (
                name.startswith("mesh_") or name.endswith("_thin")
            ):
                continue
            check_noc64(args.root / name, name)
    if args.sync:
        for name in EXPECTED_SYNC:
            if (args.sync_root / name / "SyncCmrRouter.v").is_file():
                check_sync_dir(args.sync_root / name, name)
    print("CMR_GEOMETRY_CHECK PASS")


if __name__ == "__main__":
    main()
