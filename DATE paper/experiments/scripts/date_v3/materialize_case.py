"""Materialize a V3 canonical JSONL into RTL .case / model input.

64-node async DUT keeps the classic expect-mask .case for MAXIMUM-SDF.
256-node key cases use a compact dest-list format (no 256-bit mask scoreboard).
H-REP split is applied here.  PROP keeps one packet per original event.
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from .canonical_trace import PACKET_FLITS, cores_in_rect, load_jsonl, width_of
from .hrep_policy import prop_packet, split_dest_set
from .route_oracle import traversal_for_packet

FLIT_W = 28
NUM_CORES_64 = 64


def make_flit(
    *,
    pkt_id: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    is_head: bool,
    is_tail: bool,
) -> int:
    flit = 0
    flit |= pkt_id & 0x3
    flit |= (x0 & 0x3F) << 2
    flit |= (y0 & 0x3F) << 8
    flit |= (x1 & 0x3F) << 14
    flit |= (y1 & 0x3F) << 20
    flit |= (1 if is_tail else 0) << 26
    flit |= (1 if is_head else 0) << 27
    if flit >= (1 << FLIT_W):
        raise ValueError("flit overflow 0x%x" % flit)
    return flit


def injected_packets(event: dict[str, Any], *, nodes: int, hrep: bool) -> list[dict[str, Any]]:
    width = width_of(nodes)
    if hrep:
        grid = width // 8
        return split_dest_set(
            event["original_event_id"],
            event["source"],
            event["destinations"],
            cluster_grid=grid,
        )
    return [
        prop_packet(
            event["original_event_id"],
            event["source"],
            event["destinations"],
            width,
        )
    ]


def _attach_traversal(
    packet: dict[str, Any],
    *,
    source: int,
    nodes: int,
    routing: str,
) -> dict[str, Any]:
    try:
        return traversal_for_packet(source, packet["rect"], nodes=nodes, routing=routing)
    except Exception as exc:  # pragma: no cover - oracle must not abort case emit
        return {"error": str(exc), "router_traversal": [], "link_traversal": []}


def materialize(
    trace: dict[str, Any],
    *,
    top_lanes: int,
    hrep: bool = False,
    routing: str = "quadtree",
) -> dict[str, Any]:
    header = trace["header"]
    nodes = int(header["nodes"])
    packet_flits = int(header["packet_flits"])
    if packet_flits != PACKET_FLITS:
        raise ValueError("V3 .case path is 5-flit, got %s" % packet_flits)
    width = width_of(nodes)
    case_format = "classic" if nodes == NUM_CORES_64 else "keycase"
    mask_bits = nodes + top_lanes if case_format == "classic" else nodes
    hex_width = (mask_bits + 3) // 4
    inputs: list[tuple[int, int, int, int, str]] = []
    expects: list[tuple[int, int, int, int, str]] = []
    expect_ports: list[tuple[int, int, int, int, str]] = []
    event_map: list[tuple[int, int]] = []
    packets_meta: list[dict[str, Any]] = []
    pkt_seq = 0
    for event in trace["events"]:
        event_index = int(event["event_index"])
        for packet in injected_packets(event, nodes=nodes, hrep=hrep):
            rect = list(packet["rect"])
            dests = cores_in_rect(rect, width)
            dests = [d for d in dests if d != event["source"]]
            if not dests:
                raise ValueError("%s produced no deliveries" % packet["packet_id"])
            flits = [
                make_flit(
                    pkt_id=pkt_seq,
                    x0=rect[0],
                    y0=rect[1],
                    x1=rect[2],
                    y1=rect[3],
                    is_head=(idx == 0),
                    is_tail=(idx == packet_flits - 1),
                )
                for idx in range(packet_flits)
            ]
            traversal = _attach_traversal(
                packet, source=event["source"], nodes=nodes, routing=routing
            )
            for idx, flit in enumerate(flits):
                inputs.append(
                    (
                        event["ready_cycle"] + idx,
                        event["source"],
                        pkt_seq,
                        flit,
                        "%s flit%d" % (packet["packet_id"], idx),
                    )
                )
                for dest in dests:
                    if case_format == "classic":
                        expects.append(
                            (
                                1 << dest,
                                pkt_seq,
                                1 if idx == packet_flits - 1 else 0,
                                flit,
                                "%s dst=%d" % (packet["packet_id"], dest),
                            )
                        )
                    else:
                        expect_ports.append(
                            (
                                dest,
                                pkt_seq,
                                1 if idx == packet_flits - 1 else 0,
                                flit,
                                "%s dst=%d" % (packet["packet_id"], dest),
                            )
                        )
            event_map.append((pkt_seq, event_index))
            packets_meta.append(
                {
                    "pkt_seq": pkt_seq,
                    "original_event_id": event["original_event_id"],
                    "packet_id": packet["packet_id"],
                    "phase": event["phase"],
                    "source": event["source"],
                    "intended_destinations": list(event["destinations"]),
                    "delivered_destinations": dests,
                    "rect": rect,
                    "ready_cycle": event["ready_cycle"],
                    "flits": ["%07x" % flit for flit in flits],
                    "crosses_top_mesh": packet.get("crosses_top_mesh"),
                    "hrep": hrep,
                    "traversal": traversal,
                }
            )
            pkt_seq += 1
    inputs.sort(key=lambda row: (row[1], row[0], row[2]))
    return {
        "header": header,
        "top_lanes": top_lanes,
        "hrep": hrep,
        "routing": routing,
        "case_format": case_format,
        "hex_width": hex_width,
        "inputs": inputs,
        "expects": expects,
        "expect_ports": expect_ports,
        "event_map": event_map,
        "packets": packets_meta,
    }


def _meta_lines(case: dict[str, Any], name: str) -> list[str]:
    header = case["header"]
    return [
        "# Generated by DATE V3 gen_cases_v3.py",
        "case %s" % name,
        "group %s" % header["benchmark_id"],
        "meta paper DATE_V3",
        "meta case_id %s" % name,
        "meta traffic %s" % header["traffic"],
        "meta packet_length_or_distribution %d_flits" % header["packet_flits"],
        "meta packet_flits %d" % header["packet_flits"],
        "meta load_point %.2f" % header["offered_load"],
        "meta load_unit flit_per_cycle_node",
        "meta nodes %d" % header["nodes"],
        "meta seed %d" % header["seed"],
        "meta original_event_count %d"
        % (header["warmup_original_events"] + header["measurement_original_events"]),
        "meta warmup_original_events %d" % header["warmup_original_events"],
        "meta measurement_original_events %d" % header["measurement_original_events"],
        "meta trace_id %s" % header.get("trace_id", name),
        "meta top_lanes %d" % case["top_lanes"],
        "meta hrep %d" % (1 if case["hrep"] else 0),
        "meta format %s" % case["case_format"],
        "meta latency_metric tmax",
        "meta latency_metric_name last_destination_tail_minus_source_header_injection",
        "meta tmax_definition last_destination_tail_minus_source_header_injection",
    ]


def write_case(case: dict[str, Any], path: Path) -> None:
    header = case["header"]
    hex_width = case["hex_width"]
    name = path.stem
    lines = _meta_lines(case, name)
    if case["case_format"] == "keycase":
        lines.append("# packet <pkt_seq> <src> <n_dest> <dest...>")
        lines.append("# input  <cycle> <port> <pkt_seq> <flit_hex>")
        lines.append("# expect_port <port> <pkt_seq> <is_tail> <flit_hex>")
        for pkt_seq, event_index in case["event_map"]:
            lines.append("event_map %6d %6d" % (pkt_seq, event_index))
        for packet in case["packets"]:
            dests = packet["delivered_destinations"]
            lines.append(
                "packet %6d %6d %4d %s"
                % (
                    packet["pkt_seq"],
                    packet["source"],
                    len(dests),
                    " ".join(str(d) for d in dests),
                )
            )
        for cycle, port, pkt_seq, flit, comment in case["inputs"]:
            lines.append(
                "input %6d %2d %6d %07x # %s" % (cycle, port, pkt_seq, flit, comment)
            )
        for port, pkt_seq, is_tail, flit, comment in case["expect_ports"]:
            lines.append(
                "expect_port %6d %6d %d %07x # %s" % (port, pkt_seq, is_tail, flit, comment)
            )
    else:
        lines.append("# input  <cycle> <port> <pkt_seq> <flit_hex>")
        lines.append("# expect <mask_hex> <pkt_seq> <is_tail> <flit_hex>")
        for pkt_seq, event_index in case["event_map"]:
            lines.append("event_map %6d %6d" % (pkt_seq, event_index))
        for cycle, port, pkt_seq, flit, comment in case["inputs"]:
            lines.append(
                "input %6d %2d %6d %07x # %s" % (cycle, port, pkt_seq, flit, comment)
            )
        for mask, pkt_seq, is_tail, flit, comment in case["expects"]:
            lines.append(
                "expect %0*x %6d %d %07x # %s"
                % (hex_width, mask, pkt_seq, is_tail, flit, comment)
            )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    write_packets_sidecar(case, path.with_suffix(".packets.json"))
    write_model_input(case, path.with_suffix(".model.json"))


def write_packets_sidecar(case: dict[str, Any], path: Path) -> None:
    header = case["header"]
    path.write_text(
        json.dumps(
            {
                "trace_id": header.get("trace_id"),
                "trace_hash": header.get("trace_hash"),
                "hrep": case["hrep"],
                "top_lanes": case["top_lanes"],
                "case_format": case["case_format"],
                "packets": case["packets"],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def write_model_input(case: dict[str, Any], path: Path) -> None:
    header = case["header"]
    path.write_text(
        json.dumps(
            {
                "schema": "date-v3-model-input-v1",
                "trace_id": header.get("trace_id"),
                "trace_hash": header.get("trace_hash"),
                "header": header,
                "hrep": case["hrep"],
                "routing": case.get("routing"),
                "packets": [
                    {
                        "pkt_seq": row["pkt_seq"],
                        "original_event_id": row["original_event_id"],
                        "packet_id": row["packet_id"],
                        "phase": row["phase"],
                        "source": row["source"],
                        "destinations": row["intended_destinations"],
                        "delivered_destinations": row["delivered_destinations"],
                        "rect": row["rect"],
                        "ready_cycle": row["ready_cycle"],
                        "flits": row["flits"],
                        "traversal": row.get("traversal"),
                    }
                    for row in case["packets"]
                ],
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )


def materialize_path(
    jsonl: Path,
    out_dir: Path,
    *,
    top_lanes: int,
    hrep: bool = False,
    routing: str = "quadtree",
    design_id: str | None = None,
) -> Path:
    trace = load_jsonl(jsonl)
    case = materialize(trace, top_lanes=top_lanes, hrep=hrep, routing=routing)
    suffix = "hrep" if hrep else (design_id or routing)
    name = "%s_%s_top%d" % (trace["header"].get("trace_id") or jsonl.stem, suffix, top_lanes)
    path = out_dir / ("%s.case" % name)
    write_case(case, path)
    return path
