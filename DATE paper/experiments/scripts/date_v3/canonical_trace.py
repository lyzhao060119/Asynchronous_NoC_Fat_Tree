"""DATE V3 canonical original-event traces.

Paired designs share one JSONL.  H-REP split happens only at materialize time.
Packet length is locked to 5 flits.  Do not route this through gen_cases_noc64.py.
"""
from __future__ import annotations

import json
from collections import defaultdict, deque
from pathlib import Path
from random import Random
from typing import Any, Iterable

from .hashutil import sha256_text
from .hrep_policy import cluster_of_pe, pe_index, pe_xy
from .paths import BENCHMARKS, SEEDS

PACKET_FLITS = 5
TILE = 8
COARSE_LOADS = (0.02, 0.05, 0.10, 0.20, 0.30, 0.40, 0.50)
ZERO_LOAD = 0.0
ZERO_LOAD_GAP = 256
XMC_GAP = 64
TRACE_SCHEMA = "date-v3-canonical-trace-v1"
EVENT_SCHEMA = "date-v3-canonical-event-v1"


def load_seeds(seed_set_id: str = "v3_main_seeds") -> list[int]:
    obj = json.loads((SEEDS / ("%s.json" % seed_set_id)).read_text(encoding="utf-8"))
    if obj.get("seed_set_id") != seed_set_id:
        raise ValueError("seed file mismatch")
    return list(obj["seeds"])


def load_benchmark(benchmark_id: str) -> dict[str, Any]:
    for path in BENCHMARKS.glob("*.json"):
        obj = json.loads(path.read_text(encoding="utf-8"))
        if obj.get("benchmark_id") == benchmark_id:
            return obj
    raise KeyError("unknown benchmark %s" % benchmark_id)


def seed_mix(base: int, *parts: int) -> int:
    seed = base & 0xFFFFFFFF
    for part in parts:
        seed = (seed * 1664525 + 1013904223 + (part & 0xFFFFFFFF)) & 0xFFFFFFFF
    return seed


def width_of(nodes: int) -> int:
    side = int(round(nodes ** 0.5))
    if side * side != nodes:
        raise ValueError("nodes must be a square, got %s" % nodes)
    return side


def cluster_grid_of(nodes: int, tile: int = TILE) -> int:
    width = width_of(nodes)
    if width % tile != 0:
        raise ValueError("width %s is not a multiple of tile %s" % (width, tile))
    return width // tile


def load_tag(load_point: float) -> str:
    if load_point <= 0.0:
        return "zero"
    whole = int(load_point)
    frac = int(round((load_point - whole) * 100))
    return "r%dp%02d" % (whole, frac)


