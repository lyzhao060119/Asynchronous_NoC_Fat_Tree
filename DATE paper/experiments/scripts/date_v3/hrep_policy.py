"""H-REP cluster-boundary split.  Same netlist as PROP; injection only."""
from __future__ import annotations

from typing import Iterable

TILE = 8


def pe_xy(index: int, width: int) -> tuple[int, int]:
    return index % width, index // width


def pe_index(x: int, y: int, width: int) -> int:
    return x + width * y


def cluster_of(x: int, y: int, tile: int = TILE) -> tuple[int, int]:
    return x // tile, y // tile


def cluster_of_pe(index: int, width: int, tile: int = TILE) -> tuple[int, int]:
    x, y = pe_xy(index, width)
    return cluster_of(x, y, tile)


def cluster_rect(cluster: tuple[int, int], tile: int = TILE) -> tuple[int, int, int, int]:
    tx, ty = cluster
    return tx * tile, ty * tile, tx * tile + tile - 1, ty * tile + tile - 1


def intersect(
    a: tuple[int, int, int, int], b: tuple[int, int, int, int]
) -> tuple[int, int, int, int] | None:
    ax0, ay0, ax1, ay1 = min(a[0], a[2]), min(a[1], a[3]), max(a[0], a[2]), max(a[1], a[3])
    bx0, by0, bx1, by1 = min(b[0], b[2]), min(b[1], b[3]), max(b[0], b[2]), max(b[1], b[3])
    x0, y0 = max(ax0, bx0), max(ay0, by0)
    x1, y1 = min(ax1, bx1), min(ay1, by1)
    if x0 <= x1 and y0 <= y1:
        return x0, y0, x1, y1
    return None


def split_dest_set(
    original_event_id: str,
    source: int,
    destinations: Iterable[int],
    cluster_grid: int,
    tile: int = TILE,
) -> list[dict]:
    width = cluster_grid * tile
    src_cluster = cluster_of_pe(source, width, tile)
    unique = sorted({d for d in destinations if d != source})
    groups: dict[tuple[int, int], list[int]] = {}
    for dest in unique:
        groups.setdefault(cluster_of_pe(dest, width, tile), []).append(dest)
    packets = []
    for idx, cluster in enumerate(sorted(groups)):
        dests = sorted(groups[cluster])
        xs = [pe_xy(d, width)[0] for d in dests]
        ys = [pe_xy(d, width)[1] for d in dests]
        packets.append(
            {
                "original_event_id": original_event_id,
                "packet_id": "%s#%d" % (original_event_id, idx),
                "source": source,
                "destinations": dests,
                "rect": [min(xs), min(ys), max(xs), max(ys)],
                "target_cluster": list(cluster),
                "crosses_top_mesh": cluster != src_cluster,
            }
        )
    return packets


def split_rectangle(
    original_event_id: str,
    source: int,
    rect: tuple[int, int, int, int],
    cluster_grid: int,
    tile: int = TILE,
) -> list[dict]:
    width = cluster_grid * tile
    src_cluster = cluster_of_pe(source, width, tile)
    x0, y0, x1, y1 = min(rect[0], rect[2]), min(rect[1], rect[3]), max(rect[0], rect[2]), max(rect[1], rect[3])
    packets = []
    idx = 0
    for ty in range(y0 // tile, y1 // tile + 1):
        for tx in range(x0 // tile, x1 // tile + 1):
            clipped = intersect((x0, y0, x1, y1), cluster_rect((tx, ty), tile))
            if clipped is None:
                continue
            dests = [
                pe_index(x, y, width)
                for y in range(clipped[1], clipped[3] + 1)
                for x in range(clipped[0], clipped[2] + 1)
                if pe_index(x, y, width) != source
            ]
            if not dests:
                continue
            packets.append(
                {
                    "original_event_id": original_event_id,
                    "packet_id": "%s#%d" % (original_event_id, idx),
                    "source": source,
                    "destinations": dests,
                    "rect": list(clipped),
                    "target_cluster": [tx, ty],
                    "crosses_top_mesh": (tx, ty) != src_cluster,
                }
            )
            idx += 1
    return packets


def prop_packet(
    original_event_id: str,
    source: int,
    destinations: Iterable[int],
    width: int,
    tile: int = TILE,
) -> dict:
    dests = sorted({d for d in destinations if d != source})
    if not dests:
        raise ValueError("PROP packet needs at least one destination")
    xs = [pe_xy(d, width)[0] for d in dests]
    ys = [pe_xy(d, width)[1] for d in dests]
    src_cluster = cluster_of_pe(source, width, tile)
    return {
        "original_event_id": original_event_id,
        "packet_id": "%s#0" % original_event_id,
        "source": source,
        "destinations": dests,
        "rect": [min(xs), min(ys), max(xs), max(ys)],
        "target_cluster": list(cluster_of_pe(dests[0], width, tile)),
        "crosses_top_mesh": any(cluster_of_pe(d, width, tile) != src_cluster for d in dests),
    }
