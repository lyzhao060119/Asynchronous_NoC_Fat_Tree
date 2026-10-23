#!/usr/bin/env python3
"""Lossless pairing of SDF 2.1 split timing checks for NTC/RECREM models.

No delays, edge expressions, conditions, or min/typ/max values are changed.
Only exact endpoint-matched SETUP+HOLD and RECOVERY+HOLD pairs are combined.
"""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re


def parse(text):
    stack = []
    root = None
    for token in re.findall(r"\(|\)|[^\s()]+", text):
        if token == "(":
            node = []
            if stack:
                stack[-1].append(node)
            else:
                if root is not None:
                    raise ValueError("multiple roots")
                root = node
            stack.append(node)
        elif token == ")":
            if not stack:
                raise ValueError("unbalanced close")
            stack.pop()
        else:
            if not stack:
                raise ValueError("token outside expression")
            stack[-1].append(token)
    if stack:
        raise ValueError("unbalanced expression")
    return root


def emit(node):
    return "(" + " ".join(emit(x) if isinstance(x, list) else x for x in node) + ")"


def pair_block(text):
    node = parse(text)
    if node[0] != "TIMINGCHECK":
        raise ValueError("expected TIMINGCHECK")
    entries = node[1:]
    consumed = set()
    output = []
    counts = Counter()
    for i, entry in enumerate(entries):
        if entry[0] not in ("SETUP", "RECOVERY"):
            continue
        if len(entry) != 4:
            raise ValueError("unexpected split check shape")
        matches = [j for j, hold in enumerate(entries) if hold[0] == "HOLD" and
                   hold[1:3] == entry[1:3]]
        if len(matches) != 1:
            raise ValueError(f"ambiguous/missing HOLD partner: {emit(entry)}")
        j = matches[0]
        if j in consumed or len(entries[j]) != 4:
            raise ValueError("HOLD reused or unexpected arity")
        kind = "SETUPHOLD" if entry[0] == "SETUP" else "RECREM"
        output.append([kind, entry[1], entry[2], entry[3], entries[j][3]])
        consumed.update((i, j))
        counts[kind] += 1
    output.extend(entry for i, entry in enumerate(entries) if i not in consumed)
    counts["unpaired_hold"] = sum(entry[0] == "HOLD" for entry in output)
    # Explicitly prove every numeric constraint value survives unchanged.
    before = Counter(emit(e[3]) for e in entries if e[0] in ("SETUP", "RECOVERY", "HOLD"))
    after = Counter()
    for e in output:
        if e[0] in ("SETUPHOLD", "RECREM"):
            after.update(emit(v) for v in e[3:])
        elif e[0] == "HOLD":
            after[emit(e[3])] += 1
    already_combined = [e for e in entries if e[0] in ("SETUPHOLD", "RECREM")]
    for e in already_combined:
        before.update(emit(v) for v in e[3:])
    if before != after:
        raise ValueError("constraint values changed")
    return "  (TIMINGCHECK\n" + "\n".join("    " + emit(e) for e in output) + "\n  )\n", counts


