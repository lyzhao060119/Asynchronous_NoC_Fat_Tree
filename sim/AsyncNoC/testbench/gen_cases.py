#!/usr/bin/env python3
"""Generate doc-aligned 16-node SyncNoC network-level test cases."""

from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass, field
from functools import lru_cache
from pathlib import Path
from typing import Iterable


FLIT_W = 28
NUM_PORTS = 20
NUM_CORES = 16
TOP_PORT_BASE = 16
TOP_LANES = 4

TB_TX_DEPTH = 1024
TB_RX_DEPTH = 1024

VCTM_GROUP = "VCTM_16"
TAB_GROUP = "TAB_16"

VALIDATION_LOAD_POINTS = (0.02, 0.10, 0.20, 0.30)
FORMAL_LOAD_POINTS = (0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.10, 0.11, 0.12, 0.13, 0.14, 0.15)

VCTM_PACKET_LENGTHS = (1, 3, 5)
TAB_PACKET_LENGTHS = (3, 20)

VALIDATION_EVENT_COUNTS = {
    "vctm": 1000,
    "tab_3f": 1000,
    "tab_20f": 200,
}
FORMAL_EVENT_COUNTS = {
    "vctm": 10_000,
    "tab_3f": 10_000,
    "tab_20f": 2_000,
}

DEFAULT_VCTM_MC_RATIOS = (0, 1, 5, 10)
SUPPORTED_VCTM_MC_RATIOS = (0, 1, 5, 10)

TRACE_SEED_VCTM_NOMC = 2026062301
TRACE_SEED_VCTM_MC = 2026062302
TRACE_SEED_TAB = 2026062303

DIR_CHILD0 = 0
DIR_CHILD1 = 1
DIR_CHILD2 = 2
DIR_CHILD3 = 3
DIR_PARENT = 4

PORT_NAMES = [f"core{i}" for i in range(NUM_CORES)] + [f"top{i}" for i in range(TOP_LANES)]


def port_xy(port: int) -> tuple[int, int]:
    if not 0 <= port < NUM_CORES:
        raise ValueError(f"bad physical core port {port}")
    return port & 0x3, port >> 2


def port_id(x: int, y: int) -> int:
    if not (0 <= x < 4 and 0 <= y < 4):
        raise ValueError(f"physical port coordinate out of range: ({x},{y})")
    return x + 4 * y


def doc_node_xy(node: int) -> tuple[int, int]:
    if not 0 <= node < NUM_CORES:
        raise ValueError(f"bad document node id {node}")
    return node // 4, node % 4


def doc_node_id(x: int, y: int) -> int:
    if not (0 <= x < 4 and 0 <= y < 4):
        raise ValueError(f"document node coordinate out of range: ({x},{y})")
    return 4 * x + y


def doc_node_port(node: int) -> int:
    x, y = doc_node_xy(node)
    return port_id(x, y)


def doc_point_rect(node: int) -> tuple[int, int, int, int]:
    x, y = doc_node_xy(node)
    return x, y, x, y


def l1_xy_for_port(port: int) -> tuple[int, int]:
    x, y = port_xy(port)
    return x >> 1, y >> 1


def child_dir_for_local_xy(local_x: int, local_y: int) -> int:
    return 3 - ((local_x << 1) | local_y)


def child_dir_for_port(port: int) -> int:
    x, y = port_xy(port)
    return child_dir_for_local_xy(x & 0x1, y & 0x1)


def port_for_l1_child(l1_x: int, l1_y: int, direction: int) -> int:
    if not 0 <= direction <= 3:
        raise ValueError(f"bad child direction {direction}")
    selector = 3 - direction
    local_x = (selector >> 1) & 0x1
    local_y = selector & 0x1
    return port_id(2 * l1_x + local_x, 2 * l1_y + local_y)


def l2_child_dir_for_l1(l1_x: int, l1_y: int) -> int:
    return child_dir_for_local_xy(l1_x, l1_y)


