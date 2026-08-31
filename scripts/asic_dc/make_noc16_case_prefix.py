#!/usr/bin/env python3
"""Create a smaller NoC16 .case by keeping an input-flit prefix."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


def parse_args():
    ap = argparse.ArgumentParser()
    ap.add_argument("case", type=Path)
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--prefix", type=int, help="Maximum number of input flits to keep in file order.")
    group.add_argument("--cycle-cutoff", type=int, help="Keep input flits whose scheduled cycle is <= this value.")
    ap.add_argument(
        "--out-dir",
        type=Path,
        default=Path("sim/AsyncNoC/testbench/generated_cases/VCTM_16_debug"),
    )
    ap.add_argument(
        "--allow-partial-packet",
        action="store_true",
        help="Keep exactly prefix input flits even if the last packet is incomplete.",
    )
    ap.add_argument(
        "--complete-started-packets",
        action="store_true",
        help="Keep the prefix traffic and append remaining flits of every packet started in the prefix.",
    )
    return ap.parse_args()


def strip_comment(line: str) -> str:
    return line.split("#", 1)[0].strip()


def flit_index(line: str, fallback: int) -> int:
    m = re.search(r"\bflit(\d+)\b", line)
    if m:
        return int(m.group(1))
    return fallback


def main():
    args = parse_args()
    if args.allow_partial_packet and args.complete_started_packets:
        raise SystemExit("--allow-partial-packet and --complete-started-packets are mutually exclusive")
    src = args.case
    lines = src.read_text(encoding="utf-8", errors="replace").splitlines()
    inputs = []
    expects = []
    kept_lines = []
    case_name = src.stem

    for idx, line in enumerate(lines):
        body = strip_comment(line)
        if not body:
            kept_lines.append(line)
            continue
        parts = body.split()
        tag = parts[0]
        if tag == "case" and len(parts) >= 2:
            case_name = parts[1]
            kept_lines.append(line)
        elif tag == "input":
            if len(parts) < 5:
                raise SystemExit(f"Malformed input at line {idx + 1}: {line}")
            inputs.append(
                {
                    "idx": idx,
                    "line": line,
                    "cycle": int(parts[1]),
                    "port": int(parts[2]),
                    "seq": int(parts[3]),
                    "flit": parts[4].lower(),
                    "flit_idx": flit_index(line, fallback=-1),
                }
            )
        elif tag == "expect":
            if len(parts) < 5:
                raise SystemExit(f"Malformed expect at line {idx + 1}: {line}")
            expects.append(
                {
                    "idx": idx,
                    "line": line,
                    "mask": parts[1],
                    "seq": int(parts[2]),
                    "tail": int(parts[3]),
                    "flit": parts[4].lower(),
                    "flit_idx": flit_index(line, fallback=-1),
                }
            )
        else:
            kept_lines.append(line)

    if args.prefix is not None:
        raw_keep = inputs[: args.prefix]
        prefix_label = f"prefix{args.prefix}"
    else:
        raw_keep = [item for item in inputs if item["cycle"] <= args.cycle_cutoff]
        prefix_label = f"cycle{args.cycle_cutoff}"
    keep_seq = {item["seq"] for item in raw_keep}
    if args.complete_started_packets:
        keep_seq = {item["seq"] for item in raw_keep}
        raw_keep = [item for item in inputs if item["seq"] in keep_seq]
    elif not args.allow_partial_packet:
        tail_seq = {item["seq"] for item in raw_keep if int(item["flit"], 16) & (1 << 26)}
        keep_seq &= tail_seq
        raw_keep = [item for item in raw_keep if item["seq"] in keep_seq]

    keep_input_lines = {item["idx"]: item["line"] for item in raw_keep}
    if args.allow_partial_packet:
        keep_flits = {
            (item["seq"], item["flit_idx"], item["flit"])
            for item in raw_keep
        }
        keep_expect_lines = {
            item["idx"]: item["line"]
            for item in expects
            if (item["seq"], item["flit_idx"], item["flit"]) in keep_flits
        }
    else:
        keep_expect_lines = {
            item["idx"]: item["line"]
            for item in expects
            if item["seq"] in keep_seq
        }

    if args.complete_started_packets:
        out_stem = f"{src.stem}-{prefix_label}-closed{len(raw_keep)}"
    else:
        out_stem = f"{src.stem}-{prefix_label}-kept{len(raw_keep)}"
    out_name = f"{out_stem}.case"
    out = args.out_dir / out_name
    args.out_dir.mkdir(parents=True, exist_ok=True)

    rewritten = []
    for idx, line in enumerate(lines):
        body = strip_comment(line)
        if body:
            tag = body.split()[0]
            if tag == "case":
                rewritten.append(f"case {out_stem}")
            elif tag == "input":
                if idx in keep_input_lines:
                    rewritten.append(line)
            elif tag == "expect":
                if idx in keep_expect_lines:
                    rewritten.append(line)
            elif tag == "timeout_cycles":
                rewritten.append(line)
            else:
                rewritten.append(line)
        else:
            rewritten.append(line)

    out.write_text("\n".join(rewritten) + "\n", encoding="utf-8")
    print(
        f"WROTE {out} inputs={len(raw_keep)} expects={len(keep_expect_lines)} "
        f"packets={len(keep_seq)} source_case={case_name}"
    )


if __name__ == "__main__":
    main()
