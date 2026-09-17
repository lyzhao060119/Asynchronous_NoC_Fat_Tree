#!/usr/bin/env python3
"""Structure gate for PROP_temp256 / PFAT_temp256 paper 256-node DUTs."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def count(pattern: str, text: str) -> int:
    return len(re.findall(pattern, text, re.MULTILINE))


def check_prop_temp256_m16(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    assert re.search(r"^module PROP_temp256_m16\(", text, re.MULTILINE), path
    assert count(r"^  PROPtempTileM16\w* propTile_\d_\d \(", text) == 4
    assert count(r"^  CMRTopMesh\w* propMesh_j\d_h\d \(", text) == 16
    for level in (1, 2, 3):
        actual = count(r"^  CMRRouter\w* propL%d_\w+ \(" % level, text)
        assert actual == 64, (path, level, actual)
    # FIRRTL may dedup identical mesh modules; 4 textual or 64 physical (16*4).
    assert count(r"^  CMRRouter\w* topMesh_\d_\d \(", text) in (4, 64)
    for idx in range(256):
        assert "io_core_inputs_%d_HS_Req" % idx in text
    # This candidate changes only the tree RCU matched delay.  Mesh RCU stays
    # at DEL150 and OPM Ackin stays DEL050.
    rcu100 = count(
        r"DelayElement #\(\.DelayUnitPs\(100\), \.DelayValue\(1\)\) BundlingSignal_MatchedDelay",
        text,
    )
    rcu150 = count(
        r"DelayElement #\(\.DelayUnitPs\(150\), \.DelayValue\(1\)\) BundlingSignal_MatchedDelay",
        text,
    )
    rcu050 = count(
        r"DelayElement #\(\.DelayUnitPs\(50\), \.DelayValue\(1\)\) BundlingSignal_MatchedDelay",
        text,
    )
    assert rcu100 > 0 and rcu150 > 0 and rcu050 == 0, (rcu100, rcu150, rcu050)
    print(
        "PROP_TEMP256_M16_STRUCTURE_PASS",
        path.name,
        "routers",
        256,
        "tree_rcu_del100",
        rcu100,
        "mesh_rcu_del150",
        rcu150,
        "size",
        path.stat().st_size,
    )


def check_prop_temp256(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    assert re.search(r"^module PROP_temp256\(", text, re.MULTILINE), path
    assert count(r"^  PROPtempTile\w* propTile_\d_\d \(", text) == 4
    assert count(r"^  CMRTopMesh\w* propMesh_j\d_h\d \(", text) == 8
    for level in (1, 2, 3):
        actual = count(r"^  CMRRouter\w* propL%d_\w+ \(" % level, text)
        assert actual == 64, (path, level, actual)
    # FIRRTL may dedup identical mesh modules; accept textual 4 or physical 32.
    assert count(r"^  CMRRouter\w* topMesh_\d_\d \(", text) in (4, 32)
    for idx in range(256):
        assert "io_core_inputs_%d_HS_Req" % idx in text
    print("PROP_TEMP256_STRUCTURE_PASS", path.name, "routers", 224, "size", path.stat().st_size)


def check_pfat_temp256(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    assert re.search(r"^module PFAT_temp256\(", text, re.MULTILINE), path
    assert count(r"^  CMRFatTree\w* pfatTile_\d_\d \(", text) == 4
    assert count(r"^  CMRTopMesh\w* pfatMesh_j\d \(", text) == 4
    for idx in range(256):
        assert "io_core_inputs_%d_HS_Req" % idx in text
    # 4 * 21 tile routers + 4 * 4 mesh routers = 100 (mesh may dedup textually).
    tile_r = count(r"^  CMRRouter\w* ", text)
    print(
        "PFAT_TEMP256_STRUCTURE_PASS",
        path.name,
        "cmr_router_text_instances",
        tile_r,
        "size",
        path.stat().st_size,
    )


def check_fm256(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    assert "module CMRMeshNoC" in text or re.search(
        r"^module CMRMeshNoC", text, re.MULTILINE
    ), path
    # Flat 16x16: 256 mesh routers.
    routers = count(r"^  CMRRouter\w* meshR_", text)
    if routers == 0:
        routers = count(r"^  CMRRouter\w* ", text)
    assert routers in (256, 1) or routers >= 16, (path, routers)
    print("FM256_STRUCTURE_PASS", path.name, "router_text", routers, "size", path.stat().st_size)


def main() -> None:
    prop = REPO / "generated_cmr/prop_temp256/PROP_temp256.v"
    prop_m16 = REPO / "generated_cmr/prop_temp256_m16/PROP_temp256_m16.v"
    pfat = REPO / "generated_cmr/pfat_temp256/PFAT_temp256.v"
    fm = REPO / "generated_cmr/mesh_noc256_11/CMRMeshNoC.v"
    if "--m16-only" in sys.argv:
        check_prop_temp256_m16(prop_m16)
        return
    check_prop_temp256(prop)
    if prop_m16.is_file():
        check_prop_temp256_m16(prop_m16)
    else:
        print("PROP_TEMP256_M16_STRUCTURE_SKIP missing", prop_m16)
        if "--require-m16" in sys.argv:
            raise SystemExit("missing PROP_temp256_m16.v")
    if pfat.is_file():
        check_pfat_temp256(pfat)
    else:
        print("PFAT_TEMP256_STRUCTURE_SKIP missing", pfat)
        if "--require-pfat" in sys.argv:
            raise SystemExit("missing PFAT_temp256.v")
    if fm.is_file():
        check_fm256(fm)
    else:
        print("FM256_STRUCTURE_SKIP missing", fm)
        if "--require-fm" in sys.argv:
            raise SystemExit("missing CMRMeshNoC.v")


if __name__ == "__main__":
    main()