def l1_xy_for_l2_child(direction: int) -> tuple[int, int]:
    selector = 3 - direction
    return (selector >> 1) & 0x1, selector & 0x1


def top_mask() -> int:
    return ((1 << TOP_LANES) - 1) << TOP_PORT_BASE


def normalize_rect(rect: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = rect
    return min(x0, x1), min(y0, y1), max(x0, x1), max(y0, y1)


def rect_doc_nodes(rect: tuple[int, int, int, int]) -> tuple[int, ...]:
    x0, y0, x1, y1 = normalize_rect(rect)
    return tuple(doc_node_id(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1))


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
        raise ValueError(f"flit overflow: 0x{flit:x}")
    return flit


def packet_flits(pkt_id: int, rect: tuple[int, int, int, int], length: int) -> list[int]:
    if length < 1:
        raise ValueError("packet length must be positive")
    x0, y0, x1, y1 = rect
    return [
        make_flit(
            pkt_id=pkt_id,
            x0=x0,
            y0=y0,
            x1=x1,
            y1=y1,
            is_head=(idx == 0),
            is_tail=(idx == length - 1),
        )
        for idx in range(length)
    ]


def current_tree_coord(router_x: int, router_y: int, level: int) -> tuple[int, int]:
    if level == 1:
        return (router_x >> 2) & 0x3, (router_y >> 2) & 0x3
    if level == 2:
        return (router_x >> 1) & 0x3, (router_y >> 1) & 0x3
    raise ValueError(f"unsupported router level {level}")


def local_router_coord(router_x: int, router_y: int, level: int) -> tuple[int, int]:
    if level == 1:
        return router_x & 0x3, router_y & 0x3
    if level == 2:
        return router_x & 0x1, router_y & 0x1
    raise ValueError(f"unsupported router level {level}")


def route_dirs_at_router(
    *,
    level: int,
    router_x: int,
    router_y: int,
    rect: tuple[int, int, int, int],
    ingress_dir: int,
) -> set[int]:
    x_lo_global, y_lo_global, x_hi_global, y_hi_global = normalize_rect(rect)
    tree_x, tree_y = current_tree_coord(router_x, router_y, level)
    tree_base_x = tree_x << 3
    tree_base_y = tree_y << 3
    tree_max_x = tree_base_x + 7
    tree_max_y = tree_base_y + 7

    tree_intersects = (
        x_hi_global >= tree_base_x
        and x_lo_global <= tree_max_x
        and y_hi_global >= tree_base_y
        and y_lo_global <= tree_max_y
    )
    tree_contains_rect = (
        x_lo_global >= tree_base_x
        and x_hi_global <= tree_max_x
        and y_lo_global >= tree_base_y
        and y_hi_global <= tree_max_y
    )

    if not tree_intersects:
        return {DIR_PARENT} if ingress_dir != DIR_PARENT else set()

    x_min = max(x_lo_global - tree_base_x, 0)
    x_max = min(x_hi_global - tree_base_x, 7)
    y_min = max(y_lo_global - tree_base_y, 0)
    y_max = min(y_hi_global - tree_base_y, 7)
    local_x, local_y = local_router_coord(router_x, router_y, level)

    dirs: set[int] = set()
    if level == 1:
        base_x = local_x << 1
        base_y = local_y << 1
        points = {
            DIR_CHILD3: (base_x, base_y),
            DIR_CHILD1: (base_x | 1, base_y),
            DIR_CHILD2: (base_x, base_y | 1),
            DIR_CHILD0: (base_x | 1, base_y | 1),
        }
        for direction, (x, y) in points.items():
            if x_min <= x <= x_max and y_min <= y <= y_max:
                dirs.add(direction)
        local_inside = x_min >= base_x and x_max <= (base_x | 1) and y_min >= base_y and y_max <= (base_y | 1)
        if not local_inside:
            dirs.add(DIR_PARENT)
    elif level == 2:
        base_x = (local_x & 0x1) << 2
        base_y = (local_y & 0x1) << 2
        quads = {
            DIR_CHILD3: (base_x, base_x | 1, base_y, base_y | 1),
            DIR_CHILD1: (base_x | 2, base_x | 3, base_y, base_y | 1),
            DIR_CHILD2: (base_x, base_x | 1, base_y | 2, base_y | 3),
            DIR_CHILD0: (base_x | 2, base_x | 3, base_y | 2, base_y | 3),
        }
        for direction, (qx0, qx1, qy0, qy1) in quads.items():
            if qx1 >= x_min and qx0 <= x_max and qy1 >= y_min and qy0 <= y_max:
                dirs.add(direction)
        local_inside = x_min >= base_x and x_max <= (base_x | 3) and y_min >= base_y and y_max <= (base_y | 3)
        if not local_inside:
            dirs.add(DIR_PARENT)

    bypass_ingress_suppress = level == 1 and ingress_dir != DIR_PARENT
    if not bypass_ingress_suppress:
        dirs.discard(ingress_dir)
    if not tree_contains_rect and ingress_dir != DIR_PARENT:
        dirs.add(DIR_PARENT)
    return dirs


def expected_output_masks(src_port: int, rect: tuple[int, int, int, int]) -> list[int]:
    masks: list[int] = []

    def add_mask(mask: int) -> None:
        if mask and mask not in masks:
            masks.append(mask)

    def route_into_l1(l1_x: int, l1_y: int, ingress_dir: int) -> None:
        for direction in sorted(
            route_dirs_at_router(level=1, router_x=l1_x, router_y=l1_y, rect=rect, ingress_dir=ingress_dir)
        ):
            if direction == DIR_PARENT:
                add_mask(top_mask())
            else:
                add_mask(1 << port_for_l1_child(l1_x, l1_y, direction))

    def route_into_l2(ingress_dir: int) -> None:
        for direction in sorted(route_dirs_at_router(level=2, router_x=0, router_y=0, rect=rect, ingress_dir=ingress_dir)):
            if direction == DIR_PARENT:
                add_mask(top_mask())
            else:
                route_into_l1(*l1_xy_for_l2_child(direction), ingress_dir=DIR_PARENT)

    if 0 <= src_port < NUM_CORES:
        l1_x, l1_y = l1_xy_for_port(src_port)
        ingress = child_dir_for_port(src_port)
        for direction in sorted(route_dirs_at_router(level=1, router_x=l1_x, router_y=l1_y, rect=rect, ingress_dir=ingress)):
            if direction == DIR_PARENT:
                route_into_l2(l2_child_dir_for_l1(l1_x, l1_y))
            else:
                add_mask(1 << port_for_l1_child(l1_x, l1_y, direction))
    elif TOP_PORT_BASE <= src_port < NUM_PORTS:
        route_into_l2(DIR_PARENT)
    else:
        raise ValueError(f"bad source port {src_port}")

    return masks


def seed_from(base: int, *parts: int) -> int:
    seed = base & 0xFFFFFFFF
    for part in parts:
        seed = (seed * 1664525 + 1013904223 + (part & 0xFFFFFFFF)) & 0xFFFFFFFF
    return seed


def load_to_tag(load_point: float) -> str:
    whole = int(load_point)
    frac = int(round((load_point - whole) * 100))
    return f"r{whole}p{frac:02d}"


@dataclass(frozen=True)
class OriginalEvent:
    event_id: int
    source_node: int
    ready_cycle: int
    mode: str
    rect: tuple[int, int, int, int]

    @property
    def destination_nodes(self) -> tuple[int, ...]:
        return rect_doc_nodes(self.rect)


@dataclass
class InputEvent:
    cycle: int
    port: int
    pkt_seq: int
    flit: int
    comment: str


@dataclass
class ExpectedEvent:
    mask: int
    pkt_seq: int
    is_tail: bool
    flit: int
    comment: str


@dataclass
class Case:
    name: str
    group: str
    paper: str
    traffic: str
    packet_length_or_distribution: str
    load_point: float
    load_unit: str
    scale_type: str
    paper_defined_scale: str
    latency_metric: str
    latency_metric_name: str
    node_num: int
    original_event_count: int
    trace_id: str
    multicast_ratio: int | None = None
    mode: str | None = None
    notes: list[str] = field(default_factory=list)
    packet_count: int = 0
    packet_event_ids: list[int] = field(default_factory=list)
    inputs: list[InputEvent] = field(default_factory=list)
    expects: list[ExpectedEvent] = field(default_factory=list)

    @property
    def case_id(self) -> str:
        return self.name

    def add_packet(
        self,
        *,
        name: str,
        start_cycle: int,
        src_port: int,
        rect: tuple[int, int, int, int],
        length: int,
        event_id: int,
    ) -> None:
        masks = expected_output_masks(src_port, rect)
        if not masks:
            raise ValueError(f"{self.name}:{name} has no expected outputs")

        pkt_seq = self.packet_count
        self.packet_count += 1
        self.packet_event_ids.append(event_id)
        flits = packet_flits(pkt_seq, rect, length)
        for idx, flit in enumerate(flits):
            self.inputs.append(
                InputEvent(
                    cycle=start_cycle + idx,
                    port=src_port,
                    pkt_seq=pkt_seq,
                    flit=flit,
                    comment=f"{name} flit{idx} src={PORT_NAMES[src_port]} rect={rect}",
                )
            )
            for mask in masks:
                self.expects.append(
                    ExpectedEvent(
                        mask=mask,
                        pkt_seq=pkt_seq,
                        is_tail=(idx == length - 1),
                        flit=flit,
                        comment=f"{name} flit{idx} dst_mask=0x{mask:05x}",
                    )
                )

    def sort_inputs(self) -> None:
        self.inputs.sort(key=lambda event: (event.port, event.cycle, event.pkt_seq))

    def validate_capacity(self) -> None:
        tx_counts = [0] * NUM_PORTS
        rx_counts = [0] * NUM_PORTS
        for event in self.inputs:
            tx_counts[event.port] += 1
        for event in self.expects:
            for port in range(NUM_PORTS):
                if event.mask == (1 << port):
                    rx_counts[port] += 1
        for port, count in enumerate(tx_counts):
            if count > TB_TX_DEPTH:
                raise ValueError(f"{self.name}: TX port {port} count {count} exceeds TB_TX_DEPTH={TB_TX_DEPTH}")
        for port, count in enumerate(rx_counts):
            if count > TB_RX_DEPTH:
                raise ValueError(f"{self.name}: RX port {port} count {count} exceeds TB_RX_DEPTH={TB_RX_DEPTH}")


def write_case(case: Case, out_dir: Path, emit_json: bool) -> None:
    case.sort_inputs()
    case.validate_capacity()
    group_dir = out_dir / case.group
    group_dir.mkdir(parents=True, exist_ok=True)
    path = group_dir / f"{case.name}.case"
    with path.open("w", encoding="utf-8") as out:
        out.write("# Generated by sim/AsyncNoC/testbench/gen_cases.py\n")
        out.write(f"case {case.name}\n")
        out.write(f"group {case.group}\n")
        out.write(f"meta paper {case.paper}\n")
        out.write(f"meta case_id {case.case_id}\n")
        out.write(f"meta traffic {case.traffic}\n")
        out.write(f"meta packet_length_or_distribution {case.packet_length_or_distribution}\n")
        out.write(f"meta load_point {case.load_point:.2f}\n")
        out.write(f"meta load_unit {case.load_unit}\n")
        out.write(f"meta scale_type {case.scale_type}\n")
        out.write(f"meta paper_defined_scale {case.paper_defined_scale}\n")
        out.write(f"meta latency_metric {case.latency_metric}\n")
        out.write(f"meta latency_metric_name {case.latency_metric_name}\n")
        out.write(f"meta node_num {case.node_num}\n")
        out.write(f"meta original_event_count {case.original_event_count}\n")
        out.write(f"meta trace_id {case.trace_id}\n")
        if case.multicast_ratio is not None:
            out.write(f"meta multicast_ratio {case.multicast_ratio}\n")
        if case.mode is not None:
            out.write(f"meta mode {case.mode}\n")
        for note in case.notes:
            out.write(f"# note {note}\n")
        for pkt_seq, event_id in enumerate(case.packet_event_ids):
            out.write(f"event_map {pkt_seq:6d} {event_id:6d}\n")
        out.write("# input  <cycle> <port> <pkt_seq> <flit_hex>\n")
        out.write("# expect <mask_hex> <pkt_seq> <is_tail> <flit_hex>\n")
        for event in case.inputs:
            out.write(f"input {event.cycle:6d} {event.port:2d} {event.pkt_seq:6d} {event.flit:07x} # {event.comment}\n")
        for event in case.expects:
            out.write(f"expect {event.mask:05x} {event.pkt_seq:6d} {1 if event.is_tail else 0:d} {event.flit:07x} # {event.comment}\n")
    print(path)

    if emit_json:
        payload = {
            "case": case.name,
            "group": case.group,
            "paper": case.paper,
            "case_id": case.case_id,
            "traffic": case.traffic,
            "packet_length_or_distribution": case.packet_length_or_distribution,
            "load_point": case.load_point,
            "load_unit": case.load_unit,
            "scale_type": case.scale_type,
            "paper_defined_scale": case.paper_defined_scale,
            "latency_metric": case.latency_metric,
            "latency_metric_name": case.latency_metric_name,
            "node_num": case.node_num,
            "original_event_count": case.original_event_count,
            "trace_id": case.trace_id,
            "multicast_ratio": case.multicast_ratio,
            "mode": case.mode,
            "notes": case.notes,
            "packet_count": case.packet_count,
            "packet_event_ids": case.packet_event_ids,
            "input_flit_count": len(case.inputs),
            "expected_flit_count": len(case.expects),
            "inputs": [event.__dict__ for event in case.inputs],
            "expects": [event.__dict__ for event in case.expects],
        }
        json_path = group_dir / f"{case.name}.json"
        json_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")
        print(json_path)


def choose_unicast_destination(rng: random.Random, source_node: int) -> int:
    choices = [node for node in range(NUM_CORES) if node != source_node]
    return rng.choice(choices)


@lru_cache(maxsize=None)
def multicast_rect_candidates(source_node: int) -> tuple[tuple[tuple[int, int, int, int], tuple[int, ...]], ...]:
    candidates: list[tuple[tuple[int, int, int, int], tuple[int, ...]]] = []
    src_x, src_y = doc_node_xy(source_node)
    for x0 in range(4):
        for y0 in range(4):
            for x1 in range(x0, 4):
                for y1 in range(y0, 4):
                    rect = (x0, y0, x1, y1)
                    if x0 <= src_x <= x1 and y0 <= src_y <= y1:
                        continue
                    nodes = rect_doc_nodes(rect)
                    if any(node == source_node for node in nodes):
                        continue
                    candidates.append((rect, nodes))
    if not candidates:
        raise ValueError(f"no multicast rectangle candidates for source node {source_node}")
    return tuple(candidates)


def choose_multicast_rect(rng: random.Random, source_node: int) -> tuple[int, int, int, int]:
    rect, _ = rng.choice(multicast_rect_candidates(source_node))
    return rect


def generate_event_schedule(target_count: int, packet_length: int, load_point: float, seed: int) -> list[tuple[int, int, int]]:
    if packet_length < 1:
        raise ValueError("packet_length must be positive")
    packet_start_prob = load_point / packet_length
    if not (0.0 <= packet_start_prob <= 1.0):
        raise ValueError(f"bad packet-start probability {packet_start_prob} for load {load_point} length {packet_length}")

    rng = random.Random(seed)
    source_busy_until = [0] * NUM_CORES
    events: list[tuple[int, int, int]] = []
    cycle = 0
    while len(events) < target_count:
        for source_node in range(NUM_CORES):
            if cycle < source_busy_until[source_node]:
                continue
            if rng.random() < packet_start_prob:
                event_id = len(events)
                events.append((event_id, source_node, cycle))
                source_busy_until[source_node] = cycle + packet_length
                if len(events) >= target_count:
                    break
        cycle += 1
    return events


def build_uniform_unicast_events(
    *,
    target_count: int,
    packet_length: int,
    load_point: float,
    schedule_seed: int,
    traffic_seed: int,
) -> list[OriginalEvent]:
    schedule = generate_event_schedule(target_count, packet_length, load_point, schedule_seed)
    traffic_rng = random.Random(traffic_seed)
    events: list[OriginalEvent] = []
    for event_id, source_node, ready_cycle in schedule:
        dst_node = choose_unicast_destination(traffic_rng, source_node)
        events.append(
            OriginalEvent(
                event_id=event_id,
                source_node=source_node,
                ready_cycle=ready_cycle,
                mode="unicast",
                rect=doc_point_rect(dst_node),
            )
        )
    return events


def build_vctm_events(
    *,
    target_count: int,
    packet_length: int,
    load_point: float,
    multicast_ratio: int,
    schedule_seed: int,
    traffic_seed: int,
) -> list[OriginalEvent]:
    schedule = generate_event_schedule(target_count, packet_length, load_point, schedule_seed)
    traffic_rng = random.Random(traffic_seed)
    multicast_count = (target_count * multicast_ratio) // 100
    multicast_event_ids = set(traffic_rng.sample(range(target_count), multicast_count)) if multicast_count else set()

    events: list[OriginalEvent] = []
    for event_id, source_node, ready_cycle in schedule:
        if event_id in multicast_event_ids:
            rect = choose_multicast_rect(traffic_rng, source_node)
            events.append(
                OriginalEvent(
                    event_id=event_id,
                    source_node=source_node,
                    ready_cycle=ready_cycle,
                    mode="multicast_rect",
                    rect=rect,
                )
            )
        else:
            dst_node = choose_unicast_destination(traffic_rng, source_node)
            events.append(
                OriginalEvent(
                    event_id=event_id,
                    source_node=source_node,
                    ready_cycle=ready_cycle,
                    mode="unicast",
                    rect=doc_point_rect(dst_node),
                )
            )
        if multicast_ratio and len(events[-1].destination_nodes) < 1:
            raise ValueError("multicast destination_set must contain at least one destination")
    return events


def materialize_unicast_trace(case: Case, events: list[OriginalEvent], packet_length: int) -> None:
    source_next_free = [0] * NUM_CORES
    for event in events:
        src_port = doc_node_port(event.source_node)
        start_cycle = max(event.ready_cycle, source_next_free[event.source_node])
        source_next_free[event.source_node] = start_cycle + packet_length
        case.add_packet(
            name=f"evt{event.event_id}_{event.mode}_n{event.source_node}",
            start_cycle=start_cycle,
            src_port=src_port,
            rect=event.rect,
            length=packet_length,
            event_id=event.event_id,
        )


def materialize_repeated_unicast_trace(case: Case, events: list[OriginalEvent], packet_length: int) -> None:
    source_next_free = [0] * NUM_CORES
    for event in events:
        src_port = doc_node_port(event.source_node)
        start_cycle = max(event.ready_cycle, source_next_free[event.source_node])
        if event.mode == "unicast":
            case.add_packet(
                name=f"evt{event.event_id}_ru_uni_n{event.source_node}",
                start_cycle=start_cycle,
                src_port=src_port,
                rect=event.rect,
                length=packet_length,
                event_id=event.event_id,
            )
            source_next_free[event.source_node] = start_cycle + packet_length
            continue

        destinations = [node for node in event.destination_nodes if node != event.source_node]
        if not destinations:
            raise ValueError(f"multicast event {event.event_id} has empty destination_set after source filtering")
        for idx, dst_node in enumerate(destinations):
            case.add_packet(
                name=f"evt{event.event_id}_ru_{idx}_n{event.source_node}_to_n{dst_node}",
                start_cycle=start_cycle + idx * packet_length,
                src_port=src_port,
                rect=doc_point_rect(dst_node),
                length=packet_length,
                event_id=event.event_id,
            )
        source_next_free[event.source_node] = start_cycle + len(destinations) * packet_length


def build_vctm_cases(scale_type: str, load_points: tuple[float, ...], original_event_count: int) -> Iterable[Case]:
    common_note = "document node numbering follows the markdown table and is mapped internally onto physical core ports"
    mc_note = "native multicast is verified with hardware-supported axis-aligned rectangles that exclude the source node"

    for packet_length in VCTM_PACKET_LENGTHS:
        for load_point in load_points:
            load_tag = load_to_tag(load_point)

            nomc_trace_id = f"vctm_nomc_{packet_length}f_{load_tag}_{scale_type}"
            nomc_events = build_uniform_unicast_events(
                target_count=original_event_count,
                packet_length=packet_length,
                load_point=load_point,
                schedule_seed=seed_from(TRACE_SEED_VCTM_NOMC, packet_length, int(round(load_point * 100))),
                traffic_seed=seed_from(TRACE_SEED_VCTM_NOMC ^ 0x13579BDF, packet_length, int(round(load_point * 100))),
            )
            nomc_case = Case(
                name=f"VCTM-NoMC-{packet_length}f-{load_tag}",
                group=VCTM_GROUP,
                paper="VCTM",
                traffic="uniform_random",
                packet_length_or_distribution=f"{packet_length}_flits",
                load_point=load_point,
                load_unit="flit_per_cycle_node",
                scale_type=scale_type,
                paper_defined_scale="no",
                latency_metric="network",
                latency_metric_name="average_network_latency",
                node_num=NUM_CORES,
                original_event_count=original_event_count,
                trace_id=nomc_trace_id,
                multicast_ratio=0,
                mode="NoMC",
                notes=[common_note],
            )
            materialize_unicast_trace(nomc_case, nomc_events, packet_length)
            yield nomc_case

            for multicast_ratio in DEFAULT_VCTM_MC_RATIOS:
                if multicast_ratio == 0:
                    continue
                mc_trace_id = f"vctm_mc{multicast_ratio}_{packet_length}f_{load_tag}_{scale_type}"
                mc_events = build_vctm_events(
                    target_count=original_event_count,
                    packet_length=packet_length,
                    load_point=load_point,
                    multicast_ratio=multicast_ratio,
                    schedule_seed=seed_from(TRACE_SEED_VCTM_MC, multicast_ratio, packet_length, int(round(load_point * 100))),
                    traffic_seed=seed_from(
                        TRACE_SEED_VCTM_MC ^ 0x2468ACE0,
                        multicast_ratio,
                        packet_length,
                        int(round(load_point * 100)),
                    ),
                )

                ru_case = Case(
                    name=f"VCTM-MC{multicast_ratio}-RU-{packet_length}f-{load_tag}",
                    group=VCTM_GROUP,
                    paper="VCTM",
                    traffic="uniform_random",
                    packet_length_or_distribution=f"{packet_length}_flits",
                    load_point=load_point,
                    load_unit="flit_per_cycle_node",
                    scale_type=scale_type,
                    paper_defined_scale="no",
                    latency_metric="network",
                    latency_metric_name="average_network_latency",
                    node_num=NUM_CORES,
                    original_event_count=original_event_count,
                    trace_id=mc_trace_id,
                    multicast_ratio=multicast_ratio,
                    mode="RU",
                    notes=[common_note, mc_note],
                )
                materialize_repeated_unicast_trace(ru_case, mc_events, packet_length)
                yield ru_case

                nm_case = Case(
                    name=f"VCTM-MC{multicast_ratio}-NM-{packet_length}f-{load_tag}",
                    group=VCTM_GROUP,
                    paper="VCTM",
                    traffic="uniform_random",
                    packet_length_or_distribution=f"{packet_length}_flits",
                    load_point=load_point,
                    load_unit="flit_per_cycle_node",
                    scale_type=scale_type,
                    paper_defined_scale="no",
                    latency_metric="network",
                    latency_metric_name="average_network_latency",
                    node_num=NUM_CORES,
                    original_event_count=original_event_count,
                    trace_id=mc_trace_id,
                    multicast_ratio=multicast_ratio,
                    mode="NM",
                    notes=[common_note, mc_note],
                )
                materialize_unicast_trace(nm_case, mc_events, packet_length)
                yield nm_case


def build_tab_cases(scale_type: str, load_points: tuple[float, ...], packet_counts: dict[int, int]) -> Iterable[Case]:
    common_note = "document node numbering follows the markdown table and is mapped internally onto physical core ports"

    for packet_length in TAB_PACKET_LENGTHS:
        packet_count = packet_counts[packet_length]
        for load_point in load_points:
            load_tag = load_to_tag(load_point)
            trace_id = f"tab_ur_{packet_length}f_{load_tag}_{scale_type}"
            tab_events = build_uniform_unicast_events(
                target_count=packet_count,
                packet_length=packet_length,
                load_point=load_point,
                schedule_seed=seed_from(TRACE_SEED_TAB, packet_length, int(round(load_point * 100))),
                traffic_seed=seed_from(TRACE_SEED_TAB ^ 0x10203040, packet_length, int(round(load_point * 100))),
            )
            case = Case(
                name=f"TAB-NET-UR-{packet_length}f-{load_tag}",
                group=TAB_GROUP,
                paper="TABULA_XPIPES",
                traffic="uniform_random",
                packet_length_or_distribution=f"{packet_length}_flits",
                load_point=load_point,
                load_unit="flit_per_cycle_node",
                scale_type=scale_type,
                paper_defined_scale="no",
                latency_metric="packet",
                latency_metric_name="average_packet_latency",
                node_num=NUM_CORES,
                original_event_count=packet_count,
                trace_id=trace_id,
                notes=[common_note],
            )
            materialize_unicast_trace(case, tab_events, packet_length)
            yield case


def build_cases(suite: str, scale_type: str, load_grid: str) -> Iterable[Case]:
    if scale_type == "validation":
        vctm_event_count = VALIDATION_EVENT_COUNTS["vctm"]
        tab_packet_counts = {
            3: VALIDATION_EVENT_COUNTS["tab_3f"],
            20: VALIDATION_EVENT_COUNTS["tab_20f"],
        }
    elif scale_type == "formal":
        load_points = FORMAL_LOAD_POINTS
        vctm_event_count = FORMAL_EVENT_COUNTS["vctm"]
        tab_packet_counts = {
            3: FORMAL_EVENT_COUNTS["tab_3f"],
            20: FORMAL_EVENT_COUNTS["tab_20f"],
        }
    else:
        raise ValueError(f"unsupported scale_type {scale_type}")

    if load_grid == "validation":
        load_points = VALIDATION_LOAD_POINTS
    elif load_grid == "formal":
        load_points = FORMAL_LOAD_POINTS
    else:
        raise ValueError(f"unsupported load_grid {load_grid}")

    if suite in ("all", "vctm"):
        yield from build_vctm_cases(scale_type, load_points, vctm_event_count)
    if suite in ("all", "tab"):
        yield from build_tab_cases(scale_type, load_points, tab_packet_counts)


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate doc-aligned SyncNoC16 testbench cases.")
    parser.add_argument("--suite", choices=["all", "vctm", "tab"], default="all")
    parser.add_argument("--scale", choices=["validation", "formal"], default="validation")
    parser.add_argument("--load-grid", choices=["validation", "formal"])
    parser.add_argument("--out-dir", type=Path, default=Path("sim/AsyncNoC/testbench/generated_cases"))
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    load_grid = args.load_grid if args.load_grid is not None else args.scale

    for case in build_cases(args.suite, args.scale, load_grid):
        write_case(case, args.out_dir, args.json)


if __name__ == "__main__":
    main()
