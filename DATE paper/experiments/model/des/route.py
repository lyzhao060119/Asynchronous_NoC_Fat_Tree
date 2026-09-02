"""Direction masks at a DES router, same bits as the Scala/Python oracle."""

from __future__ import annotations

from date_v3.route_oracle import (
    DIR_PARENT,
    _bits,
    mask_l1,
    mask_l2,
    mask_l3,
    mask_mesh,
)

from .topology import RouterSpec, legal_output_directions, lanes_of, phys_index


def route_mask(spec: RouterSpec, ingress_dir: int, rect: tuple[int, int, int, int]) -> int:
    x0, y0, x1, y1 = rect
    if spec.kind == "L1":
        return mask_l1(spec.x, spec.y, ingress_dir, x0, y0, x1, y1)
    if spec.kind == "L2":
        return mask_l2(spec.x, spec.y, ingress_dir, x0, y0, x1, y1)
    if spec.kind == "L3":
        return mask_l3(spec.x, spec.y, ingress_dir, x0, y0, x1, y1)
    if spec.kind in ("MESH", "FM"):
        return mask_mesh(
            spec.x,
            spec.y,
            spec.mesh_grid,
            ingress_dir,
            x0,
            y0,
            x1,
            y1,
            coord_shift=spec.coord_shift,
        )
    raise ValueError("unknown router kind %s" % spec.kind)


def output_directions(spec: RouterSpec, ingress_dir: int, rect: tuple[int, int, int, int]) -> list[int]:
    mask = route_mask(spec, ingress_dir, rect)
    legal = set(legal_output_directions(ingress_dir))
    outs = [direction for direction in _bits(mask) if direction in legal]
    if len(outs) > 4:
        raise RuntimeError("%s produced %s branches" % (spec.id, len(outs)))
    return outs


def first_phys(spec: RouterSpec, direction: int, lane: int = 0) -> int:
    n_lanes = lanes_of(spec.child_lanes, spec.parent_lanes, direction)
    if lane < 0 or lane >= n_lanes:
        raise ValueError("lane %s out of range for dir %s" % (lane, direction))
    return phys_index(spec.child_lanes, direction, lane)
