#!/usr/bin/env python3
"""Five-flit unicast/multicast cases for the 2x2 CMR TopMesh.

Destinations are global PE rectangles in 16x16 space (coordShift=3).
Scoreboard is tile-level: Local ingress does not return to the injecting
tile, matching RoutingLogic_mesh.
"""
from __future__ import annotations

import argparse
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
OUT = REPO / "sim" / "AsyncNoC" / "testbench" / "generated_cases_topmesh2"

GRID = 2
SHIFT = 3
PE_EDGE = GRID << SHIFT
PACKET_FLITS = 5
LANES = 2
DIR_W, DIR_S, DIR_E, DIR_N, DIR_L = 0, 1, 2, 3, 4
# Isolation of one 2-dest multicast finishes in ~5.2 us (~260 ticks at 20 ns).
# A 200-tick gap still overlaps at a dest Local; 1000 ticks drains first.
MIX_GAP_CYCLES = 1000
OVERLAP_GAP_CYCLES = 200


def make_flit(pkt_id: int, x0: int, y0: int, x1: int, y1: int, *, head: bool, tail: bool) -> int:
    flit = pkt_id & 0x3
    flit |= (x0 & 0x3F) << 2
    flit |= (y0 & 0x3F) << 8
    flit |= (x1 & 0x3F) << 14
    flit |= (y1 & 0x3F) << 20
    flit |= (1 if tail else 0) << 26
    flit |= (1 if head else 0) << 27
    return flit


def tile_xy(tile: int) -> tuple[int, int]:
    return tile % GRID, tile // GRID


def tile_index(tx: int, ty: int) -> int:
    return tx + GRID * ty


def inject_port(tile: int) -> int:
    return tile * LANES


def route_mask(cx: int, cy: int, ingress: int, x0: int, y0: int, x1: int, y1: int) -> int:
    x_lo = min(x0, x1) >> SHIFT
    x_hi = max(x0, x1) >> SHIFT
    y_lo = min(y0, y1) >> SHIFT
    y_hi = max(y0, y1) >> SHIFT
    in_col = x_lo <= cx <= x_hi
    in_row = y_lo <= cy <= y_hi
    local_hit = in_col and in_row

    def manhattan(tx: int, ty: int) -> int:
        return abs(cx - tx) + abs(cy - ty)

    d_ll = manhattan(x_lo, y_lo)
    d_lh = manhattan(x_lo, y_hi)
    d_hl = manhattan(x_hi, y_lo)
    d_hh = manhattan(x_hi, y_hi)
    best_left_y = y_hi if d_lh < d_ll else y_lo
    best_left_d = d_lh if d_lh < d_ll else d_ll
    best_right_y = y_hi if d_hh < d_hl else y_lo
    best_right_d = d_hh if d_hh < d_hl else d_hl
    target_x = x_hi if best_right_d < best_left_d else x_lo
    target_y = best_right_y if best_right_d < best_left_d else best_left_y
    east_needed = cx < x_hi
    west_needed = cx > x_lo
    north_needed = in_col and cy < y_hi
    south_needed = in_col and cy > y_lo
    go_w = go_s = go_e = go_n = go_l = False
    if not local_hit:
        if cx < target_x:
            go_e = True
        elif cx > target_x:
            go_w = True
        elif cy < target_y:
            go_n = True
        elif cy > target_y:
            go_s = True
    else:
        if ingress != DIR_L:
            go_l = True
        if ingress == DIR_W:
            go_e, go_n, go_s = east_needed, north_needed, south_needed
        elif ingress == DIR_E:
            go_w, go_n, go_s = west_needed, north_needed, south_needed
        elif ingress == DIR_N:
            if cy == y_hi:
                go_w, go_e = west_needed, east_needed
            go_s = south_needed
        elif ingress == DIR_S:
            if cy == y_lo:
                go_w, go_e = west_needed, east_needed
            go_n = north_needed
        elif ingress == DIR_L:
            if cx < x_lo:
                go_e = True
            elif cx > x_hi:
                go_w = True
            else:
                go_w, go_e = west_needed, east_needed
            go_n, go_s = north_needed, south_needed
    if cx == 0:
        go_w = False
    if cx == GRID - 1:
        go_e = False
    if cy == 0:
        go_s = False
    if cy == GRID - 1:
        go_n = False
    return (
        (1 << DIR_W if go_w else 0)
        | (1 << DIR_S if go_s else 0)
        | (1 << DIR_E if go_e else 0)
        | (1 << DIR_N if go_n else 0)
        | (1 << DIR_L if go_l else 0)
    )


