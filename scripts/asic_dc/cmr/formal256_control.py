#!/usr/bin/env python3
"""LSF smoke gates and independent one-core scan grids for formal256."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import re
import shlex
import subprocess


def main():
    p = argparse.ArgumentParser()
    p.add_argument("action", choices=("gate", "grid", "schedule-finish", "finish", "report"))
    p.add_argument("--root", required=True)
    p.add_argument("--design", choices=("Mesh256", "M16_256"))
    p.add_argument("--benchmark")
    p.add_argument("--seed", type=int)
    a = p.parse_args()
    root = Path(a.root)
    spec = importlib.util.spec_from_file_location("campaign", root / "formal256_campaign.py")
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    m.ROOT = str(root)
    env = dict(os.environ, FORMAL256_ROOT=str(root))

    if a.action == "finish":
        finish(root, m)
        return
    if a.action == "report":
        report(root, m)
        return
    if a.action == "schedule-finish":
        jobs = []
        for design in m.DESIGNS:
            jobs.extend(json.loads((root / "manifests" / f"grid_jobs_{design}.json").read_text()))
        dependency = " && ".join(f"ended({j['job_id']})" for j in jobs)
        out = subprocess.check_output(["bsub", "-q", "normal", "-n", "1", "-w", dependency,
            "-J", "f256_select_repeat", "-o", str(root / "jobs/finish.log"),
            "-e", str(root / "jobs/finish.err"),
            f"/soft/GNU/python3.12/bin/python3 {root}/formal256_control.py finish --root {root}"], text=True)
        m.save(root / "manifests/finish_job.json", dict(submission=out, dependencies=jobs))
        print(out, flush=True)
        return

    def run(stem):
        subprocess.run(["bash", str(root / "run_formal256.sh"), a.design, "run", stem],
                       env=env, check=True)
        data = json.loads((root / "logs" / a.design / stem / "metrics.json").read_text())
        if not data["valid"]:
            raise RuntimeError(f"invalid original-event metrics: {stem}")

    if a.action == "gate":
        rows = json.loads((root / "manifests/inputs.json").read_text())
        if len(rows) != 270:
            raise RuntimeError("canonical input coverage is incomplete")
        for row in rows:
            if m.sha(row["trace"]) != row["trace_sha256"]:
                raise RuntimeError("trace hash mismatch")
            c = row["cases"][a.design]
            if m.sha(c["path"]) != c["sha256"]:
                raise RuntimeError("case hash mismatch")
        run("IDENTITY18_n256_s202701_m5_small")
        subprocess.run(["bash", str(root / "run_formal256.sh"), a.design, "negative"], env=env, check=True)
        for b in m.BENCHMARKS:
            # Small cases exercise the same generator/scoreboard as production.
            for seed in m.SEEDS:
                stem = f"{b}_n256_s{seed}_m5_small"
                run(stem)
            for seed in m.SEEDS:
                run(f"{b}_n256_s{seed}_m5")
        print("FORMAL256_SMOKE_GATE_PASS", a.design, flush=True)
        jobs = []
        for b in m.BENCHMARKS:
            for seed in m.SEEDS:
                command = ["/soft/GNU/python3.12/bin/python3", str(root / "formal256_control.py"),
                           "grid", "--root", str(root), "--design", a.design,
                           "--benchmark", b, "--seed", str(seed)]
                log = root / "jobs" / f"grid_{a.design}_{b}_{seed}.log"
                out = subprocess.check_output(["bsub", "-q", "normal", "-n", "1", "-J",
                    f"f256_{a.design}_{b}_{seed}", "-o", str(log), "-e", str(log) + ".err",
                    shlex.join(command)], text=True)
                match = re.search(r"Job <(\d+)>", out)
                if not match:
                    raise RuntimeError(out)
                jobs.append(dict(job_id=match[1], benchmark=b, seed=seed, log=str(log)))
                print("FORMAL256_GRID_SUBMITTED", jobs[-1], flush=True)
        m.save(root / "manifests" / f"grid_jobs_{a.design}.json", jobs)
        return
    results = []
    for load in m.LOADS[1:]:
        if (root / "manifests" / f"HALT_{a.design}.json").exists():
            raise RuntimeError("design halted after a correctness failure")
        stem = f"{a.benchmark}_n256_s{a.seed}_m{load}"
        try:
            run(stem)
            status = "PASS"
        except (subprocess.CalledProcessError, RuntimeError) as exc:
            log = root / "logs" / a.design / stem / "run.log"
            text = log.read_text(errors="replace") if log.exists() else ""
            status = "FAIL"
            print("FORMAL256_CASE_FAILURE", stem, str(exc), flush=True)
            # Data/timing correctness failures stop this grid; pressure timeouts
            # remain recorded and do not hide later independent load points.
            rawfile = root / "results" / a.design / f"{stem}.csv"
            unexpected = False
            if rawfile.exists():
                import csv
                with rawfile.open() as f:
                    raw = next(csv.DictReader(f))
                    unexpected = int(raw["unexpected_flits"]) > 0
            if unexpected or re.search(r"TB_X_FAIL|Timing violation|TB_FATAL", text, re.I):
                m.save(root / "manifests" / f"HALT_{a.design}.json",
                       dict(stem=stem, reason="correctness_failure"))
                m.save(root / "manifests" / f"stopped_{a.design}_{a.benchmark}_{a.seed}.json",
                       dict(stem=stem, reason="correctness_failure"))
                raise
        results.append(dict(load=load, status=status))
        m.save(root / "manifests" / f"progress_{a.design}_{a.benchmark}_{a.seed}.json", results)
    print("FORMAL256_GRID_COMPLETE", a.design, a.benchmark, a.seed, results, flush=True)


def finish(root, m):
    """Audit every native point, select quarter-saturation loads, queue Repeated."""
    import statistics
    points = {}
    missing = []
    for d in m.DESIGNS:
        for b in m.BENCHMARKS:
            for s in m.SEEDS:
                for load in m.LOADS:
                    stem = f"{b}_n256_s{s}_m{load}"
                    path = root / "logs" / d / stem / "metrics.json"
                    if not path.exists():
                        missing.append(str(path))
                        continue
                    points[d, b, s, load] = json.loads(path.read_text())
    m.save(root / "manifests/native_coverage.json", dict(expected=540, measured=len(points), missing=missing))
    if missing:
        raise RuntimeError(f"{len(missing)} points have no metrics; inspect failures before continuing")
    selection = []
    repeated_jobs = []
    repeated_inputs = []
    for b in m.BENCHMARKS[1:]:
        rates = {load: statistics.mean(points["Mesh256", b, s, load]["delivered_mflit_port_s"]
                                      for s in m.SEEDS) for load in m.LOADS
                 if all(points["Mesh256", b, s, load]["valid"] for s in m.SEEDS)}
        if not rates:
            raise RuntimeError(f"no valid three-seed rates for {b}")
        peak = max(rates.values())
        saturation = next(load for load in m.LOADS if rates.get(load, -1) >= 0.99 * peak)
        if saturation == m.LOADS[-1] and rates.get(700, 0) < 0.95 * rates[800]:
            raise RuntimeError(f"saturation not bounded within the load grid: {b}")
        eligible = [load for load in m.LOADS if load <= saturation * 0.25 and
                    all(points["Mesh256", b, s, load]["valid"] and
                        points["Mesh256", b, s, load]["delivery_fraction"] >= 0.99 for s in m.SEEDS)]
        if not eligible:
            raise RuntimeError(f"no eligible quarter-saturation point for {b}")
        chosen = max(eligible)
        selection.append(dict(benchmark=b, saturation=saturation, selected=chosen,
                              actual_fraction=chosen / saturation, rates=rates))
        for seed in m.SEEDS:
            stem = f"{b}_n256_s{seed}_m{chosen}"
            trace = m.modules(root).load_jsonl(root / "traces" / f"{stem}.jsonl")
            cases = m.materialize(root, trace, stem, repeated=True)
            repeated_inputs.append(dict(benchmark=b, seed=seed, load=chosen,
                                        trace_sha256=m.sha(root / "traces" / f"{stem}.jsonl"),
                                        cases=cases))
            m.save(root / "manifests/repeated_inputs.json", repeated_inputs)
            for d in m.DESIGNS:
                log = root / "jobs" / f"repeated_{d}_{b}_{seed}.log"
                cmd = f"env FORMAL256_ROOT={shlex.quote(str(root))} bash {root}/run_formal256.sh {d} run {stem} repeated"
                out = subprocess.check_output(["bsub", "-q", "normal", "-n", "1", "-J",
                    f"f256_repeat_{d}_{seed}", "-o", str(log), "-e", str(log)+".err", cmd], text=True)
                match = re.search(r"Job <(\d+)>", out)
                if not match:
                    raise RuntimeError(out)
                repeated_jobs.append(dict(design=d, benchmark=b, seed=seed, load=chosen,
                                          job_id=match[1], log=str(log)))
                m.save(root / "manifests/repeated_jobs.json", repeated_jobs)
    m.save(root / "manifests/quarter_saturation.json", selection)
    dep = " && ".join(f"ended({j['job_id']})" for j in repeated_jobs)
    out = subprocess.check_output(["bsub", "-q", "normal", "-n", "1", "-w", dep,
        "-J", "f256_report", "-o", str(root / "jobs/report.log"), "-e", str(root / "jobs/report.err"),
        f"/soft/GNU/python3.12/bin/python3 {root}/formal256_control.py report --root {root}"], text=True)
    m.save(root / "manifests/report_job.json", dict(submission=out))
    print("FORMAL256_REPEATED_SUBMITTED", len(repeated_jobs), flush=True)


def report(root, m):
    import csv
    import statistics
    records = []
    missing = []
    for design in m.DESIGNS:
        for b in m.BENCHMARKS:
            for seed in m.SEEDS:
                for load in m.LOADS:
                    stem = f"{b}_n256_s{seed}_m{load}"
                    path = root / "logs" / design / stem / "metrics.json"
                    if path.exists():
                        records.append(json.loads(path.read_text()))
                    else:
                        missing.append(str(path))
    jobs = json.loads((root / "manifests/repeated_jobs.json").read_text())
    for job in jobs:
        stem = f"{job['benchmark']}_n256_s{job['seed']}_m{job['load']}_repeated"
        path = root / "logs" / job["design"] / stem / "metrics.json"
        if path.exists():
            records.append(json.loads(path.read_text()))
        else:
            missing.append(str(path))
    target = root / "summary"
    target.mkdir(exist_ok=True)
    if records:
        with (target / "raw_metrics.csv").open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(records[0]))
            writer.writeheader()
            writer.writerows(records)
    groups = {}
    for row in records:
        key = (row["design"], row["benchmark"], row["load"], row["mode"])
        groups.setdefault(key, []).append(row)
    means = []
    columns = ("mean_last_destination_ns", "mean_first_destination_ns", "mean_destination_ns",
               "original_transactions_s", "delivered_mflit_port_s", "delivery_fraction", "copy_backlog")
    for (d, b, load, mode), rows in sorted(groups.items()):
        row = dict(design=d, benchmark=b, load=load, mode=mode, seeds=len(rows),
                   valid_seeds=sum(bool(r["valid"]) for r in rows),
                   latency_curve_eligible=all(r["valid"] and r["delivery_fraction"] >= .99 for r in rows) and len(rows) == 3)
        for col in columns:
            vals = [r[col] for r in rows if r.get(col) is not None]
            row[col + "_n"] = len(vals)
            row[col + "_mean"] = statistics.mean(vals) if vals else None
            row[col + "_std"] = statistics.stdev(vals) if len(vals) > 1 else None
        means.append(row)
    if means:
        with (target / "three_seed_means.csv").open("w", newline="") as f:
            writer = csv.DictWriter(f, fieldnames=list(means[0]))
            writer.writeheader()
            writer.writerows(means)
    status = dict(expected=552, measured=len(records), missing=missing,
                  valid=sum(bool(r["valid"]) for r in records),
                  invalid=sum(not r["valid"] for r in records),
                  complete=len(records) == 552 and not missing)
    m.save(target / "coverage.json", status)
    print("FORMAL256_REPORT", status, flush=True)


if __name__ == "__main__":
    main()
