"""Python twin of `CMRNetworkRouteOracle` for V3 event-record traversal.

Counts actual router/link visits from the same L1/L2/L3/mesh masks the
Scala DUT uses.  Do not substitute Manhattan hop count.
"""
from __future__ import annotations

from collections import deque
from typing import Any, Iterable

from .hrep_policy import pe_index, pe_xy

DIR_WEST = 0
DIR_SOUTH = 1
DIR_EAST = 2
DIR_NORTH = 3
DIR_PARENT = 4
TILE = 8
COORD_SHIFT = 3
MAX_HOPS = 64


def opposite(direction: int) -> int:
    return {DIR_WEST: DIR_EAST, DIR_EAST: DIR_WEST, DIR_SOUTH: DIR_NORTH, DIR_NORTH: DIR_SOUTH}.get(
        direction, direction
    )


def core_dir(x: int, y: int) -> int:
    odd_x = (x & 1) != 0
    odd_y = (y & 1) != 0
    if odd_x and odd_y:
        return 0
    if odd_x and not odd_y:
        return 1
    if (not odd_x) and odd_y:
        return 2
    return 3


def core_at(l1x: int, l1y: int, direction: int) -> tuple[int, int]:
    gx0, gy0 = l1x * 2, l1y * 2
    if direction == 0:
        return gx0 + 1, gy0 + 1
    if direction == 1:
        return gx0 + 1, gy0
    if direction == 2:
        return gx0, gy0 + 1
    if direction == 3:
        return gx0, gy0
    raise ValueError("not a child dir: %s" % direction)


def parent_child_dir(child_x: int, child_y: int) -> int:
    selector = ((child_x & 1) << 1) | (child_y & 1)
    return (~selector) & 0x3


def l2_child_l1(l2x: int, l2y: int, direction: int) -> tuple[int, int]:
    selector = (~direction) & 0x3
    return 2 * l2x + ((selector >> 1) & 1), 2 * l2y + (selector & 1)


def l3_child_l2(l3x: int, l3y: int, direction: int) -> tuple[int, int]:
    selector = (~direction) & 0x3
    return 2 * l3x + ((selector >> 1) & 1), 2 * l3y + (selector & 1)


def _bits(mask: int) -> list[int]:
    return [bit for bit in range(5) if (mask >> bit) & 1]


def mask_l1(coordinate_x: int, coordinate_y: int, ingress_dir: int, x0: int, y0: int, x1: int, y1: int) -> int:
    x0, y0, x1, y1 = x0 & 0x3F, y0 & 0x3F, x1 & 0x3F, y1 & 0x3F
    tree_x = (coordinate_x >> 2) & 0x3
    tree_y = (coordinate_y >> 2) & 0x3
    local_x = coordinate_x & 0x3
    local_y = coordinate_y & 0x3
    tree_base_x = tree_x << 3
    tree_base_y = tree_y << 3
    l1_min_x = tree_base_x + (local_x << 1)
    l1_max_x = l1_min_x + 1
    l1_min_y = tree_base_y + (local_y << 1)
    l1_max_y = l1_min_y + 1

    def covers(a: int, b: int, point: int) -> bool:
        return (a <= point <= b) or (b <= point <= a)

    def core_hit(gx: int, gy: int) -> bool:
        return covers(x0, x1, gx) and covers(y0, y1, gy)

    bypass = ingress_dir != DIR_PARENT
    clipped = (
        x0 >= l1_min_x
        and x1 >= l1_min_x
        and x0 <= l1_max_x
        and x1 <= l1_max_x
        and y0 >= l1_min_y
        and y1 >= l1_min_y
        and y0 <= l1_max_y
        and y1 <= l1_max_y
    )
    bits = 0
    if core_hit(l1_min_x, l1_min_y) and (bypass or ingress_dir != 3):
        bits |= 1 << 3
    if core_hit(l1_max_x, l1_min_y) and (bypass or ingress_dir != 1):
        bits |= 1 << 1
    if core_hit(l1_min_x, l1_max_y) and (bypass or ingress_dir != 2):
        bits |= 1 << 2
    if core_hit(l1_max_x, l1_max_y) and (bypass or ingress_dir != 0):
        bits |= 1 << 0
    if bypass and not clipped:
        bits |= 1 << 4
    return bits


