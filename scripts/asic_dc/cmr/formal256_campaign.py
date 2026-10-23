#!/usr/bin/env python3
"""Remote-only paired 256-node campaign. No DUT RTL changes."""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path
from random import Random
import sys
import statistics
import re

LOADS = (5, 10, 20, *range(40, 501, 20), 600, 700, 800)
SEEDS = (202701, 202702, 202703)
BENCHMARKS = ("TOPO-UR", "MULTICAST10-AABB", "ALL-MULTICAST-AABB")
DESIGNS = ("Mesh256", "M16_256")
MAX_PACKETS = 131072
MAX_RX = 8192


def sha(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def save(path, obj):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(obj, indent=2) + "\n", encoding="utf-8")


def modules(root):
    sys.path.insert(0, str(Path(root) / "experiments/scripts"))
    from date_v3 import canonical_trace as ct
    return ct


def trace_for(root, benchmark, seed, load, small=False):
    ct = modules(root)
    traffic = {"TOPO-UR": "topo_ur", "MULTICAST10-AABB": "continuous_mix64",
               "ALL-MULTICAST-AABB": "continuous_all_multicast64"}[benchmark]
    warmup, measurement = (4, 32) if small else (1000, 10000)
    pairs = ct.draw_pairs(traffic, 256, warmup + measurement,
                          Random(ct.seed_mix(seed, 256, 0, 1)),
                          multicast_fraction=0.10, fanout_choices=(2, 4, 8, 16))
    ready = ct.schedule_pairs(pairs, nodes=256, packet_flits=5, load_point=load,
                              rng=Random(ct.seed_mix(seed, 256, 0, load)))
    events = ct.build_events(pairs, ready, warmup=warmup, packet_flits=5)
    header = dict(kind="header", nodes=256, benchmark_id=benchmark, seed=seed,
                  packet_flits=5, warmup_original_events=warmup,
                  measurement_original_events=measurement, case_tick_ns=1,
                  offered_load=load, load_tag=f"m{load}", fanout_choices=[2, 4, 8, 16],
                  injection_model="v3_exp_header_asap_body", identity_bits=18)
    return dict(header=header, events=events)


def audit(trace):
    ct = modules(ROOT)
    counts = Counter()
    seen = set()
    for e in trace["events"]:
        src, dsts = e["source"], set(e["destinations"])
        assert 0 <= src < 256 and src not in dsts and dsts
        assert all(0 <= d < 256 for d in dsts)
        assert set(ct.cores_in_rect(e["rect"], 16)) - {src} == dsts
        assert len(dsts) in (1, 2, 4, 8, 16)
        assert e["original_event_id"] not in seen
        seen.add(e["original_event_id"])
        counts[len(dsts)] += 1
    return dict(counts)


def encode(seq, src, rect, index):
    if not 0 <= seq < MAX_PACKETS:
        raise ValueError("physical packet ID capacity exceeded")
    if index == 0:
        x0, y0, x1, y1 = rect
        return (1 << 27) | x0 << 2 | y0 << 8 | x1 << 14 | y1 << 20 | src & 3
    # 18-bit identity: [25:12] low14, [5:2] high4. Magic and type unchanged.
    return ((int(index == 4) << 26) | ((seq & 0x3fff) << 12) |
            (index << 9) | (5 << 6) | ((seq >> 14) << 2) | (src & 3))