def l2_key(pe: int, width: int, tile: int = TILE) -> tuple[int, int, int, int]:
    x, y = pe_xy(pe, width)
    return (x // tile, y // tile, (x % tile) >> 2, (y % tile) >> 2)


def same_l2_subtree(a: int, b: int, width: int) -> bool:
    return l2_key(a, width) == l2_key(b, width)


def bounding_rect(dests: Iterable[int], width: int) -> list[int]:
    xs = [pe_xy(d, width)[0] for d in dests]
    ys = [pe_xy(d, width)[1] for d in dests]
    return [min(xs), min(ys), max(xs), max(ys)]


def cores_in_rect(rect: list[int] | tuple[int, int, int, int], width: int) -> list[int]:
    x0, y0, x1, y1 = min(rect[0], rect[2]), min(rect[1], rect[3]), max(rect[0], rect[2]), max(rect[1], rect[3])
    return [
        pe_index(x, y, width)
        for y in range(y0, y1 + 1)
        for x in range(x0, x1 + 1)
    ]


def choose_other(rng: Random, source: int, n: int) -> int:
    dest = rng.randrange(n - 1)
    return dest if dest < source else dest + 1


def choose_bf_dest(rng: Random, source: int, n: int) -> int:
    width = width_of(n)
    choices = [d for d in range(n) if d != source and not same_l2_subtree(d, source, width)]
    if not choices:
        raise RuntimeError("no BF-STRESS destination for source %s" % source)
    return rng.choice(choices)


def choose_intercluster_dest(rng: Random, source: int, n: int) -> int:
    width = width_of(n)
    src_c = cluster_of_pe(source, width)
    choices = [d for d in range(n) if cluster_of_pe(d, width) != src_c]
    if not choices:
        raise RuntimeError("no inter-cluster destination for source %s" % source)
    return rng.choice(choices)


def sample_xmc_dests(
    rng: Random,
    source: int,
    *,
    fanout: int,
    spread: int,
    nodes: int,
) -> list[int]:
    width = width_of(nodes)
    grid = cluster_grid_of(nodes)
    src_c = cluster_of_pe(source, width)
    clusters = [(tx, ty) for ty in range(grid) for tx in range(grid)]
    for _ in range(128):
        if spread == 1:
            dest_clusters = [c for c in clusters if c != src_c] or clusters
            tx, ty = dest_clusters[rng.randrange(len(dest_clusters))]
            ox = rng.randint(0, TILE - 4)
            oy = rng.randint(0, TILE - 4)
            dests = [
                pe_index(tx * TILE + x, ty * TILE + y, width)
                for y in range(oy, oy + 4)
                for x in range(ox, ox + 4)
            ]
        elif spread == 4:
            if grid < 2:
                raise ValueError("S=4 needs at least a 2x2 cluster grid")
            jx = rng.randint(1, grid - 1) * TILE
            jy = rng.randint(1, grid - 1) * TILE
            dests = cores_in_rect((jx - 2, jy - 2, jx + 1, jy + 1), width)
        elif spread == 16:
            if grid * grid < 16:
                raise ValueError("S=16 needs 16 clusters")
            dests = []
            for cluster in clusters:
                pes = [
                    pe_index(cluster[0] * TILE + x, cluster[1] * TILE + y, width)
                    for y in range(TILE)
                    for x in range(TILE)
                    if pe_index(cluster[0] * TILE + x, cluster[1] * TILE + y, width) != source
                ]
                dests.append(rng.choice(pes))
        else:
            raise ValueError("unsupported spread S=%s" % spread)
        dests = [d for d in dests if d != source]
        if spread == 16 and len(dests) == fanout:
            return dests
        if spread in (1, 4) and len(dests) == fanout:
            return dests
    raise RuntimeError("could not sample XMC dests F=%s S=%s" % (fanout, spread))


def draw_pairs(
    traffic: str,
    nodes: int,
    count: int,
    rng: Random,
    *,
    spread: int | None = None,
    multicast_fraction: float = 0.0,
    fanout: int = 16,
) -> list[dict[str, Any]]:
    width = width_of(nodes)
    pairs: list[dict[str, Any]] = []
    for _ in range(count):
        source = rng.randrange(nodes)
        multicast = False
        if traffic == "bf_stress64":
            dests = [choose_bf_dest(rng, source, nodes)]
        elif traffic == "topo_ur":
            dests = [choose_other(rng, source, nodes)]
        elif traffic == "mesh_intercluster_ur":
            dests = [choose_intercluster_dest(rng, source, nodes)]
        elif traffic == "xmc_f16":
            if spread is None:
                raise ValueError("xmc_f16 needs spread S")
            dests = sample_xmc_dests(rng, source, fanout=fanout, spread=spread, nodes=nodes)
            multicast = True
        elif traffic == "xmc10_g":
            multicast = rng.random() < multicast_fraction
            if multicast:
                dests = sample_xmc_dests(
                    rng, source, fanout=fanout, spread=spread or 4, nodes=nodes
                )
            else:
                dests = [choose_other(rng, source, nodes)]
        else:
            raise ValueError("unsupported traffic %s" % traffic)
        pairs.append(
            {
                "source": source,
                "destinations": dests,
                "rect": bounding_rect(dests, width),
                "multicast": multicast or len(dests) > 1,
            }
        )
    return pairs


def schedule_pairs(
    pairs: list[dict[str, Any]],
    *,
    nodes: int,
    packet_flits: int,
    load_point: float,
    rng: Random,
) -> list[int]:
    if load_point <= 0.0:
        return [idx * (packet_flits + ZERO_LOAD_GAP) for idx in range(len(pairs))]
    start_prob = load_point / packet_flits
    if not (0.0 < start_prob <= 1.0):
        raise ValueError("bad packet-start probability %s" % start_prob)
    queues: dict[int, deque[int]] = defaultdict(deque)
    for idx, pair in enumerate(pairs):
        queues[pair["source"]].append(idx)
    ready = [-1] * len(pairs)
    busy_until = [0] * nodes
    placed = 0
    cycle = 0
    while placed < len(pairs):
        for source in range(nodes):
            if cycle < busy_until[source] or not queues[source]:
                continue
            if rng.random() < start_prob:
                idx = queues[source].popleft()
                ready[idx] = cycle
                busy_until[source] = cycle + packet_flits
                placed += 1
                if placed >= len(pairs):
                    break
        cycle += 1
        if cycle > 10_000_000:
            raise RuntimeError("schedule did not finish")
    return ready


def build_events(
    pairs: list[dict[str, Any]],
    ready: list[int],
    *,
    warmup: int,
    packet_flits: int,
) -> list[dict[str, Any]]:
    events = []
    for idx, pair in enumerate(pairs):
        phase = "warmup" if idx < warmup else "measurement"
        events.append(
            {
                "schema": EVENT_SCHEMA,
                "original_event_id": "e%06d" % idx,
                "event_index": idx,
                "phase": phase,
                "source": pair["source"],
                "destinations": list(pair["destinations"]),
                "rect": list(pair["rect"]),
                "multicast": bool(pair["multicast"]),
                "ready_cycle": ready[idx],
                "packet_flits": packet_flits,
            }
        )
    return events


def generate_trace(
    benchmark_id: str,
    *,
    seed: int,
    nodes: int | None = None,
    load_point: float = 0.10,
    warmup: int | None = None,
    measurement: int | None = None,
    spread: int | None = None,
    smoke: bool = False,
) -> dict[str, Any]:
    bench = load_benchmark(benchmark_id)
    packet_flits = int(bench["packet_flits"])
    if packet_flits != PACKET_FLITS:
        raise ValueError("%s packet_flits=%s, V3 main path is 5" % (benchmark_id, packet_flits))
    if smoke:
        warmup = 0 if bench["warmup_original_events"] == 0 else 4
        measurement = 8 if bench["measurement_original_events"] >= 8 else int(bench["measurement_original_events"])
        if benchmark_id == "XMC-F16":
            warmup, measurement = 0, min(8, int(bench["measurement_original_events"]))
    else:
        warmup = bench["warmup_original_events"] if warmup is None else warmup
        measurement = bench["measurement_original_events"] if measurement is None else measurement
    traffic = bench["traffic"]
    if nodes is None:
        if traffic == "bf_stress64":
            nodes = 64
        elif traffic in ("xmc_f16", "xmc10_g", "mesh_intercluster_ur"):
            nodes = 1024
        else:
            nodes = 64
    if traffic == "bf_stress64" and nodes != 64:
        raise ValueError("BF-STRESS64 is 64-node only")
    if traffic == "xmc_f16" and not smoke and measurement < 32:
        raise ValueError("XMC-F16 needs at least 32 destination-set samples")
    if traffic == "xmc_f16":
        if spread is None:
            raise ValueError("XMC-F16 needs spread S")
        load_point = 0.0
    dest_rng = Random(seed_mix(seed, nodes, spread or 0, 1))
    pairs = draw_pairs(
        traffic,
        nodes,
        warmup + measurement,
        dest_rng,
        spread=spread,
        multicast_fraction=float(bench.get("multicast_fraction") or 0.0),
        fanout=int(bench["fanout_F"] or 16),
    )
    if traffic in ("xmc_f16",) or load_point <= 0.0:
        gap = XMC_GAP if traffic == "xmc_f16" else ZERO_LOAD_GAP
        ready = [idx * (packet_flits + gap) for idx in range(len(pairs))]
    else:
        sched_rng = Random(seed_mix(seed, nodes, spread or 0, load_tag_int(load_point)))
        ready = schedule_pairs(
            pairs, nodes=nodes, packet_flits=packet_flits, load_point=load_point, rng=sched_rng
        )
    events = build_events(pairs, ready, warmup=warmup, packet_flits=packet_flits)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": benchmark_id,
        "traffic": traffic,
        "nodes": nodes,
        "seed": seed,
        "seed_set_id": bench["seed_set_id"],
        "packet_flits": packet_flits,
        "warmup_original_events": warmup,
        "measurement_original_events": measurement,
        "offered_load": load_point,
        "load_tag": load_tag(load_point),
        "spread_S": spread,
        "paired_trace": True,
        "tmax_definition": bench.get("tmax_definition"),
    }
    return {"header": header, "events": events}