def walk_dest_tiles(src_tile: int, x0: int, y0: int, x1: int, y1: int) -> list[int]:
    sx, sy = tile_xy(src_tile)
    delivered: set[int] = set()
    seen: set[tuple[int, int, int]] = set()
    queue = [(sx, sy, DIR_L)]
    hops = 0
    while queue:
        hops += 1
        if hops > 64:
            raise RuntimeError("topmesh walk exceeded 64 hops")
        cx, cy, ingress = queue.pop(0)
        key = (cx, cy, ingress)
        if key in seen:
            continue
        seen.add(key)
        mask = route_mask(cx, cy, ingress, x0, y0, x1, y1)
        if mask & (1 << DIR_L):
            delivered.add(tile_index(cx, cy))
        neighbors = (
            (DIR_W, cx - 1, cy, DIR_E),
            (DIR_E, cx + 1, cy, DIR_W),
            (DIR_S, cx, cy - 1, DIR_N),
            (DIR_N, cx, cy + 1, DIR_S),
        )
        for bit, nx, ny, opp in neighbors:
            if mask & (1 << bit) and 0 <= nx < GRID and 0 <= ny < GRID:
                queue.append((nx, ny, opp))
    return sorted(delivered)


def flits_for(pkt_seq: int, x0: int, y0: int, x1: int, y1: int) -> list[int]:
    return [
        make_flit(
            pkt_seq,
            x0,
            y0,
            x1,
            y1,
            head=(idx == 0),
            tail=(idx == PACKET_FLITS - 1),
        )
        for idx in range(PACKET_FLITS)
    ]


def add_packet(
    packets: list[dict],
    *,
    src_tile: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    kind: str,
    start_cycle: int,
) -> int:
    dests = walk_dest_tiles(src_tile, x0, y0, x1, y1)
    if not dests:
        raise ValueError(
            "no TopMesh Local delivery src=%d rect=(%d,%d)-(%d,%d)"
            % (src_tile, x0, y0, x1, y1)
        )
    packets.append(
        {
            "src_tile": src_tile,
            "port": inject_port(src_tile),
            "rect": (x0, y0, x1, y1),
            "dest_tiles": dests,
            "kind": kind,
            "start_cycle": start_cycle,
            "flits": flits_for(len(packets), x0, y0, x1, y1),
        }
    )
    return start_cycle + PACKET_FLITS


def write_case(name: list | str, group: str, packets: list[dict], path: Path) -> None:
    case_name = name if isinstance(name, str) else name
    lines = [
        "# Generated by scripts/asic_dc/cmr/gen_topmesh2_cases.py",
        "case %s" % case_name,
        "group %s" % group,
        "reset_cycles 10",
        "timeout_cycles 200000",
        "meta paper DATE_V3",
        "meta dut CMRTopMesh_2x2",
        "meta packet_flits %d" % PACKET_FLITS,
        "meta tiles 4",
        "meta lanes %d" % LANES,
        "# input       <cycle> <port> <pkt_seq> <flit_hex>",
        "# expect_tile <tile> <pkt_seq> <is_tail> <flit_hex>",
    ]
    for pkt_seq, packet in enumerate(packets):
        lines.append(
            "# %s src_tile=%d rect=%s dest_tiles=%s"
            % (packet["kind"], packet["src_tile"], packet["rect"], packet["dest_tiles"])
        )
        for idx, flit in enumerate(packet["flits"]):
            lines.append(
                "input %6d %2d %6d %07x # pkt%d flit%d"
                % (packet["start_cycle"] + idx, packet["port"], pkt_seq, flit, pkt_seq, idx)
            )
            for tile in packet["dest_tiles"]:
                lines.append(
                    "expect_tile %2d %6d %d %07x # pkt%d dst_tile=%d"
                    % (
                        tile,
                        pkt_seq,
                        1 if idx == PACKET_FLITS - 1 else 0,
                        flit,
                        pkt_seq,
                        tile,
                    )
                )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("CASE", path, "packets", len(packets))


