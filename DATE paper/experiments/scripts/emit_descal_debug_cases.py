#!/usr/bin/env python3
"""Emit DATE V3 single-packet isolation cases for FM64 / PROP256 debug.

Seed 900001 only.  Does not submit LSF.  Does not cook DelayElement_sim.
"""
from __future__ import annotations

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent
MODEL = SCRIPTS.parent / "model"
for path in (SCRIPTS, MODEL):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from random import Random  # noqa: E402

from date_v3.canonical_trace import (  # noqa: E402
    PACKET_FLITS,
    TRACE_SCHEMA,
    ZERO_LOAD_GAP,
    bounding_rect,
    build_events,
    dump_jsonl,
    load_jsonl,
    schedule_pairs,
    seed_mix,
    width_of,
)
from date_v3.designs import materialize_opts  # noqa: E402
from date_v3.materialize_case import materialize, write_case  # noqa: E402
from date_v3.offered_load import trace_load_fields  # noqa: E402
from date_v3.paths import INTERMEDIATE  # noqa: E402
from des import CALIBRATION_SEED  # noqa: E402

OUT = INTERMEDIATE / "des_calibration"


def n_unicast(*, nodes: int, hops: list[tuple[int, int, int]], tag: str) -> dict:
    width = width_of(nodes)
    pairs = []
    ready = []
    for src, dest, cycle in hops:
        pairs.append(
            {
                "source": src,
                "destinations": [dest],
                "rect": bounding_rect([dest], width),
                "multicast": False,
            }
        )
        ready.append(cycle)
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": tag,
        "traffic": "directed_keycase",
        "nodes": nodes,
        "seed": CALIBRATION_SEED,
        "seed_set_id": "v3_calibration_seed",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": len(hops),
        "spread_S": None,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    header.update(trace_load_fields(0.0))
    return {"header": header, "events": events}


def one_unicast(*, nodes: int, src: int, dest: int, tag: str) -> dict:
    return n_unicast(nodes=nodes, hops=[(src, dest, 0)], tag=tag)


# Mirror scripts/asic_dc/cmr/tb_cmr_router_rate_scan.sv: PKTS=20, FLITS=5, M100.
# Header gaps are exponential (schedule_pairs), not the old uniform 50-tick grid.
HOP_PKTS = 20
HOP_LOAD_MFLIT = 100.0
HOP_UC_SOURCES = (0, 1, 8, 9)
HOP_UC_DEST = 36
HOP_F4_SOURCE = 36
HOP_F4_DESTS = (0, 1, 8, 9)


def _directed_header(*, tag: str, traffic: str, nodes: int, n_events: int, load_point: float) -> dict:
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": tag,
        "traffic": traffic,
        "nodes": nodes,
        "seed": CALIBRATION_SEED,
        "seed_set_id": "v3_calibration_seed",
        "packet_flits": PACKET_FLITS,
        "warmup_original_events": 0,
        "measurement_original_events": n_events,
        "spread_S": None,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    header.update(trace_load_fields(load_point))
    return header


def router_uc_trace(*, nodes: int = 64) -> dict:
    """Four L1 children unicast out of the 2x2, 20 packets each, like hop UC."""
    width = width_of(nodes)
    dest_rect = bounding_rect([HOP_UC_DEST], width)
    pairs = []
    for _pkt in range(HOP_PKTS):
        for src in HOP_UC_SOURCES:
            pairs.append(
                {
                    "source": src,
                    "destinations": [HOP_UC_DEST],
                    "rect": list(dest_rect),
                    "multicast": False,
                }
            )
    sched_rng = Random(seed_mix(CALIBRATION_SEED, nodes, 0, int(HOP_LOAD_MFLIT)))
    ready = schedule_pairs(
        pairs,
        nodes=nodes,
        packet_flits=PACKET_FLITS,
        load_point=HOP_LOAD_MFLIT,
        rng=sched_rng,
    )
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = _directed_header(
        tag="ROUTER-UC",
        traffic="router_uc",
        nodes=nodes,
        n_events=len(pairs),
        load_point=HOP_LOAD_MFLIT,
    )
    return {"header": header, "events": events}


