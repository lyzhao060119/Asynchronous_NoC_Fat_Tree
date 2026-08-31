#!/usr/bin/env python3
"""Run RouterWormholeMinimal Stage1 per-domain DEL profile sweep.

This script regenerates RTL for each profile before DC because DelayElement
unit selection is baked into emitted Verilog parameters.
"""
from __future__ import print_function

import argparse
import csv
import os
import re
import shutil
import subprocess
from pathlib import Path

import paramiko


P = "/home/ghy19/Asynchronous_Router"
REPO = Path(__file__).resolve().parents[2]
RESULT_DIR = Path(__file__).resolve().parent / "timing" / "results" / "wormhole_stage1"
UNITS = [250, 150, 125, 100, 75, 50]
COUNT_NAMES = ["DEL050", "DEL075", "DEL100", "DEL125", "DEL150", "DEL250"]


def profile_name(a, br, bg):
    return "STAGE1_A%d_BR%d_BG%d" % (a, br, bg)


def margin_profile_name(a, br, bg, om):
    return "STAGE1M_A%d_BR%d_BG%d_OM%d" % (a, br, bg, om)


def run_local(cmd, env):
    if cmd and cmd[0] == "sbt":
        sbt_exe = shutil.which("sbt") or shutil.which("sbt.bat") or shutil.which("sbt.cmd")
        if sbt_exe:
            cmd = [sbt_exe] + cmd[1:]
    print("LOCAL:", " ".join(cmd))
    subprocess.check_call(cmd, cwd=str(REPO), env=env)


def run_script(script, env):
    run_local(["python", str(REPO / script)], env)


def get_password_from_docs():
    for doc in (REPO / "docs").glob("*.md"):
        text = doc.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"^[ \t-]*密码[:：][ \t]*(\S+)", text, re.M)
        if m:
            return m.group(1)
    raise SystemExit("Set C1_PASS environment variable")


def connect(env):
    password = env.get("C1_PASS") or get_password_from_docs()
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(
        env.get("C1_HOST", "192.168.2.8"),
        username=env.get("C1_USER", "ghy19"),
        password=password,
        timeout=40,
        banner_timeout=90,
        allow_agent=False,
        look_for_keys=False,
    )
    return c


def ssh(c, cmd):
    _, o, e = c.exec_command(cmd)
    return o.read().decode(errors="replace") + e.read().decode(errors="replace")


def collect_profile(profile, env):
    c = connect(env)
    try:
        text = ssh(c, """
echo '==counts=='
for u in 050 075 100 125 150 250; do
  echo -n DEL${{u}}=; grep -cE "DEL${{u}}D1BWP" {P}/outputs/RouterL1WormholeMinimal_post.v 2>/dev/null
done
echo '==result=='
grep -E 'TB_RESULT|SDF_METRIC|setuphold|ERROR|violation' {P}/logs/gls_wormhole_minimal_sdf_run.log 2>/dev/null | tail -700
""".format(P=P))
    finally:
        c.close()

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    (RESULT_DIR / ("%s.log" % profile)).write_text(text, encoding="utf-8")

    counts = {}
    for name in COUNT_NAMES:
        m = re.search(r"%s=(\d+)" % name, text)
        counts[name] = int(m.group(1)) if m else 0

    passed = "TB_RESULT PASS" in text
    rows = []
    metric_re = re.compile(
        r"SDF_METRIC\s+domain=(\S+)\s+name=(\S+)\s+idx=(\d+)\s+value_ns=([-+0-9.]+)"
    )
    for m in metric_re.finditer(text):
        row = {
            "profile": profile,
            "pass": "PASS" if passed else "FAIL",
            "domain": m.group(1),
            "metric": m.group(2),
            "idx": m.group(3),
            "value_ns": m.group(4),
        }
        row.update(counts)
        rows.append(row)
    if not rows:
        row = {
            "profile": profile,
            "pass": "PASS" if passed else "FAIL",
            "domain": "NA",
            "metric": "NO_METRICS",
            "idx": "-1",
            "value_ns": "NA",
        }
        row.update(counts)
        rows.append(row)
    return passed, rows