def _overlaps(a: int, b: int, c_min: int, c_max: int) -> bool:
    both_below = c_min > 0 and a < c_min and b < c_min
    both_above = c_max < 63 and a > c_max and b > c_max
    return not (both_below or both_above)


def mask_l2(coordinate_x: int, coordinate_y: int, ingress_dir: int, x0: int, y0: int, x1: int, y1: int) -> int:
    x0, y0, x1, y1 = x0 & 0x3F, y0 & 0x3F, x1 & 0x3F, y1 & 0x3F
    tree_x = (coordinate_x >> 1) & 0x3
    tree_y = (coordinate_y >> 1) & 0x3
    local_x = coordinate_x & 0x1
    local_y = coordinate_y & 0x1
    tree_base_x = tree_x << 3
    tree_base_y = tree_y << 3
    l2_min_x = tree_base_x + (local_x << 2)
    l2_max_x = l2_min_x + 3
    l2_min_y = tree_base_y + (local_y << 2)
    l2_max_y = l2_min_y + 3

    def rect_overlaps(x_min: int, x_max: int, y_min: int, y_max: int) -> bool:
        return _overlaps(x0, x1, x_min, x_max) and _overlaps(y0, y1, y_min, y_max)

    def child_hit(x_min: int, x_max: int, y_min: int, y_max: int, direction: int) -> bool:
        return rect_overlaps(x_min, x_max, y_min, y_max) and ingress_dir != direction

    contained = (
        x0 >= l2_min_x
        and x1 >= l2_min_x
        and x0 <= l2_max_x
        and x1 <= l2_max_x
        and y0 >= l2_min_y
        and y1 >= l2_min_y
        and y0 <= l2_max_y
        and y1 <= l2_max_y
    )
    bits = 0
    if child_hit(l2_min_x, l2_min_x + 1, l2_min_y, l2_min_y + 1, 3):
        bits |= 1 << 3
    if child_hit(l2_min_x + 2, l2_min_x + 3, l2_min_y, l2_min_y + 1, 1):
        bits |= 1 << 1
    if child_hit(l2_min_x, l2_min_x + 1, l2_min_y + 2, l2_min_y + 3, 2):
        bits |= 1 << 2
    if child_hit(l2_min_x + 2, l2_min_x + 3, l2_min_y + 2, l2_min_y + 3, 0):
        bits |= 1 << 0
    if ingress_dir != DIR_PARENT and not contained:
        bits |= 1 << 4
    return bits


def mask_l3(coordinate_x: int, coordinate_y: int, ingress_dir: int, x0: int, y0: int, x1: int, y1: int) -> int:
    x0, y0, x1, y1 = x0 & 0x3F, y0 & 0x3F, x1 & 0x3F, y1 & 0x3F
    tree_x = coordinate_x & 0x3
    tree_y = coordinate_y & 0x3
    tree_base_x = tree_x << 3
    tree_base_y = tree_y << 3
    tree_max_x = tree_base_x + 7
    tree_max_y = tree_base_y + 7
    mid_x = tree_base_x + 3
    mid_y = tree_base_y + 3

    def rect_overlaps(x_min: int, x_max: int, y_min: int, y_max: int) -> bool:
        return _overlaps(x0, x1, x_min, x_max) and _overlaps(y0, y1, y_min, y_max)

    def child_hit(x_min: int, x_max: int, y_min: int, y_max: int, direction: int) -> bool:
        return rect_overlaps(x_min, x_max, y_min, y_max) and ingress_dir != direction

    contained = (
        x0 >= tree_base_x
        and x1 >= tree_base_x
        and x0 <= tree_max_x
        and x1 <= tree_max_x
        and y0 >= tree_base_y
        and y1 >= tree_base_y
        and y0 <= tree_max_y
        and y1 <= tree_max_y
    )
    bits = 0
    if child_hit(tree_base_x, mid_x, tree_base_y, mid_y, 3):
        bits |= 1 << 3
    if child_hit(tree_base_x + 4, tree_max_x, tree_base_y, mid_y, 1):
        bits |= 1 << 1
    if child_hit(tree_base_x, mid_x, tree_base_y + 4, tree_max_y, 2):
        bits |= 1 << 2
    if child_hit(tree_base_x + 4, tree_max_x, tree_base_y + 4, tree_max_y, 0):
        bits |= 1 << 0
    if ingress_dir != DIR_PARENT and not contained:
        bits |= 1 << 4
    return bits