def load_tag_int(load_point: float) -> int:
    return int(round(load_point * 1000))


def paper_nodes_for(benchmark_id: str) -> list[int]:
    """Node counts the paper path must emit for one canonical-trace family."""
    if benchmark_id == "BF-STRESS64":
        return [64]
    if benchmark_id == "TOPO-UR":
        return [64, 256, 1024]
    if benchmark_id in ("XMC-F16", "XMC10-G", "MESH-INTERCLUSTER-UR"):
        return [1024]
    if benchmark_id == "KEY-256":
        return [256]
    return [64]


def trace_id(header: dict[str, Any]) -> str:
    parts = [
        header["benchmark_id"],
        "n%d" % header["nodes"],
        "s%d" % header["seed"],
        header["load_tag"],
    ]
    if header.get("spread_S") is not None:
        parts.append("S%d" % header["spread_S"])
    return "_".join(parts)


def dump_jsonl(trace: dict[str, Any], path: Path) -> str:
    header = dict(trace["header"])
    header["trace_id"] = trace_id(header)
    header.pop("trace_hash", None)
    event_lines = [json.dumps(event, sort_keys=True) for event in trace["events"]]
    body = json.dumps(header, sort_keys=True) + "\n" + "\n".join(event_lines) + "\n"
    digest = sha256_text(body)
    header["trace_hash"] = digest
    text = json.dumps(header, sort_keys=True) + "\n" + "\n".join(event_lines) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    return digest


