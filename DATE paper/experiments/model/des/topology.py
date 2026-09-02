"""Build Q64 / TopMesh / flat-mesh router graphs that match emitted RTL."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from date_v3.network_inventory import adapters as adapter_count
from date_v3.network_inventory import by_id as inventory_by_id
from date_v3.network_inventory import max_fanin, port_count
from date_v3.route_oracle import (
    DIR_EAST,
    DIR_NORTH,
    DIR_PARENT,
    DIR_SOUTH,
    DIR_WEST,
    TILE,
    core_at,
    parent_child_dir,
    pe_index,
)

from .timing import TimingTable


def rid(kind: str, x: int, y: int) -> str:
    return "%s(%d,%d)" % (kind, x, y)


def phys_index(child: int, direction: int, lane: int) -> int:
    if direction < 4:
        return direction * child + lane
    return 4 * child + lane


def dir_of_phys(child: int, port: int) -> int:
    if port < 4 * child:
        return port // child
    return DIR_PARENT


def lane_of_phys(child: int, port: int) -> int:
    if port < 4 * child:
        return port % child
    return port - 4 * child


def lanes_of(child: int, parent: int, direction: int) -> int:
    return child if direction < 4 else parent


def legal_output_directions(ingress_dir: int, n_dirs: int = 5) -> list[int]:
    return [direction for direction in range(n_dirs) if direction != ingress_dir]


@dataclass
class RouterSpec:
    id: str
    kind: str
    x: int
    y: int
    level: int
    child_lanes: int
    parent_lanes: int
    mesh: bool
    mesh_grid: int
    coord_shift: int
    primitive_id: str
    tile_x: int = 0
    tile_y: int = 0

    @property
    def n_ports(self) -> int:
        return port_count(self.child_lanes, self.parent_lanes)

    @property
    def n_adapters(self) -> int:
        return adapter_count(self.child_lanes, self.parent_lanes)

    @property
    def max_fanin(self) -> int:
        return max_fanin(self.child_lanes, self.parent_lanes)


@dataclass
class Network:
    design_id: str
    nodes: int
    width: int
    cluster_grid: int
    routing: str
    async_design: bool
    hrep: bool
    routers: dict[str, RouterSpec] = field(default_factory=dict)
    links: dict[tuple[str, int], tuple[str, int]] = field(default_factory=dict)
    inject: dict[int, tuple[str, int]] = field(default_factory=dict)
    eject: dict[tuple[str, int], int] = field(default_factory=dict)
    dangling: set[tuple[str, int]] = field(default_factory=set)
    timing_kind: dict[str, str] = field(default_factory=dict)

    def add_router(self, spec: RouterSpec) -> RouterSpec:
        self.routers[spec.id] = spec
        self.timing_kind[spec.id] = spec.primitive_id
        return spec

    def connect(self, a: str, ap: int, b: str, bp: int) -> None:
        self.links[(a, ap)] = (b, bp)
        self.links[(b, bp)] = (a, ap)

    def attach_pe(self, pe: int, router: str, port: int) -> None:
        self.inject[pe] = (router, port)
        self.eject[(router, port)] = pe

    def stats(self) -> dict[str, Any]:
        ports = sum(spec.n_ports for spec in self.routers.values())
        adp = sum(spec.n_adapters for spec in self.routers.values())
        inter = sum(1 for (src, _sp), (dst, _dp) in self.links.items() if src in self.routers and dst in self.routers)
        # each bidirectional pair is stored twice
        inter_links = inter
        return {
            "design_id": self.design_id,
            "routers": len(self.routers),
            "ports": ports,
            "ipms": ports,
            "opms": ports,
            "adapters": adp,
            "inter_router_links": inter_links,
            "core_ports": self.nodes,
            "max_opm_fanin": max((spec.max_fanin for spec in self.routers.values()), default=0),
        }


def _pick_primitive(design: dict[str, Any], *, level: int, child: int, parent: int, mesh: bool) -> str:
    for row in design.get("router_primitives") or []:
        if (
            int(row["level"]) == level
            and int(row["child_lanes"]) == child
            and int(row["parent_lanes"]) == parent
            and bool(row.get("use_mesh_routing")) == mesh
        ):
            return str(row["primitive_id"])
    async_design = bool(design.get("async", True))
    prefix = "async" if async_design else "sync"
    if mesh and (child, parent) == (1, 1):
        return "async_flatmesh_1x1"
    if mesh and (child, parent) == (2, 2):
        return "async_topmesh_2x2"
    if (child, parent) == (1, 1):
        return "%s_thin_1x1" % prefix
    if (child, parent) == (1, 2):
        return "async_fat_1x2" if async_design else "sync_fat_1x2"
    if (child, parent) == (2, 2):
        return "%s_prop_2x2" % prefix
    if (child, parent) == (2, 4):
        return "async_pfat_2x4"
    if (child, parent) == (4, 8):
        return "async_pfat_4x8"
    raise KeyError("no primitive for L%s (%s,%s) mesh=%s" % (level, child, parent, mesh))


def _level_geom(design: dict[str, Any], level: int, *, mesh: bool = False) -> tuple[int, int, str]:
    rows = [
        row
        for row in design.get("router_primitives") or []
        if int(row["level"]) == level and bool(row.get("use_mesh_routing")) == mesh
    ]
    if not rows:
        raise KeyError("%s missing L%s mesh=%s" % (design["design_id"], level, mesh))
    row = rows[0]
    return int(row["child_lanes"]), int(row["parent_lanes"]), str(row["primitive_id"])


def _add_q64(net: Network, design: dict[str, Any], tx: int, ty: int) -> str:
    l1c, l1p, l1k = _level_geom(design, 1, mesh=False)
    l2c, l2p, l2k = _level_geom(design, 2, mesh=False)
    l3c, l3p, l3k = _level_geom(design, 3, mesh=False)
    if l1c != 1:
        raise ValueError("Q64 L1 child lanes must be 1")
    if l2c != l1p or l3c != l2p:
        raise ValueError("Q64 lane chain must nest")
    base_l1x = tx * 4
    base_l1y = ty * 4
    width = net.width
    for ly in range(4):
        for lx in range(4):
            x, y = base_l1x + lx, base_l1y + ly
            spec = net.add_router(
                RouterSpec(
                    rid("L1", x, y), "L1", x, y, 1, l1c, l1p, False, 0, 0, l1k, tx, ty
                )
            )
            for direction in range(4):
                cx, cy = core_at(x, y, direction)
                pe = pe_index(cx, cy, width)
                net.attach_pe(pe, spec.id, phys_index(l1c, direction, 0))
    for ly in range(2):
        for lx in range(2):
            x, y = tx * 2 + lx, ty * 2 + ly
            net.add_router(
                RouterSpec(rid("L2", x, y), "L2", x, y, 2, l2c, l2p, False, 0, 0, l2k, tx, ty)
            )
    l3_id = rid("L3", tx, ty)
    net.add_router(RouterSpec(l3_id, "L3", tx, ty, 3, l3c, l3p, False, 0, 0, l3k, tx, ty))
    for ly in range(4):
        for lx in range(4):
            x, y = base_l1x + lx, base_l1y + ly
            l2x, l2y = x >> 1, y >> 1
            direction = parent_child_dir(x, y)
            for lane in range(l1p):
                net.connect(
                    rid("L1", x, y),
                    phys_index(l1c, DIR_PARENT, lane),
                    rid("L2", l2x, l2y),
                    phys_index(l2c, direction, lane),
                )
    for ly in range(2):
        for lx in range(2):
            x, y = tx * 2 + lx, ty * 2 + ly
            direction = parent_child_dir(x, y)
            for lane in range(l2p):
                net.connect(
                    rid("L2", x, y),
                    phys_index(l2c, DIR_PARENT, lane),
                    l3_id,
                    phys_index(l3c, direction, lane),
                )
    return l3_id


def _add_topmesh(net: Network, design: dict[str, Any], grid: int) -> None:
    child, parent, kind = None, None, None
    for row in design.get("router_primitives") or []:
        if row.get("use_mesh_routing") and int(row.get("child_lanes") or 0) >= 1:
            child = int(row["child_lanes"])
            parent = int(row["parent_lanes"])
            kind = str(row["primitive_id"])
            break
    if child is None:
        raise KeyError("%s missing TopMesh primitive" % design["design_id"])
    l3c, l3p, _l3k = _level_geom(design, 3, mesh=False)
    if parent != l3p:
        raise ValueError("TopMesh local lanes %s != L3 parent %s" % (parent, l3p))
    for ty in range(grid):
        for tx in range(grid):
            spec = net.add_router(
                RouterSpec(
                    rid("MESH", tx, ty),
                    "MESH",
                    tx,
                    ty,
                    1,
                    child,
                    parent,
                    True,
                    grid,
                    3,
                    kind,
                    tx,
                    ty,
                )
            )
            l3 = rid("L3", tx, ty)
            for lane in range(parent):
                net.connect(spec.id, phys_index(child, DIR_PARENT, lane), l3, phys_index(l3c, DIR_PARENT, lane))
    for ty in range(grid):
        for tx in range(grid):
            here = rid("MESH", tx, ty)
            for lane in range(child):
                if tx + 1 < grid:
                    net.connect(
                        here,
                        phys_index(child, DIR_EAST, lane),
                        rid("MESH", tx + 1, ty),
                        phys_index(child, DIR_WEST, lane),
                    )
                else:
                    net.dangling.add((here, phys_index(child, DIR_EAST, lane)))
                if ty + 1 < grid:
                    net.connect(
                        here,
                        phys_index(child, DIR_NORTH, lane),
                        rid("MESH", tx, ty + 1),
                        phys_index(child, DIR_SOUTH, lane),
                    )
                else:
                    net.dangling.add((here, phys_index(child, DIR_NORTH, lane)))
                if tx == 0:
                    net.dangling.add((here, phys_index(child, DIR_WEST, lane)))
                if ty == 0:
                    net.dangling.add((here, phys_index(child, DIR_SOUTH, lane)))


def _add_flat_mesh(net: Network, design: dict[str, Any], n: int) -> None:
    child, parent, kind = _level_geom(design, 1, mesh=True)
    for y in range(n):
        for x in range(n):
            spec = net.add_router(
                RouterSpec(rid("FM", x, y), "FM", x, y, 1, child, parent, True, n, 0, kind)
            )
            pe = pe_index(x, y, n)
            net.attach_pe(pe, spec.id, phys_index(child, DIR_PARENT, 0))
            for lane in range(1, parent):
                net.dangling.add((spec.id, phys_index(child, DIR_PARENT, lane)))
            for lane in range(child):
                if x + 1 < n:
                    net.connect(
                        spec.id,
                        phys_index(child, DIR_EAST, lane),
                        rid("FM", x + 1, y),
                        phys_index(child, DIR_WEST, lane),
                    )
                else:
                    net.dangling.add((spec.id, phys_index(child, DIR_EAST, lane)))
                if y + 1 < n:
                    net.connect(
                        spec.id,
                        phys_index(child, DIR_NORTH, lane),
                        rid("FM", x, y + 1),
                        phys_index(child, DIR_SOUTH, lane),
                    )
                else:
                    net.dangling.add((spec.id, phys_index(child, DIR_NORTH, lane)))
                if x == 0:
                    net.dangling.add((spec.id, phys_index(child, DIR_WEST, lane)))
                if y == 0:
                    net.dangling.add((spec.id, phys_index(child, DIR_SOUTH, lane)))


def build_network(design: dict[str, Any], *, timing: TimingTable | None = None) -> Network:
    design_id = design["design_id"]
    routing = design.get("routing") or "quadtree"
    nodes = int(design["nodes"])
    width = int(round(nodes ** 0.5))
    if routing == "mesh":
        cluster_grid = 0
    else:
        cluster_grid = int(design.get("cluster_grid") or (width // TILE))
    if design_id == "PROP1024_MESH4" or int(design.get("top_mesh_lanes") or 0) == 4:
        raise ValueError("Mesh4 / (4,2) is not elaborated")
    net = Network(
        design_id=design_id,
        nodes=nodes,
        width=width,
        cluster_grid=max(cluster_grid, 1) if routing != "mesh" else 0,
        routing=routing,
        async_design=bool(design.get("async", True)),
        hrep=bool(design.get("hrep_policy")),
    )
    if routing == "mesh":
        _add_flat_mesh(net, design, width)
    else:
        grid = max(cluster_grid, 1)
        for ty in range(grid):
            for tx in range(grid):
                l3 = _add_q64(net, design, tx, ty)
                if grid == 1:
                    _l3c, l3p, _ = _level_geom(design, 3, mesh=False)
                    for lane in range(l3p):
                        net.dangling.add((l3, phys_index(_l3c, DIR_PARENT, lane)))
        if grid > 1:
            _add_topmesh(net, design, grid)
    if timing is not None:
        for spec in net.routers.values():
            timing.require(spec.primitive_id)
    return net


def inventory_delta(net: Network) -> list[str]:
    inv = inventory_by_id()
    if net.design_id not in inv:
        return ["no inventory row for %s" % net.design_id]
    row = inv[net.design_id]
    stats = net.stats()
    errors = []
    for key in ("routers", "ports", "adapters", "inter_router_links"):
        if int(row.get(key) or 0) != int(stats[key]):
            errors.append(
                "%s %s model=%s inventory=%s" % (net.design_id, key, stats[key], row.get(key))
            )
    return errors


def isolated_hop_network(
    *,
    child: int,
    parent: int,
    mesh: bool,
    primitive_id: str,
    async_design: bool = True,
) -> Network:
    """Single-router R-U5: tree injects child0 toward parent; mesh injects local toward East."""
    kind = "FM" if mesh else "L1"
    spec = RouterSpec(
        rid(kind, 0, 0),
        kind,
        0,
        0,
        1,
        child,
        parent,
        mesh,
        8 if mesh else 0,
        0,
        primitive_id,
    )
    net = Network(
        design_id="HOP_%s" % primitive_id,
        nodes=1,
        width=8,
        cluster_grid=1,
        routing="mesh" if mesh else "quadtree",
        async_design=async_design,
        hrep=False,
    )
    net.add_router(spec)
    if mesh:
        net.attach_pe(0, spec.id, phys_index(child, DIR_PARENT, 0))
        for lane in range(child):
            net.dangling.add((spec.id, phys_index(child, DIR_EAST, lane)))
    else:
        net.attach_pe(0, spec.id, phys_index(child, 0, 0))
        for lane in range(parent):
            net.dangling.add((spec.id, phys_index(child, DIR_PARENT, lane)))
    return net
