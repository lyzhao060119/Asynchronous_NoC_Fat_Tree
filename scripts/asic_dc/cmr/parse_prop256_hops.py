#!/usr/bin/env python3
"""Summarize TB_HOP lines: first Head-in without Head-out per flit/link."""
from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

PKT15 = {"8214217", "0214217", "4214217", "8214215", "0214215", "4214215"}
PKT13 = {"8c0cc0d", "0c0cc0d", "4c0cc0d", "8c0cc0c", "0c0cc0c", "4c0cc0c"}
HEADS = {"8214217": "pkt15", "8c0cc0d": "pkt13"}
LINE = re.compile(
    r"TB_HOP t=(\S+) link=(\S+) .* ht=(\d)(\d) .*flit=([0-9a-fA-FxX]+)"
)


def parse(path: Path) -> None:
    hops = []
    with path.open(encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            match = LINE.search(raw)
            if not match:
                continue
            t, link, hbit, tbit, flit = match.groups()
            flit = flit.lower().replace("x", "")
            hops.append((t, link, hbit, tbit, flit))
    print("HOP_LINES", len(hops), path, flush=True)
    by_link = defaultdict(list)
    for row in hops:
        by_link[row[1]].append(row)
    for flit, label in (
        ("8214217", "key_pkt15_head"),
        ("8214215", "iso_pkt15_head"),
        ("8c0cc0d", "key_pkt13_head"),
        ("8c0cc0c", "iso_pkt13_head"),
        ("4214217", "key_pkt15_tail"),
        ("4214215", "iso_pkt15_tail"),
        ("4c0cc0d", "key_pkt13_tail"),
        ("4c0cc0c", "iso_pkt13_tail"),
    ):
        seen = [row for row in hops if row[4] == flit]
        print("FLIT", label, flit, "count", len(seen), flush=True)
        for row in seen[:40]:
            print(" ", row[0], row[1], "ht", row[2] + row[3], flush=True)
        if len(seen) > 40:
            print("  ...", len(seen) - 40, "more", flush=True)
    print("LINKS", flush=True)
    for link in sorted(by_link):
        flits = [row[4] for row in by_link[link]]
        p15 = sum(1 for f in flits if f in PKT15)
        p13 = sum(1 for f in flits if f in PKT13)
        heads15 = sum(1 for f in flits if f in ("8214217", "8214215"))
        heads13 = sum(1 for f in flits if f in ("8c0cc0d", "8c0cc0c"))
        print(
            " ", link, "n=%d p13=%d p15=%d h13=%d h15=%d" % (len(flits), p13, p15, heads13, heads15),
            flush=True,
        )


def main() -> int:
    if len(sys.argv) < 2:
        print("usage: parse_prop256_hops.py run.log [run.log...]", flush=True)
        return 2
    for arg in sys.argv[1:]:
        parse(Path(arg))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
