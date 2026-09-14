#!/usr/bin/env python3
"""Check emitted PROP_temp hierarchy and B8 one-to-one link maps."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]


def links() -> None:
    l1_parents, l2_children = set(), set()
    l2_parents, l3_children = set(), set()
    l3_parents, mesh_locals = set(), set()
    for q in range(4):
        for i in range(4):
            for k in range(4):
                l1_parents.add((q, i, k))
                l2_children.add((q, k, (~i) & 3))
        for k in range(4):
            for j in range(4):
                l2_parents.add((q, k, j))
                l3_children.add((j, k, (~q) & 3))
    for j in range(4):
        for k in range(4):
            l3_parents.add((j, k))
            mesh_locals.add((j, k // 2, k % 2))
    assert len(l1_parents) == len(l2_children) == 64
    assert len(l2_parents) == len(l3_children) == 64
    assert len(l3_parents) == len(mesh_locals) == 16


def count(pattern: str, text: str) -> int:
    return len(re.findall(pattern, text, re.MULTILINE))


def main() -> None:
    links()
    p64 = REPO / "generated_cmr/prop_temp64/PROP_temp64.v"
    p256 = REPO / "generated_cmr/prop_temp256/PROP_temp256.v"
    targets = ((p64, 1),) if "--64-only" in sys.argv else ((p64, 1), (p256, 4))
    for path, expected in targets:
        text = path.read_text(encoding="utf-8")
        assert re.search(r"^module PROP_temp%d\(" % (64 if expected == 1 else 256),
                         text, re.MULTILINE), path
        for level, n in ((1, 16), (2, 16), (3, 16)):
            actual = count(r"^  CMRRouter\w* propL%d_\w+ \(" % level, text)
            assert actual == n * expected, (path, level, actual, n * expected)
        if expected == 1:
            assert count(r"^  PROPtempTile\w* tile \(", text) == 1
            for idx in range(16):
                assert "io_top_input_%d_HS_Req" % idx in text
                assert "io_top_output_%d_HS_Req" % idx in text
        else:
            assert count(r"^  PROPtempTile\w* propTile_\d_\d \(", text) == 4
            assert count(r"^  CMRTopMesh\w* propMesh_j\d_h\d \(", text) == 8
            # FIRRTL may deduplicate the eight identical mesh-plane modules;
            # four textual routers then represent 8*4 physical instances.
            assert count(r"^  CMRRouter\w* topMesh_\d_\d \(", text) in (4, 32)
            for idx in range(256):
                assert "io_core_inputs_%d_HS_Req" % idx in text
        print("PROP_TEMP_STRUCTURE_PASS", path.name,
              "routers", 48 if expected == 1 else 224,
              "size", path.stat().st_size)


if __name__ == "__main__":
    main()