def convert(source, target):
    source, target = Path(source), Path(target)
    if source.resolve() == target.resolve():
        raise ValueError("original SDF must remain read-only")
    target.parent.mkdir(parents=True, exist_ok=True)
    original_hash, output_hash = hashlib.sha256(), hashlib.sha256()
    counts = Counter()
    buffer = []
    balance = 0
    celltype = instance = ""
    with source.open("rb") as inp, target.with_suffix(target.suffix + ".part").open("wb") as out:
        for raw in inp:
            original_hash.update(raw)
            line = raw.decode("utf-8")
            if line.lstrip().startswith("(CELLTYPE"):
                celltype = line.strip()
            if line.lstrip().startswith("(INSTANCE"):
                instance = line.strip()
            if buffer or line.lstrip().startswith("(TIMINGCHECK"):
                buffer.append(line)
                balance += line.count("(") - line.count(")")
                if balance == 0:
                    try:
                        result, found = pair_block("".join(buffer))
                    except ValueError as exc:
                        raise ValueError(f"{celltype} {instance}: {exc}") from exc
                    data = result.encode()
                    counts.update(found)
                    counts["timingcheck_blocks"] += 1
                    out.write(data)
                    output_hash.update(data)
                    buffer = []
                continue
            data = raw.replace(b'(SDFVERSION "OVI 2.1")', b'(SDFVERSION "3.0")')
            out.write(data)
            output_hash.update(data)
    if buffer:
        raise ValueError("unfinished timingcheck block")
    if counts["unpaired_hold"]:
        raise ValueError(f"unpaired HOLD checks require review: {counts}")
    target.with_suffix(target.suffix + ".part").replace(target)
    manifest = dict(source=str(source), source_sha256=original_hash.hexdigest(),
                    target=str(target), target_sha256=output_hash.hexdigest(),
                    counts=dict(counts), delay_lines_unchanged=True,
                    exact_edge_condition_pairing=True, numeric_values_unchanged=True)
    target.with_suffix(target.suffix + ".json").write_text(json.dumps(manifest, indent=2) + "\n")
    print("FORMAL256_SDF_PAIRING_PASS", json.dumps(manifest), flush=True)
    return manifest


def prepare_pilot(source, work):
    """Extract actual frozen checks into a two-cell annotation compatibility test."""
    work = Path(work)
    work.mkdir(parents=True, exist_ok=True)
    wanted = {"LHCNDQD1BWP12T30P140": "u_latch", "DFCNQD1BWP12T30P140": "u_dff"}
    found = {}
    buffer = []
    depth = 0
    name = None
    with Path(source).open() as stream:
        for line in stream:
            if not buffer:
                match = re.match(r'\s*\(CELLTYPE "([^"]+)"\)', line)
                if not match or match[1] not in wanted or match[1] in found:
                    continue
                name = match[1]
                buffer = ["(CELL\n", line]
                depth = 1
                continue
            buffer.append(line)
            depth += line.count("(") - line.count(")")
            if depth == 0:
                text = "".join(buffer)
                text = re.sub(r"(?m)^\s*\(INSTANCE .*$", f"  (INSTANCE {wanted[name]})", text)
                found[name] = text
                buffer = []
                if len(found) == len(wanted):
                    break
    if len(found) != len(wanted):
        raise ValueError("pilot cell types were not found")
    source_path = work / "split.sdf"
    source_path.write_text('(DELAYFILE\n(SDFVERSION "OVI 2.1")\n(DESIGN "tb")\n(TIMESCALE 1ns)\n' +
                           "".join(found.values()) + ")\n")
    convert(source_path, work / "paired.sdf")
    (work / "tb.sv").write_text('''`timescale 1ns/1ps
module tb;
reg D=0, CP=0, E=0, CDN=0;
wire Qd, Ql;
DFCNQD1BWP12T30P140 u_dff(.D(D),.CP(CP),.CDN(CDN),.Q(Qd));
LHCNDQD1BWP12T30P140 u_latch(.D(D),.E(E),.CDN(CDN),.Q(Ql));
initial begin
$sdf_annotate("paired.sdf",tb,,"annotation.log","MAXIMUM");
#10 CDN=1; #10 D=1; #10 CP=1; E=1; #10 CP=0; E=0;
#10 D=0; #10 CP=1; E=1; #10 CP=0; E=0; #10 $finish;
end
endmodule
''')
    print("FORMAL256_SDF_PILOT_READY", str(work), flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--source", required=True)
    p.add_argument("--target", required=True)
    p.add_argument("--pilot", action="store_true")
    a = p.parse_args()
    if a.pilot:
        prepare_pilot(a.source, a.target)
    else:
        convert(a.source, a.target)