def run_profile(profile, env_base):
    env = env_base.copy()
    env["SBT_OPTS"] = "-Dsbt.server=false"
    env["ASYNC_PRIMITIVES"] = "asic"
    env["ASYNC_DELAY_PROFILE"] = profile
    env["GLS_PROBE"] = "1"
    print("=== PROFILE %s: generate ===" % profile)
    run_local(["sbt", "runMain Router_Architecture.instantiation.RouterL1WormholeMinimal"], env)
    print("=== PROFILE %s: dc ===" % profile)
    run_script("scripts/asic_dc/run_dc_wormhole_minimal.py", env)
    print("=== PROFILE %s: sdf ===" % profile)
    env["GLS_SMOKE_STAGE"] = "sdf_wormhole_minimal"
    run_script("scripts/asic_dc/upload_and_run_gls_smoke.py", env)
    return collect_profile(profile, env)


def choose_min_passing(env_base):
    all_rows = []
    cache = {}

    def cached(profile):
        if profile not in cache:
            cache[profile] = run_profile(profile, env_base)
        return cache[profile]

    safe_profile = profile_name(250, 250, 250)
    safe_passed, safe_rows = cached(safe_profile)
    all_rows.extend(safe_rows)
    if not safe_passed:
        return "NO_PASSING_PROFILE", all_rows

    best_a = 250
    best_br = 250
    best_bg = 250

    for a in [250, 150, 100, 75]:
        profile = profile_name(a, 250, 250)
        if profile == safe_profile:
            passed = True
        else:
            passed, rows = cached(profile)
            all_rows.extend(rows)
        if passed:
            best_a = a
        else:
            break

    for br in [250, 150, 100, 75]:
        profile = profile_name(best_a, br, 250)
        if profile in cache:
            passed, _ = cache[profile]
        else:
            passed, rows = cached(profile)
            all_rows.extend(rows)
        if passed:
            best_br = br
        else:
            break

    for bg in [250, 150, 100, 75]:
        profile = profile_name(best_a, best_br, bg)
        if profile in cache:
            passed, _ = cache[profile]
        else:
            passed, rows = cached(profile)
            all_rows.extend(rows)
        if passed:
            best_bg = bg
        else:
            break

    return profile_name(best_a, best_br, best_bg), all_rows


def choose_margin_min_passing(env_base):
    all_rows = []
    cache = {}

    def cached(profile):
        if profile not in cache:
            cache[profile] = run_profile(profile, env_base)
        return cache[profile]

    bringup = [
        margin_profile_name(250, 250, 250, 250),
        margin_profile_name(75, 75, 250, 250),
        margin_profile_name(75, 75, 150, 150),
    ]
    last_pass = "NO_PASSING_PROFILE"
    for profile in bringup:
        passed, rows = cached(profile)
        all_rows.extend(rows)
        if not passed:
            return last_pass, all_rows
        last_pass = profile

    return last_pass, all_rows


def usable_delay_units():
    inv = RESULT_DIR / "delay_cell_inventory.csv"
    usable = set([75, 100, 150, 250])
    if not inv.exists():
        return usable
    with inv.open(newline="", encoding="utf-8") as f:
        for row in csv.DictReader(f):
            if row.get("usable") == "YES":
                usable.add(int(row["unit"]))
    return usable