def directed_unicast() -> list[dict]:
    packets: list[dict] = []
    cycle = 0
    for src, dest in (
        (0, (8, 0, 8, 0)),
        (0, (0, 8, 0, 8)),
        (0, (15, 15, 15, 15)),
        (1, (0, 0, 0, 0)),
        (2, (8, 0, 8, 0)),
        (3, (0, 0, 0, 0)),
        (3, (8, 0, 8, 0)),
        (1, (0, 15, 0, 15)),
    ):
        cycle = add_packet(packets, src_tile=src, x0=dest[0], y0=dest[1], x1=dest[2], y1=dest[3], kind="uc", start_cycle=cycle) + 40
    return packets


def directed_multicast() -> list[dict]:
    packets: list[dict] = []
    cycle = 0
    for src, dest in (
        (0, (0, 0, 15, 0)),
        (0, (0, 0, 0, 15)),
        (0, (0, 0, 15, 15)),
        (0, (8, 0, 15, 15)),
        (3, (0, 0, 15, 15)),
        (1, (0, 8, 15, 15)),
        (2, (0, 0, 15, 7)),
    ):
        cycle = add_packet(packets, src_tile=src, x0=dest[0], y0=dest[1], x1=dest[2], y1=dest[3], kind="mc", start_cycle=cycle) + 50
    return packets


def random_mix(seed: int = 20260901, count: int = 48) -> list[dict]:
    import random

    rng = random.Random(seed)
    packets: list[dict] = []
    cycle = 0
    attempts = 0
    while len(packets) < count and attempts < 4000:
        attempts += 1
        src = rng.randrange(4)
        if rng.random() < 0.55:
            dx = rng.randrange(PE_EDGE)
            dy = rng.randrange(PE_EDGE)
            if (dx >> SHIFT, dy >> SHIFT) == tile_xy(src):
                continue
            rect = (dx, dy, dx, dy)
            kind = "uc"
        else:
            x0 = rng.randrange(PE_EDGE)
            y0 = rng.randrange(PE_EDGE)
            x1 = rng.randrange(PE_EDGE)
            y1 = rng.randrange(PE_EDGE)
            rect = (x0, y0, x1, y1)
            kind = "mc"
        try:
            cycle = add_packet(
                packets,
                src_tile=src,
                x0=rect[0],
                y0=rect[1],
                x1=rect[2],
                y1=rect[3],
                kind=kind,
                start_cycle=cycle,
            ) + MIX_GAP_CYCLES
        except ValueError:
            continue
    if len(packets) != count:
        raise SystemExit("random mix only produced %d packets" % len(packets))
    return packets


def overlap_p32_34() -> list[dict]:
    """Same three packets that surround the mix miss, at the old 200-tick gap."""
    packets: list[dict] = []
    cycle = 0
    for src, dest, kind in (
        (3, (7, 5, 3, 12), "mc"),
        (0, (7, 8, 7, 8), "uc"),
        (1, (12, 8, 2, 15), "mc"),
    ):
        cycle = add_packet(
            packets,
            src_tile=src,
            x0=dest[0],
            y0=dest[1],
            x1=dest[2],
            y1=dest[3],
            kind=kind,
            start_cycle=cycle,
        ) + OVERLAP_GAP_CYCLES
    return packets


def slice_packets(packets: list[dict], start: int, end: int, gap: int) -> list[dict]:
    out: list[dict] = []
    cycle = 0
    for packet in packets[start:end]:
        cloned = dict(packet)
        cloned["start_cycle"] = cycle
        out.append(cloned)
        cycle += PACKET_FLITS + gap
    return out