def mask_mesh(
    coordinate_x: int,
    coordinate_y: int,
    grid_size: int,
    ingress_dir: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    *,
    coord_shift: int = 0,
) -> int:
    x_lo = min(x0, x1) >> coord_shift
    x_hi = max(x0, x1) >> coord_shift
    y_lo = min(y0, y1) >> coord_shift
    y_hi = max(y0, y1) >> coord_shift
    cx, cy = coordinate_x, coordinate_y
    in_col = x_lo <= cx <= x_hi
    in_row = y_lo <= cy <= y_hi
    local_hit = in_col and in_row

    def abs_diff(a: int, b: int) -> int:
        return a - b if a >= b else b - a

    d_ll = abs_diff(cx, x_lo) + abs_diff(cy, y_lo)
    d_lh = abs_diff(cx, x_lo) + abs_diff(cy, y_hi)
    d_hl = abs_diff(cx, x_hi) + abs_diff(cy, y_lo)
    d_hh = abs_diff(cx, x_hi) + abs_diff(cy, y_hi)
    choose_lh = d_lh < d_ll
    best_y_left = y_hi if choose_lh else y_lo
    best_d_left = d_lh if choose_lh else d_ll
    choose_hh = d_hh < d_hl
    best_y_right = y_hi if choose_hh else y_lo
    best_d_right = d_hh if choose_hh else d_hl
    choose_right = best_d_right < best_d_left
    target_x = x_hi if choose_right else x_lo
    target_y = best_y_right if choose_right else best_y_left

    east_needed = cx < x_hi
    west_needed = cx > x_lo
    north_needed = in_col and cy < y_hi
    south_needed = in_col and cy > y_lo
    go_west = go_south = go_east = go_north = go_local = False
    if not local_hit:
        if cx < target_x:
            go_east = True
        elif cx > target_x:
            go_west = True
        elif cy < target_y:
            go_north = True
        elif cy > target_y:
            go_south = True
    else:
        if ingress_dir != DIR_PARENT:
            go_local = True
        if ingress_dir == DIR_WEST:
            go_east, go_north, go_south = east_needed, north_needed, south_needed
        elif ingress_dir == DIR_EAST:
            go_west, go_north, go_south = west_needed, north_needed, south_needed
        elif ingress_dir == DIR_NORTH:
            if cy == y_hi:
                go_west, go_east = west_needed, east_needed
            go_south = south_needed
        elif ingress_dir == DIR_SOUTH:
            if cy == y_lo:
                go_west, go_east = west_needed, east_needed
            go_north = north_needed
        elif ingress_dir == DIR_PARENT:
            if cx < x_lo:
                go_east = True
            elif cx > x_hi:
                go_west = True
            else:
                go_west, go_east = west_needed, east_needed
            go_north, go_south = north_needed, south_needed
    if cx == 0:
        go_west = False
    if cx == grid_size - 1:
        go_east = False
    if cy == 0:
        go_south = False
    if cy == grid_size - 1:
        go_north = False
    return (
        (1 << DIR_WEST if go_west else 0)
        | (1 << DIR_SOUTH if go_south else 0)
        | (1 << DIR_EAST if go_east else 0)
        | (1 << DIR_NORTH if go_north else 0)
        | (1 << DIR_PARENT if go_local else 0)
    )


def _empty_result(**overrides: Any) -> dict[str, Any]:
    base = {
        "destinations": [],
        "hops": 0,
        "tree_hops": 0,
        "mesh_hops": 0,
        "duplicate": False,
        "loss": False,
        "cycle": False,
        "path": [],
        "router_traversal": [],
        "link_traversal": [],
        "top_mesh_injection": 0,
        "top_mesh_link_traversal": 0,
    }
    base.update(overrides)
    return base