def load_jsonl(path: Path) -> dict[str, Any]:
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]
    header = json.loads(lines[0])
    events = [json.loads(line) for line in lines[1:]]
    return {"header": header, "events": events}


def cluster_corners(cluster_grid: int) -> list[tuple[int, int]]:
    corners = []
    for ty in range(cluster_grid):
        for tx in range(cluster_grid):
            x0, y0 = tx * TILE, ty * TILE
            corners.extend(
                [
                    (x0, y0),
                    (x0 + TILE - 1, y0),
                    (x0, y0 + TILE - 1),
                    (x0 + TILE - 1, y0 + TILE - 1),
                ]
            )
    return corners


def generate_directed_keycase(
    *,
    nodes: int,
    seed: int,
    random_unicasts: int = 200,
    packet_flits: int = PACKET_FLITS,
) -> dict[str, Any]:
    """256-node directed corners + random unicasts.  Not a paper load sweep."""
    width = width_of(nodes)
    grid = cluster_grid_of(nodes)
    pairs: list[dict[str, Any]] = []
    seen: set[tuple[int, int]] = set()
    for sx, sy in cluster_corners(grid):
        src = pe_index(sx, sy, width)
        for dx, dy in cluster_corners(grid):
            if sx == dx and sy == dy:
                continue
            dest = pe_index(dx, dy, width)
            key = (src, dest)
            if key in seen:
                continue
            seen.add(key)
            pairs.append(
                {
                    "source": src,
                    "destinations": [dest],
                    "rect": bounding_rect([dest], width),
                    "multicast": False,
                }
            )
    rng = Random(seed_mix(seed, nodes, 0, 9))
    added = 0
    spins = 0
    while added < random_unicasts and spins < random_unicasts * 32:
        spins += 1
        src = rng.randrange(nodes)
        dest = choose_other(rng, src, nodes)
        key = (src, dest)
        if key in seen:
            continue
        seen.add(key)
        pairs.append(
            {
                "source": src,
                "destinations": [dest],
                "rect": bounding_rect([dest], width),
                "multicast": False,
            }
        )
        added += 1
    ready = [idx * (packet_flits + ZERO_LOAD_GAP) for idx in range(len(pairs))]
    events = build_events(pairs, ready, warmup=0, packet_flits=packet_flits)
    header = {
        "schema": TRACE_SCHEMA,
        "kind": "header",
        "benchmark_id": "KEY-256",
        "traffic": "directed_keycase",
        "nodes": nodes,
        "seed": seed,
        "seed_set_id": "v3_main_seeds",
        "packet_flits": packet_flits,
        "warmup_original_events": 0,
        "measurement_original_events": len(events),
        "offered_load": 0.0,
        "load_tag": "zero",
        "spread_S": None,
        "paired_trace": True,
        "tmax_definition": "last destination tail minus source header injection",
    }
    return {"header": header, "events": events}