def self_check() -> None:
    assert walk_dest_tiles(0, 8, 0, 8, 0) == [1]
    assert walk_dest_tiles(0, 0, 8, 0, 8) == [2]
    assert walk_dest_tiles(0, 15, 15, 15, 15) == [3]
    assert walk_dest_tiles(0, 0, 0, 15, 0) == [1]
    assert 1 in walk_dest_tiles(0, 0, 0, 15, 15)
    assert 2 in walk_dest_tiles(0, 0, 0, 15, 15)
    assert 3 in walk_dest_tiles(0, 0, 0, 15, 15)
    assert 0 not in walk_dest_tiles(0, 0, 0, 15, 15)
    print("SELF_CHECK_PASS")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    self_check()
    write_case("tm2_directed_uc", "TOPMESH2", directed_unicast(), args.out / "tm2_directed_uc.case")
    write_case("tm2_directed_mc", "TOPMESH2", directed_multicast(), args.out / "tm2_directed_mc.case")
    mix = random_mix()
    write_case("tm2_random_mix", "TOPMESH2", mix, args.out / "tm2_random_mix.case")
    isolate: list[dict] = []
    add_packet(isolate, src_tile=1, x0=12, y0=8, x1=2, y1=15, kind="mc", start_cycle=0)
    write_case("tm2_iso_p34", "TOPMESH2", isolate, args.out / "tm2_iso_p34.case")
    write_case("tm2_overlap_p32_34", "TOPMESH2", overlap_p32_34(), args.out / "tm2_overlap_p32_34.case")
    mix = random_mix()
    write_case("tm2_prefix_p34", "TOPMESH2", slice_packets(mix, 0, 35, MIX_GAP_CYCLES), args.out / "tm2_prefix_p34.case")
    write_case("tm2_late_p34", "TOPMESH2", slice_packets(mix, 26, 35, MIX_GAP_CYCLES), args.out / "tm2_late_p34.case")
    write_case(
        "tm2_p26_then_p34",
        "TOPMESH2",
        slice_packets([mix[26], mix[34]], 0, 2, MIX_GAP_CYCLES),
        args.out / "tm2_p26_then_p34.case",
    )
    write_case("tm2_from13_p34", "TOPMESH2", slice_packets(mix, 13, 35, MIX_GAP_CYCLES), args.out / "tm2_from13_p34.case")
    write_case("tm2_from20_p34", "TOPMESH2", slice_packets(mix, 20, 35, MIX_GAP_CYCLES), args.out / "tm2_from20_p34.case")
    write_case("tm2_from6_p34", "TOPMESH2", slice_packets(mix, 6, 35, MIX_GAP_CYCLES), args.out / "tm2_from6_p34.case")
    write_case("tm2_from10_p34", "TOPMESH2", slice_packets(mix, 10, 35, MIX_GAP_CYCLES), args.out / "tm2_from10_p34.case")
    write_case("tm2_from3_p34", "TOPMESH2", slice_packets(mix, 3, 35, MIX_GAP_CYCLES), args.out / "tm2_from3_p34.case")
    write_case(
        "tm2_early_then_p34",
        "TOPMESH2",
        slice_packets(mix[0:6] + [mix[34]], 0, 7, MIX_GAP_CYCLES),
        args.out / "tm2_early_then_p34.case",
    )
    write_case("tm2_from4_p34", "TOPMESH2", slice_packets(mix, 4, 35, MIX_GAP_CYCLES), args.out / "tm2_from4_p34.case")
    write_case("tm2_from5_p34", "TOPMESH2", slice_packets(mix, 5, 35, MIX_GAP_CYCLES), args.out / "tm2_from5_p34.case")
    write_case(
        "tm2_p3_then_p34",
        "TOPMESH2",
        slice_packets([mix[3], mix[34]], 0, 2, MIX_GAP_CYCLES),
        args.out / "tm2_p3_then_p34.case",
    )
    write_case(
        "tm2_p3to5_then_p34",
        "TOPMESH2",
        slice_packets(mix[3:6] + [mix[34]], 0, 4, MIX_GAP_CYCLES),
        args.out / "tm2_p3to5_then_p34.case",
    )
    write_case(
        "tm2_p3to12_then_p34",
        "TOPMESH2",
        slice_packets(mix[3:13] + [mix[34]], 0, 11, MIX_GAP_CYCLES),
        args.out / "tm2_p3to12_then_p34.case",
    )
    write_case(
        "tm2_p3_plus_from13",
        "TOPMESH2",
        slice_packets([mix[3]] + mix[13:35], 0, 23, MIX_GAP_CYCLES),
        args.out / "tm2_p3_plus_from13.case",
    )
    write_case(
        "tm2_p3_p4_then_p34",
        "TOPMESH2",
        slice_packets([mix[3], mix[4], mix[34]], 0, 3, MIX_GAP_CYCLES),
        args.out / "tm2_p3_p4_then_p34.case",
    )
    write_case("tm2_mix_s2", "TOPMESH2", random_mix(seed=20260902), args.out / "tm2_mix_s2.case")
    write_case("tm2_mix_s7", "TOPMESH2", random_mix(seed=7), args.out / "tm2_mix_s7.case")
    write_case("tm2_mix_s42", "TOPMESH2", random_mix(seed=42), args.out / "tm2_mix_s42.case")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