def deliver(
    sx: int,
    sy: int,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    cluster_grid: int,
    *,
    exclude_source: bool = True,
) -> dict[str, Any]:
    if cluster_grid < 1 or cluster_grid > 4:
        raise ValueError("cluster_grid out of range")
    width = cluster_grid * TILE
    expected = {
        (x, y)
        for y in range(min(y0, y1), max(y0, y1) + 1)
        for x in range(min(x0, x1), max(x0, x1) + 1)
        if 0 <= x < width and 0 <= y < width and (not exclude_source or x != sx or y != sy)
    }
    delivered: set[tuple[int, int]] = set()
    duplicate = False
    cycle = False
    tree_hops = 0
    mesh_hops = 0
    path: list[str] = []
    routers: list[str] = []
    links: list[str] = []
    top_mesh_injection = 0
    top_mesh_links = 0
    visited: set[tuple[str, int, int, int]] = set()
    queue: deque[tuple[str, int, int, int, int]] = deque()
    l1x, l1y = sx >> 1, sy >> 1

    def push(kind: str, x: int, y: int, ingress: int, hops: int, src: str | None) -> None:
        nonlocal cycle, top_mesh_injection, top_mesh_links
        key = (kind, x, y, ingress)
        dest = "%s(%d,%d)" % (kind, x, y)
        if src is not None:
            links.append("%s->%s" % (src, dest))
            if src.startswith("L3") and kind == "MESH":
                top_mesh_injection += 1
            if src.startswith("MESH") and kind == "MESH":
                top_mesh_links += 1
        if hops >= MAX_HOPS:
            cycle = True
        elif key not in visited:
            visited.add(key)
            queue.append((kind, x, y, ingress, hops))

    start = ("L1", l1x, l1y, core_dir(sx, sy))
    visited.add(start)
    queue.append((start[0], start[1], start[2], start[3], 0))

    while queue:
        kind, rx, ry, ingress, hops = queue.popleft()
        here = "%s(%d,%d)" % (kind, rx, ry)
        path.append("%s<-%d" % (here, ingress))
        if here not in routers:
            routers.append(here)
        if kind == "L1":
            tree_hops = max(tree_hops, hops + 1)
            mask = mask_l1(rx, ry, ingress, x0, y0, x1, y1)
            for direction in _bits(mask):
                if direction == ingress:
                    continue
                if direction == DIR_PARENT:
                    push("L2", rx >> 1, ry >> 1, parent_child_dir(rx, ry), hops + 1, here)
                else:
                    cx, cy = core_at(rx, ry, direction)
                    if (cx, cy) in delivered:
                        duplicate = True
                    delivered.add((cx, cy))
                    links.append("%s->PE(%d,%d)" % (here, cx, cy))
        elif kind == "L2":
            tree_hops = max(tree_hops, hops + 1)
            mask = mask_l2(rx, ry, ingress, x0, y0, x1, y1)
            for direction in _bits(mask):
                if direction == ingress:
                    continue
                if direction == DIR_PARENT:
                    push("L3", rx >> 1, ry >> 1, parent_child_dir(rx, ry), hops + 1, here)
                else:
                    cx, cy = l2_child_l1(rx, ry, direction)
                    push("L1", cx, cy, DIR_PARENT, hops + 1, here)
        elif kind == "L3":
            tree_hops = max(tree_hops, hops + 1)
            mask = mask_l3(rx, ry, ingress, x0, y0, x1, y1)
            for direction in _bits(mask):
                if direction == ingress:
                    continue
                if direction == DIR_PARENT:
                    if cluster_grid > 1:
                        push("MESH", rx, ry, DIR_PARENT, hops + 1, here)
                else:
                    cx, cy = l3_child_l2(rx, ry, direction)
                    push("L2", cx, cy, DIR_PARENT, hops + 1, here)
        elif kind == "MESH":
            mesh_hops = max(mesh_hops, hops + 1)
            mask = mask_mesh(rx, ry, cluster_grid, ingress, x0, y0, x1, y1, coord_shift=COORD_SHIFT)
            for direction in _bits(mask):
                if direction == ingress:
                    continue
                if direction == DIR_PARENT:
                    push("L3", rx, ry, DIR_PARENT, hops + 1, here)
                else:
                    nx, ny = {
                        DIR_WEST: (rx - 1, ry),
                        DIR_EAST: (rx + 1, ry),
                        DIR_SOUTH: (rx, ry - 1),
                        DIR_NORTH: (rx, ry + 1),
                    }[direction]
                    if 0 <= nx < cluster_grid and 0 <= ny < cluster_grid:
                        push("MESH", nx, ny, opposite(direction), hops + 1, here)
        else:
            raise ValueError(kind)

    loss = any(pe not in delivered for pe in expected) or any(pe not in expected for pe in delivered)
    return _empty_result(
        destinations=sorted(pe_index(x, y, width) for x, y in delivered),
        hops=tree_hops + mesh_hops,
        tree_hops=tree_hops,
        mesh_hops=mesh_hops,
        duplicate=duplicate,
        loss=loss,
        cycle=cycle,
        path=path,
        router_traversal=routers,
        link_traversal=links,
        top_mesh_injection=top_mesh_injection,
        top_mesh_link_traversal=top_mesh_links,
    )