def router_f4_trace(*, nodes: int = 64) -> dict:
    """One source fanout-4 into an L1 2x2, 20 packets, like hop F4."""
    width = width_of(nodes)
    dests = list(HOP_F4_DESTS)
    dest_rect = bounding_rect(dests, width)
    pairs = []
    for _pkt in range(HOP_PKTS):
        pairs.append(
            {
                "source": HOP_F4_SOURCE,
                "destinations": dests,
                "rect": list(dest_rect),
                "multicast": True,
            }
        )
    sched_rng = Random(seed_mix(CALIBRATION_SEED, nodes, 0, int(HOP_LOAD_MFLIT)))
    ready = schedule_pairs(
        pairs,
        nodes=nodes,
        packet_flits=PACKET_FLITS,
        load_point=HOP_LOAD_MFLIT,
        rng=sched_rng,
    )
    events = build_events(pairs, ready, warmup=0, packet_flits=PACKET_FLITS)
    header = _directed_header(
        tag="ROUTER-F4",
        traffic="router_f4",
        nodes=nodes,
        n_events=len(pairs),
        load_point=HOP_LOAD_MFLIT,
    )
    return {"header": header, "events": events}


def emit(design_id: str, name: str, trace: dict, out: Path) -> Path:
    opts = materialize_opts(design_id)
    jsonl = out / "traces" / ("%s.jsonl" % name)
    dump_jsonl(trace, jsonl)
    loaded = load_jsonl(jsonl)
    case = materialize(
        loaded,
        top_lanes=opts["top_lanes"],
        hrep=opts["hrep"],
        routing=opts["routing"],
    )
    path = out / "cases" / ("%s.case" % name)
    write_case(case, path)
    print("EMIT", path, "src", trace["events"][0]["source"], "dst", trace["events"][0]["destinations"], flush=True)
    return path