def choose_target12(env_base, stop_on_fail=False):
    usable = usable_delay_units()
    profiles = [margin_profile_name(75, 75, 150, 150)]
    if 125 in usable:
        profiles.append(margin_profile_name(75, 75, 150, 125))
    profiles.append(margin_profile_name(75, 75, 150, 100))
    if 125 in usable:
        profiles.append(margin_profile_name(75, 75, 125, 150))
    profiles.append(margin_profile_name(75, 75, 100, 150))
    if 125 in usable:
        profiles.append(margin_profile_name(75, 75, 125, 125))
    if 50 in usable:
        # DEL050 is exploratory only; keep BG/OM at the best 125 candidate when available.
        bg = 125 if 125 in usable else 150
        om = 125 if 125 in usable else 150
        profiles.append(margin_profile_name(75, 50, bg, om))
        profiles.append(margin_profile_name(50, 50, bg, om))

    all_rows = []
    best_profile = "NO_PASSING_PROFILE"
    best_head = None
    seen = set()
    for profile in profiles:
        if profile in seen:
            continue
        seen.add(profile)
        passed, rows = run_profile(profile, env_base)
        all_rows.extend(rows)
        head_vals = [
            float(r["value_ns"]) for r in rows
            if r["metric"] == "E2E_head_REQ_EDGE_NS" and r["value_ns"] != "NA"
        ]
        head = head_vals[0] if head_vals else None
        if passed and head is not None and (best_head is None or head < best_head):
            best_profile = profile
            best_head = head
        if stop_on_fail and not passed:
            break
    return best_profile, all_rows


def write_profile_summary(rows, recommended):
    by_profile = {}
    for row in rows:
        item = by_profile.setdefault(row["profile"], {"profile": row["profile"], "pass": row["pass"]})
        item["pass"] = row["pass"]
        if row["metric"] in (
            "E2E_head_REQ_EDGE_NS",
            "E2E_body_REQ_EDGE_NS",
            "E2E_tail_REQ_EDGE_NS",
            "T_del_global",
            "T_out_req_after_global",
            "T_output_data_to_req_setup",
            "T_data_setup_B",
            "T_mask_setup_B",
            "T_globalCommitEvent_pw",
        ):
            item[row["metric"]] = row["value_ns"]
    path = RESULT_DIR / "stage1_delay_sweep_profile_summary.csv"
    fields = [
        "profile", "pass", "E2E_head_REQ_EDGE_NS", "E2E_body_REQ_EDGE_NS",
        "E2E_tail_REQ_EDGE_NS", "T_del_global", "T_out_req_after_global",
        "T_output_data_to_req_setup", "T_data_setup_B", "T_mask_setup_B",
        "T_globalCommitEvent_pw", "recommended",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for profile in by_profile:
            item = by_profile[profile]
            item["recommended"] = "YES" if profile == recommended else ""
            w.writerow(item)
    print("WROTE", path)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument(
        "--profiles",
        default="auto",
        help="auto, auto_margin, target12, or comma-separated ASYNC_DELAY_PROFILE list",
    )
    ap.add_argument(
        "--stop-on-fail",
        action="store_true",
        help="stop after the first failed SDF profile",
    )
    args = ap.parse_args()

    env_base = os.environ.copy()
    if "C1_PASS" not in env_base:
        get_password_from_docs()

    mode = args.profiles.strip().lower()
    if mode == "auto":
        recommended, all_rows = choose_min_passing(env_base)
    elif mode == "auto_margin":
        recommended, all_rows = choose_margin_min_passing(env_base)
    elif mode == "target12":
        recommended, all_rows = choose_target12(env_base, args.stop_on_fail)
    else:
        recommended = ""
        all_rows = []
        for profile in [p.strip() for p in args.profiles.split(",") if p.strip()]:
            passed, rows = run_profile(profile, env_base)
            all_rows.extend(rows)
            if passed:
                recommended = profile
            if args.stop_on_fail and not passed:
                break

    RESULT_DIR.mkdir(parents=True, exist_ok=True)
    csv_path = RESULT_DIR / "stage1_delay_sweep.csv"
    fieldnames = [
        "profile", "pass", "domain", "metric", "idx", "value_ns",
    ] + COUNT_NAMES
    with csv_path.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for row in all_rows:
            w.writerow(row)
    print("WROTE", csv_path)
    write_profile_summary(all_rows, recommended)
    summary_path = RESULT_DIR / "stage1_delay_sweep_summary.txt"
    summary_path.write_text("recommended_profile=%s\n" % recommended, encoding="utf-8")
    print("RECOMMENDED", recommended)
    print("WROTE", summary_path)


if __name__ == "__main__":
    main()