def deliver_unicast(sx: int, sy: int, dx: int, dy: int, cluster_grid: int) -> dict[str, Any]:
    return deliver(sx, sy, dx, dy, dx, dy, cluster_grid)


def deliver_flat_mesh(sx: int, sy: int, dx: int, dy: int, n: int) -> dict[str, Any]:
    expected = {(dx, dy)}
    delivered: set[tuple[int, int]] = set()
    duplicate = False
    cycle = False
    visited: set[tuple[int, int, int]] = set()
    queue: deque[tuple[int, int, int, int]] = deque()
    queue.append((sx, sy, DIR_PARENT, 0))
    visited.add((sx, sy, DIR_PARENT))
    hops = 0
    path: list[str] = []
    routers: list[str] = []
    links: list[str] = []
    while queue:
        cx, cy, ingress, hop = queue.popleft()
        hops = max(hops, hop)
        here = "FM(%d,%d)" % (cx, cy)
        path.append("%s<-%d" % (here, ingress))
        if here not in routers:
            routers.append(here)
        mask = mask_mesh(cx, cy, n, ingress, dx, dy, dx, dy, coord_shift=0)
        for direction in _bits(mask):
            if direction == ingress:
                continue
            if direction == DIR_PARENT:
                if (cx, cy) in delivered:
                    duplicate = True
                delivered.add((cx, cy))
                links.append("%s->PE(%d,%d)" % (here, cx, cy))
            else:
                nx, ny = {
                    DIR_WEST: (cx - 1, cy),
                    DIR_EAST: (cx + 1, cy),
                    DIR_SOUTH: (cx, cy - 1),
                    DIR_NORTH: (cx, cy + 1),
                }[direction]
                key = (nx, ny, opposite(direction))
                if nx < 0 or nx >= n or ny < 0 or ny >= n or hop + 1 >= MAX_HOPS:
                    cycle = True
                elif key not in visited:
                    visited.add(key)
                    links.append("%s->FM(%d,%d)" % (here, nx, ny))
                    queue.append((nx, ny, opposite(direction), hop + 1))
    return _empty_result(
        destinations=sorted(pe_index(x, y, n) for x, y in delivered),
        hops=hops,
        tree_hops=0,
        mesh_hops=hops,
        duplicate=duplicate,
        loss=delivered != expected,
        cycle=cycle,
        path=path,
        router_traversal=routers,
        link_traversal=links,
        top_mesh_injection=0,
        top_mesh_link_traversal=0,
    )


def traversal_for_packet(
    source: int,
    rect: Iterable[int],
    *,
    nodes: int,
    routing: str,
) -> dict[str, Any]:
    width = int(round(nodes ** 0.5))
    sx, sy = pe_xy(source, width)
    x0, y0, x1, y1 = [int(v) for v in rect]
    if routing == "mesh":
        if x0 != x1 or y0 != y1:
            raise ValueError("flat-mesh V3 cases are unicast")
        return deliver_flat_mesh(sx, sy, x0, y0, width)
    return deliver(sx, sy, x0, y0, x1, y1, width // TILE)