def emit_classic_mesh16(*, name: str, src: int, dest: int, out: Path) -> Path:
    """16-port classic .case for 4x4 mesh isolation.  Does not add an FM16 paper design."""
    width = 4
    if not (0 <= src < 16 and 0 <= dest < 16 and src != dest):
        raise ValueError("mesh16 isolation needs distinct cores 0..15")
    x = dest % width
    y = dest // width
    addr = ((x & 0x3F) << 2) | ((y & 0x3F) << 8) | ((x & 0x3F) << 14) | ((y & 0x3F) << 20)
    head = addr | (1 << 27)
    body = 0
    tail = 1 << 26
    flits = [head, body, body, body, tail]
    mask = 1 << dest
    lines = [
        "# Generated by DATE V3 emit_descal_debug_cases.py",
        "case %s" % name,
        "group DBG-16",
        "meta paper DATE_V3",
        "meta case_id %s" % name,
        "meta traffic directed_keycase",
        "meta packet_length_or_distribution 5_flits",
        "meta packet_flits 5",
        "meta load_point 0.00",
        "meta load_unit MFlit_per_port_s",
        "meta case_tick_ns 1.000",
        "meta nodes 16",
        "meta seed %d" % CALIBRATION_SEED,
        "meta original_event_count 1",
        "meta warmup_original_events 0",
        "meta measurement_original_events 1",
        "meta trace_id %s" % name,
        "meta top_lanes 0",
        "meta hrep 0",
        "meta format classic",
        "meta latency_metric tmax",
        "meta latency_metric_name last_destination_tail_minus_source_header_injection",
        "meta tmax_definition last_destination_tail_minus_source_header_injection",
        "# input  <cycle> <port> <pkt_seq> <flit_hex>",
        "# expect <mask_hex> <pkt_seq> <is_tail> <flit_hex>",
        "event_map      0      0",
    ]
    for idx, flit in enumerate(flits):
        lines.append("input      %d  %d      0 %07x # e000000#0 flit%d" % (idx, src, flit, idx))
    for idx, flit in enumerate(flits):
        is_tail = 1 if idx == len(flits) - 1 else 0
        lines.append("expect %04x      0 %d %07x # e000000#0 dst=%d" % (mask, is_tail, flit, dest))
    path = out / "cases" / ("%s.case" % name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("EMIT", path, "src", src, "dst", dest, flush=True)
    return path


def emit_classic_mesh64_body0(*, name: str, src: int, dest: int, out: Path) -> Path:
    """64-port classic .case: Head keeps dest AABB, Body/Tail clear [25:2]."""
    width = 8
    nodes = 64
    if not (0 <= src < nodes and 0 <= dest < nodes and src != dest):
        raise ValueError("mesh64 isolation needs distinct cores 0..63")
    x = dest % width
    y = dest // width
    addr = ((x & 0x3F) << 2) | ((y & 0x3F) << 8) | ((x & 0x3F) << 14) | ((y & 0x3F) << 20)
    head = addr | (1 << 27)
    body = 0
    tail = 1 << 26
    flits = [head, body, body, body, tail]
    mask = 1 << dest
    lines = [
        "# Generated by DATE V3 emit_descal_debug_cases.py",
        "case %s" % name,
        "group DBG-64",
        "meta paper DATE_V3",
        "meta case_id %s" % name,
        "meta traffic directed_keycase",
        "meta packet_length_or_distribution 5_flits",
        "meta packet_flits 5",
        "meta load_point 0.00",
        "meta load_unit MFlit_per_port_s",
        "meta case_tick_ns 1.000",
        "meta nodes 64",
        "meta seed %d" % CALIBRATION_SEED,
        "meta original_event_count 1",
        "meta warmup_original_events 0",
        "meta measurement_original_events 1",
        "meta trace_id %s" % name,
        "meta top_lanes 0",
        "meta hrep 0",
        "meta format classic",
        "meta latency_metric tmax",
        "meta latency_metric_name last_destination_tail_minus_source_header_injection",
        "meta tmax_definition last_destination_tail_minus_source_header_injection",
        "# input  <cycle> <port> <pkt_seq> <flit_hex>",
        "# expect <mask_hex> <pkt_seq> <is_tail> <flit_hex>",
        "event_map      0      0",
    ]
    for idx, flit in enumerate(flits):
        lines.append("input      %d  %d      0 %07x # e000000#0 flit%d" % (idx, src, flit, idx))
    for idx, flit in enumerate(flits):
        is_tail = 1 if idx == len(flits) - 1 else 0
        lines.append(
            "expect %016x      0 %d %07x # e000000#0 dst=%d" % (mask, is_tail, flit, dest)
        )
    path = out / "cases" / ("%s.case" % name)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("EMIT", path, "src", src, "dst", dest, "flits", ["%07x" % f for f in flits], flush=True)
    return path


def main() -> int:
    out = OUT
    jobs = [
        (
            "FM64",
            "DBG-64_fm64_6to44",
            one_unicast(nodes=64, src=6, dest=44, tag="DBG-64"),
        ),
        (
            "PROP256",
            "DBG-256_prop_138to37",
            one_unicast(nodes=256, src=138, dest=37, tag="DBG-256"),
        ),
        (
            "PROP256",
            "DBG-256_prop_15to0",
            one_unicast(nodes=256, src=15, dest=0, tag="DBG-256"),
        ),
        (
            "PROP256",
            "DBG-256_prop_13and15",
            n_unicast(
                nodes=256,
                hops=[(185, 195, 0), (138, 37, 522)],
                tag="DBG-256",
            ),
        ),
        (
            "FM256",
            "DBG-256_fm256_77to189",
            one_unicast(nodes=256, src=77, dest=189, tag="DBG-256"),
        ),
    ]
    for design_id, name, trace in jobs:
        emit(design_id, name, trace, out)
    emit_classic_mesh16(name="DBG-16_fm16_3to13", src=3, dest=13, out=out)
    emit_classic_mesh64_body0(name="DBG-64_fm64_6to44_body0", src=6, dest=44, out=out)
    emit(
        "PROP64",
        "ROUTER-UC_n64_s900001_m100_PROP64_top2",
        router_uc_trace(),
        out,
    )
    emit(
        "PROP64",
        "ROUTER-F4_n64_s900001_m100_PROP64_top2",
        router_f4_trace(),
        out,
    )
    print("EMIT_OK seed=%d gap=%d" % (CALIBRATION_SEED, ZERO_LOAD_GAP), flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