def materialize(root, trace, stem, repeated=False, sequence_start=0):
    packets, inputs, expected = [], [], []
    per_port = Counter()
    for e in trace["events"]:
        groups = [[d] for d in sorted(e["destinations"])] if repeated else [e["destinations"]]
        for dsts in groups:
            seq = sequence_start + len(packets)
            rect = [dsts[0] % 16, dsts[0] // 16] * 2 if repeated else e["rect"]
            flits = [encode(seq, e["source"], rect, i) for i in range(5)]
            p = dict(pkt_seq=seq, event_index=e["event_index"],
                     original_event_id=e["original_event_id"], source=e["source"],
                     destinations=sorted(dsts), ready_cycle=e["ready_cycle"], phase=e["phase"])
            packets.append(p)
            for i, f in enumerate(flits):
                inputs.append((e["source"], e["ready_cycle"], seq, i, f))
                for d in dsts:
                    expected.append((d, seq, int(i == 4), f))
                    per_port[d] += 1
    assert max(per_port.values()) <= MAX_RX
    assert len(packets) <= MAX_PACKETS
    # Canonical ready time is never shifted by serialization; the TB queues packets.
    inputs.sort(key=lambda v: v[:4])
    suffix = "repeated" if repeated else "native"
    paths = {}
    base_lines = [f"group {trace['header']['benchmark_id']}", "meta case_tick_ns 1.000",
                  "meta packet_tag_bits 18", "meta payload_encoding head_aabb_body_pktseq18_flitindex3",
                  f"meta warmup_original_events {trace['header']['warmup_original_events']}",
                  f"meta measurement_original_events {trace['header']['measurement_original_events']}"]
    base_lines += [f"event_map {p['pkt_seq']} {p['event_index']}" for p in packets]
    base_lines += [f"packet {p['pkt_seq']} {p['source']} {len(p['destinations'])} " +
                   " ".join(map(str, p['destinations'])) for p in packets]
    base_lines += [f"input {cycle} {src} {seq} {f:07x}" for src, cycle, seq, _, f in inputs]
    base_lines += [f"expect_port {d} {seq} {tail} {f:07x}" for d, seq, tail, f in expected]
    for design in DESIGNS:
        name = f"{stem}_{design}_{suffix}"
        path = Path(root) / "cases" / f"{name}.case"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(f"case {name}\n" + "\n".join(base_lines) + "\n", encoding="utf-8")
        paths[design] = dict(path=str(path), sha256=sha(path))
    save(Path(root) / "sidecars" / f"{stem}_{suffix}.json", dict(
        packets=packets, input_flits=len(inputs), expected_copy_flits=len(expected),
        max_rx_per_port=max(per_port.values()), repeated=repeated))
    return paths


def generate(args):
    root = Path(args.root)
    rows = []
    for b in args.benchmark or BENCHMARKS:
        for seed in args.seed or SEEDS:
            for load in args.load or LOADS:
                stem = f"{b}_n256_s{seed}_m{load}" + ("_small" if args.small else "")
                trace_path = root / "traces" / f"{stem}.jsonl"
                if args.repeated:
                    trace = modules(root).load_jsonl(trace_path)
                else:
                    trace = trace_for(root, b, seed, load, args.small)
                    trace_path.parent.mkdir(parents=True, exist_ok=True)
                    modules(root).dump_jsonl(trace, trace_path)
                fanouts = audit(trace)
                paths = materialize(root, trace, stem, args.repeated)
                rows.append(dict(benchmark=b, seed=seed, load=load, trace=str(trace_path),
                                 trace_sha256=sha(trace_path), fanout_counts=fanouts, cases=paths))
                print("FORMAL256_POINT_PASS", stem, flush=True)
    save(root / "manifests" / ("repeated_inputs.json" if args.repeated else
         "small_inputs.json" if args.small else "inputs.json"), rows)
    if args.small:
        directed = trace_for(root, "ALL-MULTICAST-AABB", SEEDS[0], 5, True)
        directed["events"] = directed["events"][:8]
        directed["header"].update(warmup_original_events=0, measurement_original_events=8)
        ct = modules(root)
        for i, event in enumerate(directed["events"]):
            event.update(phase="measurement", ready_cycle=i * 100,
                         destinations=ct.sample_rect_multicast_dests(
                             Random(i), event["source"], 256, (2, 4, 8, 16)[i % 4], cross_l2=False))
            event["rect"] = ct.bounding_rect(event["destinations"], 16)
        stem = "IDENTITY18_n256_s202701_m5_small"
        ct.dump_jsonl(directed, root / "traces" / f"{stem}.jsonl")
        materialize(root, directed, stem, sequence_start=65536)
        # Deliberately inject the first packet twice with the same identity;
        # preserve the original expectations so the scoreboard must reject it.
        for design in DESIGNS:
            src = root / "cases" / f"{stem}_{design}_native.case"
            lines = src.read_text().splitlines()
            first = [line for line in lines if line.startswith("input ") and line.split()[3] == "65536"]
            negative = f"SCOREBOARD_DUPLICATE_{design}"
            lines[0] = "case " + negative
            lines += first
            (root / "cases" / f"{negative}.case").write_text("\n".join(lines) + "\n")
            missing = [line for line in src.read_text().splitlines() if line not in first]
            missing[0] = f"case SCOREBOARD_MISSING_{design}"
            (root / "cases" / f"SCOREBOARD_MISSING_{design}.case").write_text("\n".join(missing) + "\n")
    print("FORMAL256_GENERATION_PASS", len(rows), flush=True)


def build_tb(args):
    root = Path(args.root)
    src = (root / "src/tb_noc_async_keycase.sv").read_text()
    assert src.count("localparam integer MAX_PACKETS = 16384;") == 1
    assert src.count("pkt = captured[25:12];") == 1
    src = src.replace("MAX_PACKETS = 16384;", "MAX_PACKETS = 131072;")
    src = src.replace("STR_CHARS = 256;", "STR_CHARS = 1024;")
    src = src.replace("MAX_RX_PER_PORT = 4096;", "MAX_RX_PER_PORT = 8192;")
    src = src.replace("(NUM_CORES <= 256) ? 1024 : 512", "8192")
    src = src.replace("pkt = captured[25:12];", "pkt = {captured[5:2], captured[25:12]};")
    old = """      for (i = 0; i < latency_count; i = i + 1) for (j = i + 1; j < latency_count; j = j + 1)
        if (latency_ps[j] < latency_ps[i]) begin tmp = latency_ps[i]; latency_ps[i] = latency_ps[j]; latency_ps[j] = tmp; end"""
    assert old in src
    src = src.replace("    reg pass_ok, drainable, backlog_growth;",
                      "    reg pass_ok, drainable, backlog_growth;\n    longint ordered_latencies[$];")
    src = src.replace(old, """      for (i = 0; i < latency_count; i = i + 1) ordered_latencies.push_back(latency_ps[i]);
      ordered_latencies.sort();
      for (i = 0; i < latency_count; i = i + 1) latency_ps[i] = ordered_latencies[i];""")
    src = src.replace('      fd_flit = $fopen(flit_latency_csv_file, "w");',
                      '      if (flit_latency_csv_file != "/dev/null") begin\n      fd_flit = $fopen(flit_latency_csv_file, "w");')
    src = src.replace('      $fclose(fd_flit);', '      $fclose(fd_flit);\n      end')
    src = src.replace('      fd_events = $fopen(event_csv_file, "w");',
                      '      if (event_csv_file != "/dev/null") begin\n      fd_events = $fopen(event_csv_file, "w");')
    src = src.replace('      $fclose(fd_events);', '      $fclose(fd_events);\n      end')
    src = src.replace('      if (measurement_end_cycle < measurement_start_cycle) begin',
                      '      measurement_end_cycle = measurement_end_cycle + 1;\n      if (measurement_end_cycle < measurement_start_cycle) begin')
    src = src.replace('    running = 1\'b1;', '''    for (integer oi = 0; oi < input_count; oi = oi + 1) begin
      input_offer_ps[oi] = longint'((case_epoch_ns + input_cycle[oi] * case_tick_ns) * 1000.0 + 0.5);
      if (input_flit[oi][27]) packet_head_offer_ps[input_pkt_seq[oi]] = input_offer_ps[oi];
    end
    running = 1'b1;''')
    target = root / "src/tb_formal256_fast.sv"
    target.write_text(src)
    print("FORMAL256_TB_BUILD_PASS", sha(target))


def collect_case(root, design, stem, mode="native"):
    root = Path(root)
    side = json.loads((root / "sidecars" / f"{stem}_{mode}.json").read_text())
    trace = modules(root).load_jsonl(root / "traces" / f"{stem}.jsonl")
    result_path = root / "results" / design / f"{stem}_{mode}.csv"
    if not result_path.exists():
        result_path = root / "results" / design / f"{stem}.csv"
    with result_path.open() as f:
        raw = next(csv.DictReader(f))
    log_dir = root / "logs" / design / (stem if mode == "native" else stem + "_repeated")
    log = (log_dir / "run.log").read_text(errors="replace")
    packets = {p["pkt_seq"]: p for p in side["packets"]}
    tails = {}
    with (log_dir / "latency.csv").open() as f:
        for row in csv.DictReader(f):
            key = (int(row["pkt_seq"]), int(row["port"]))
            if key in tails:
                raise ValueError(f"duplicate Tail {key}")
            p = packets[key[0]]
            if key[1] not in p["destinations"]:
                raise ValueError(f"unexpected destination {key}")
            tails[key] = int(row["tail_egress_req_ps"])
    events = {e["event_index"]: e for e in trace["events"]}
    event_tails = {i: {} for i in events}
    epoch = int(raw["measurement_start_ps"]) - min(
        e["ready_cycle"] for e in events.values() if e["phase"] == "measurement") * 1000
    for (seq, dest), arrival in tails.items():
        ei = packets[seq]["event_index"]
        if dest in event_tails[ei]:
            raise ValueError(f"duplicate event destination {ei}:{dest}")
        event_tails[ei][dest] = arrival
    values, first, average = [], [], []
    completed_window = 0
    start, end = int(raw["measurement_start_ps"]), int(raw["measurement_end_ps"])
    for i, e in events.items():
        if e["phase"] != "measurement":
            continue
        arrivals = event_tails[i]
        if set(arrivals) != set(e["destinations"]):
            continue
        due = epoch + e["ready_cycle"] * 1000
        ts = list(arrivals.values())
        first.append((min(ts) - due) / 1000)
        average.append((statistics.mean(ts) - due) / 1000)
        values.append((max(ts) - due) / 1000)
        completed_window += start <= max(ts) < end
    expected = sum(len(e["destinations"]) * 5 for e in events.values() if e["phase"] == "measurement")
    annotation_path = root / "work" / design / "annotation_status.json"
    annotation = json.loads(annotation_path.read_text()) if annotation_path.exists() else {}
    valid = (raw["pass_fail"] == "PASS" and "TB_RESULT PASS" in log and
             annotation.get("errors") == 0 and
             annotation.get("missing_timing_checks", 1) == 0 and
             not annotation.get("negative_separate_checks_limited", True) and
             not re.search(r"Timing violation|TB_X_FAIL|TB_FATAL", log, re.I) and
             int(raw["missing_expected_flits"]) == int(raw["unexpected_flits"]) == int(raw["timeout_hit"]) == 0 and
             int(raw["delivered_flits"]) == side["expected_copy_flits"] and
             int(raw["injected_flits"]) == side["input_flits"] and
             len(values) == trace["header"]["measurement_original_events"])
    seconds = (end - start) * 1e-12
    failure_class = "none"
    if re.search(r"Timing violation|TB_X_FAIL|TB_FATAL", log, re.I):
        failure_class = "timing_or_x"
    elif int(raw["unexpected_flits"]) or int(raw["delivered_flits"]) > side["expected_copy_flits"]:
        failure_class = "unexpected_or_duplicate"
    elif int(raw["timeout_hit"]):
        failure_class = "timeout_unclassified"
    elif not valid:
        failure_class = "coverage_or_annotation"
    row = dict(design=design, benchmark=trace["header"]["benchmark_id"], seed=trace["header"]["seed"],
               load=trace["header"]["offered_load"], mode=mode, valid=valid,
               failure_class=failure_class,
               completed_originals=len(values), window_completed_originals=completed_window,
               original_transactions_s=completed_window / seconds,
               delivered_mflit_port_s=float(raw["delivered_mflit_port_s"]),
               delivery_fraction=int(raw["measurement_delivered_flits"]) / expected,
               expected_measurement_copy_flits=expected,
               copy_backlog=expected - int(raw["measurement_delivered_flits"]),
               mean_last_destination_ns=statistics.mean(values) if values and valid else None,
               mean_first_destination_ns=statistics.mean(first) if first and valid else None,
               mean_destination_ns=statistics.mean(average) if average and valid else None,
               input_flits=side["input_flits"], accepted_input_flits=int(raw["injected_flits"]),
               annotation_errors=annotation.get("errors"),
               annotation_warnings=annotation.get("warnings"),
               trace_sha256=sha(root / "traces" / f"{stem}.jsonl"))
    save(log_dir / "metrics.json", row)
    return row


def audit_annotation(args):
    path = Path(args.root) / "work" / args.design / "sdf_annotate.log"
    categories = Counter()
    errors = warnings = None
    with path.open(errors="replace") as stream:
        for line in stream:
            match = re.search(r"Warning-\[([^]]+)\]", line)
            if match:
                categories[match[1]] += 1
            match = re.search(r"Total errors:\s*(\d+)", line)
            if match:
                errors = int(match[1])
            match = re.search(r"Total warnings:\s*(\d+)", line)
            if match:
                warnings = int(match[1])
    result = dict(errors=errors, warnings=warnings, categories=dict(categories),
                  path=str(path), sha256=sha(path),
                  library_model_sha256=sha('/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v'),
                  missing_timing_checks=categories["SDFCOM_CFTC"],
                  negative_separate_checks_limited=categories["SDFCOM_NL"] > 0)
    save(path.with_name("annotation_status.json"), result)
    if errors != 0 or categories["SDFCOM_NL"] or categories["SDFCOM_CFTC"]:
        raise RuntimeError(f"annotation errors or missing summary: {result}")
    print("FORMAL256_ANNOTATION_AUDIT", result, flush=True)


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=("generate", "build-tb", "collect-case", "audit-annotation"))
    p.add_argument("--root", required=True)
    p.add_argument("--benchmark", choices=BENCHMARKS, action="append")
    p.add_argument("--seed", type=int, choices=SEEDS, action="append")
    p.add_argument("--load", type=int, choices=LOADS, action="append")
    p.add_argument("--small", action="store_true")
    p.add_argument("--repeated", action="store_true")
    p.add_argument("--design", choices=DESIGNS)
    p.add_argument("--stem")
    args = p.parse_args()
    ROOT = args.root
    if args.action == "audit-annotation":
        audit_annotation(args)
    elif args.action == "collect-case":
        print(json.dumps(collect_case(args.root, args.design, args.stem,
                                    "repeated" if args.repeated else "native")))
    else:
        (generate if args.action == "generate" else build_tb)(args)
