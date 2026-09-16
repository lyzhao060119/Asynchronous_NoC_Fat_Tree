#!/usr/bin/env python3
"""E1 wrap-up: archive PFAT64 UR fill + assemble three-DUT ASAP UR figure.

Sources:
  PROP_temp64 / FM64 — local 30-pt aggregated CSV (already paper-facing)
  PFAT64 M5–M200 — remote 20260913_1310_cmr_pfat64_rpsdel050_asap_uc_m5_200
  PFAT64 M220–M800 — remote 20260915_091759_cmr_pfat64_asap_uc_m220_800_1248
  PFAT64 netlist — 20260915_080229_cmr_pfat64_rpsdel050_1248 (fill); historical
                   GLS reused for low loads under prior netlist ID noted in manifest

Fail-closed: all 30 PFAT points must be PASS 55000/55000 with SDF done.
Latency panel uses near-lossless only (delivery_ratio>=0.99 and backlog<=5).
"""
from __future__ import annotations

import csv
import argparse
import hashlib
import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import matplotlib.pyplot as plt
from matplotlib.ticker import LogLocator, NullFormatter

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]  # scripts/asic_dc/cmr -> repo root
sys.path.insert(0, str(HERE))

from _tmp_paper64_common import (  # noqa: E402
    FROZEN_FM64,
    FROZEN_PROP_TEMP64,
    LOADS,
    connect_failover,
    remote_run_failover,
)
from run_remote_prop_temp64 import ROOT  # noqa: E402

PROP_FM_CSV = (
    REPO
    / "DATE paper"
    / "experiments"
    / "figures"
    / "paper64"
    / "20260914_092324_asap_uc_m5_800_mesh64_prop_temp64"
    / "aggregated_metrics.csv"
)
PFAT_HIST_GLS = "20260913_1310_cmr_pfat64_rpsdel050_asap_uc_m5_200"
PFAT_FILL_GLS = "20260915_091759_cmr_pfat64_asap_uc_m220_800_1248"
PFAT_NETLIST_NEW = "20260915_080229_cmr_pfat64_rpsdel050_1248"
PFAT_NETLIST_HIST = "20260912_195012_cmr_pfat64_rpsdel050_1248"
HIST_LOADS = (5, 10, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200)
FILL_LOADS = tuple(load for load in LOADS if load not in HIST_LOADS)

STYLE = {
    "FM64": {"label": "FlatMesh64 DEL150", "color": "#1f77b4", "marker": "o", "z": 3},
    "PFAT64": {"label": "PFAT64 1-2-4-8 DEL050", "color": "#2ca02c", "marker": "^", "z": 2},
    "PROP_temp64": {"label": "PROP_temp64 B8 DEL050", "color": "#d62728", "marker": "s", "z": 4},
}


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def git_evidence() -> tuple[str, bool]:
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=REPO, text=True).strip()
    dirty = bool(
        subprocess.check_output(
            ["git", "status", "--short"], cwd=REPO, text=True, errors="replace"
        ).strip()
    )
    return commit, dirty


def pfat_case(load: int) -> str:
    return "TOPO-UR_n64_s202701_m%d_PFAT64_top8" % load


def near_lossless(row: dict) -> bool:
    offered = float(row["measurement_offered_flits"])
    delivered = float(row["measurement_delivered_flits"])
    backlog = float(row["measurement_backlog_flits"])
    if offered <= 0:
        return False
    return (delivered / offered) >= 0.99 and backlog <= 5


def fetch_pfat_rows(client, fill_archive: Path | None = None) -> tuple[list[dict], dict[str, bytes]]:
    import io

    sftp = client.open_sftp()
    artifacts: dict[str, bytes] = {}
    rows: list[dict] = []
    try:
        for load, gls, netlist in (
            *[(load, PFAT_HIST_GLS, PFAT_NETLIST_HIST) for load in HIST_LOADS],
            *[(load, PFAT_FILL_GLS, PFAT_NETLIST_NEW) for load in FILL_LOADS],
        ):
            name = pfat_case(load)
            csv_remote = f"{ROOT}/results/{gls}/csv/sdf_{name}.csv"
            run_remote = f"{ROOT}/logs/gls/{gls}/sdf/{name}/run.log"
            local_case = (fill_archive / "cases" / name) if fill_archive and load in FILL_LOADS else None
            if local_case is not None:
                csv_data = (local_case / "result.csv").read_bytes()
                run_data = (local_case / "run.log").read_bytes()
            else:
                with sftp.file(csv_remote, "rb") as fh:
                    csv_data = fh.read()
                with sftp.file(run_remote, "rb") as fh:
                    run_data = fh.read()
            if not csv_data or not run_data:
                raise RuntimeError(f"empty artifact for {name}")
            artifacts[f"pfat64/csv/sdf_{name}.csv"] = csv_data
            artifacts[f"pfat64/run/{name}.run.log"] = run_data
            row = list(csv.DictReader(io.StringIO(csv_data.decode("utf-8"))))
            if len(row) != 1:
                raise RuntimeError(f"{name}: expected 1 CSV row")
            r = row[0]
            run_text = run_data.decode("utf-8", errors="replace")
            if r.get("pass_fail") != "PASS":
                raise RuntimeError(f"{name}: pass_fail={r.get('pass_fail')}")
            if "TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0" not in run_text:
                raise RuntimeError(f"{name}: full-drain TB_RESULT missing")
            if "Doing SDF annotation ...... Done" not in run_text:
                raise RuntimeError(f"{name}: SDF annotation missing")
            out = {
                "design": "PFAT64",
                "design_label": "PFAT64 1-2-4-8 DEL050",
                "netlist_run_id": netlist,
                "gls_run_id": gls,
                "load_setpoint_mflit_per_port_s": load,
                "injected_flits": int(r["injected_flits"]),
                "delivered_flits": int(r["delivered_flits"]),
                "missing": int(r["missing_expected_flits"]),
                "unexpected": int(r["unexpected_flits"]),
                "timeout": int(r["timeout_hit"]),
                "measurement_offered_flits": int(r["measurement_offered_flits"]),
                "measurement_delivered_flits": int(r["measurement_delivered_flits"]),
                "measurement_backlog_flits": int(float(r["measurement_backlog_flits"])),
                "offered_mflit_per_port_s": float(r["offered_mflit_port_s"]),
                "delivered_mflit_per_port_s": float(r["delivered_mflit_port_s"]),
                "backlog": int(float(r["measurement_backlog_flits"])),
                "flit_latency_mean_ns": float(r["flit_lat_mean_ns"]),
                "flit_latency_p50_ns": float(r.get("flit_lat_p50_ns") or 0),
                "flit_latency_p95_ns": float(r.get("flit_lat_p95_ns") or 0),
                "flit_latency_p99_ns": float(r.get("flit_lat_p99_ns") or 0),
                "pass_fail": "PASS",
                "case": name,
                "result_csv_sha256": sha256_bytes(csv_data),
                "run_log_sha256": sha256_bytes(run_data),
            }
            out["near_lossless"] = near_lossless(out)
            out["latency_claim_eligible"] = out["near_lossless"]
            rows.append(out)
            print("PFAT_OK", load, "delivered", out["delivered_mflit_per_port_s"], "nl", out["near_lossless"], flush=True)
    finally:
        sftp.close()
    if len(rows) != 30:
        raise RuntimeError(f"expected 30 PFAT rows, got {len(rows)}")
    return rows, artifacts


def load_prop_fm() -> list[dict]:
    rows = []
    with PROP_FM_CSV.open(encoding="utf-8", newline="") as fh:
        for r in csv.DictReader(fh):
            backlog = int(float(r["backlog"]))
            inj = int(r["injected_flits"])
            deliv = int(r["delivered_flits"])
            # PROP/FM historical CSV uses end-of-run backlog; for near-lossless
            # reuse backlog<=5 and full drain as provisional gate matching prior audit.
            nl = inj == 55000 and deliv == 55000 and backlog <= 5
            # Also require delivery of measurement if columns exist — they don't;
            # approximate with end-of-run backlog gate used in paper figures.
            out = {
                "design": r["design"],
                "design_label": r["design_label"],
                "netlist_run_id": r["netlist_run_id"],
                "gls_run_id": r["gls_run_id"],
                "load_setpoint_mflit_per_port_s": int(r["load_setpoint_mflit_per_port_s"]),
                "injected_flits": inj,
                "delivered_flits": deliv,
                "missing": int(r["missing"]),
                "unexpected": int(r["unexpected"]),
                "timeout": int(r["timeout"]),
                "measurement_offered_flits": "",
                "measurement_delivered_flits": "",
                "measurement_backlog_flits": backlog,
                "offered_mflit_per_port_s": float(r["offered_mflit_per_port_s"]),
                "delivered_mflit_per_port_s": float(r["delivered_mflit_per_port_s"]),
                "backlog": backlog,
                "flit_latency_mean_ns": float(r["flit_latency_mean_ns"]),
                "flit_latency_p50_ns": float(r.get("flit_latency_p50_ns") or 0),
                "flit_latency_p95_ns": float(r.get("flit_latency_p95_ns") or 0),
                "flit_latency_p99_ns": float(r.get("flit_latency_p99_ns") or 0),
                "pass_fail": r["pass_fail"],
                "case": r["case"],
                "result_csv_sha256": "",
                "run_log_sha256": "",
                "near_lossless": nl,
                "latency_claim_eligible": nl,
            }
            if out["pass_fail"] != "PASS":
                raise RuntimeError(f"PROP/FM not PASS: {out['case']}")
            rows.append(out)
    if len(rows) != 60:
        raise RuntimeError(f"expected 60 PROP/FM rows, got {len(rows)}")
    return rows


def saturation_summary(rows: list[dict]) -> list[dict]:
    out = []
    for design in ("PROP_temp64", "PFAT64", "FM64"):
        sel = [r for r in rows if r["design"] == design]
        peak = max(sel, key=lambda r: float(r["delivered_mflit_per_port_s"]))
        eligible = [r for r in sel if r["near_lossless"]]
        near = max(eligible, key=lambda r: int(r["load_setpoint_mflit_per_port_s"])) if eligible else None
        out.append(
            {
                "design": design,
                "peak_load_setpoint": peak["load_setpoint_mflit_per_port_s"],
                "peak_delivered_mflit_per_port_s": peak["delivered_mflit_per_port_s"],
                "near_lossless_load_setpoint": near["load_setpoint_mflit_per_port_s"] if near else "",
                "near_lossless_delivered_mflit_per_port_s": near["delivered_mflit_per_port_s"] if near else "",
                "near_lossless_criterion": "delivery_ratio>=0.99 and backlog<=5 (PFAT measurement; PROP/FM end-of-run backlog proxy)",
            }
        )
    return out


def plot_three(rows: list[dict], out_dir: Path) -> list[str]:
    fig, (ax_tp, ax_lat) = plt.subplots(1, 2, figsize=(9.2, 3.5), constrained_layout=True)
    xmax = max(float(r["offered_mflit_per_port_s"]) for r in rows)
    ymax = max(float(r["delivered_mflit_per_port_s"]) for r in rows)
    lim = max(xmax, ymax) * 1.05
    ax_tp.plot([0, lim], [0, lim], "--", color="#7f7f7f", lw=1.0, label="Ideal", zorder=1)
    for design in ("FM64", "PFAT64", "PROP_temp64"):
        st = STYLE[design]
        sel = sorted(
            (r for r in rows if r["design"] == design),
            key=lambda r: float(r["offered_mflit_per_port_s"]),
        )
        ax_tp.plot(
            [float(r["offered_mflit_per_port_s"]) for r in sel],
            [float(r["delivered_mflit_per_port_s"]) for r in sel],
            color=st["color"], marker=st["marker"], ms=4.2, lw=1.35, label=st["label"], zorder=st["z"],
        )
        elig = [r for r in sel if r["latency_claim_eligible"]]
        ax_lat.plot(
            [float(r["offered_mflit_per_port_s"]) for r in elig],
            [float(r["flit_latency_mean_ns"]) for r in elig],
            color=st["color"], marker=st["marker"], ms=4.2, lw=1.35, label=st["label"], zorder=st["z"],
        )
    ax_tp.set(xlabel="Offered load (Mflit/s/port)", ylabel="Delivered throughput (Mflit/s/port)")
    ax_tp.set_xlim(0, lim)
    ax_tp.set_ylim(0, lim)
    ax_tp.set_aspect("equal", adjustable="box")
    ax_tp.grid(True, ls=":", alpha=0.65)
    ax_tp.legend(fontsize=8, loc="upper left")
    ax_lat.set(xlabel="Offered load (Mflit/s/port)", ylabel="Mean flit latency (ns)", title="Pre-saturation / near-lossless")
    ax_lat.set_xlim(0, lim)
    ax_lat.set_yscale("log")
    ax_lat.yaxis.set_major_locator(LogLocator(base=10.0))
    ax_lat.yaxis.set_minor_locator(LogLocator(base=10.0, subs=(2, 3, 4, 5, 6, 7, 8, 9)))
    ax_lat.yaxis.set_minor_formatter(NullFormatter())
    ax_lat.grid(True, which="major", ls=":", alpha=0.65)
    ax_lat.legend(fontsize=8, loc="upper left")
    names = [
        "three-dut-ur-throughput-pre-saturation-latency.png",
        "three-dut-ur-throughput-pre-saturation-latency.pdf",
    ]
    fig.savefig(out_dir / names[0], dpi=300, bbox_inches="tight")
    fig.savefig(out_dir / names[1], bbox_inches="tight")
    plt.close(fig)
    return names


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pfat-fill-archive", type=Path,
                        help="hash-verified output of run_e1_pfat64_ur_fill.py collect")
    args = parser.parse_args()
    if args.pfat_fill_archive is not None:
        archive = args.pfat_fill_archive.resolve()
        manifest = archive / "manifest.json"
        if not manifest.is_file() or not (archive / "acceptance.csv").is_file():
            raise SystemExit("invalid PFAT fill archive: missing manifest/acceptance")
        accepted = list(csv.DictReader((archive / "acceptance.csv").open(encoding="utf-8", newline="")))
        if len(accepted) != len(FILL_LOADS) or any(row.get("pass") != "True" for row in accepted):
            raise SystemExit("PFAT fill archive is not an accepted 18-point collection")
    else:
        archive = None
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    raw_root = REPO / "DATE paper" / "experiments" / "raw" / "paper64" / f"e1_ur_three_dut_{stamp}"
    fig_dir = REPO / "DATE paper" / "experiments" / "figures" / "paper64" / f"e1_ur_three_dut_{stamp}"
    if raw_root.exists() or fig_dir.exists():
        raise SystemExit("refusing to overwrite existing archive/figure dirs")
    raw_root.mkdir(parents=True)
    fig_dir.mkdir(parents=True)

    prop_fm = load_prop_fm()
    client = connect_failover()
    try:
        pfat_rows, artifacts = fetch_pfat_rows(client, archive)
        # optional DC hashes for new netlist
        sftp = client.open_sftp()
        try:
            for rel in ("NoC_64nodes_post.v", "NoC_64nodes.sdf"):
                remote = f"{ROOT}/outputs/{PFAT_NETLIST_NEW}/{rel}"
                with sftp.file(remote, "rb") as fh:
                    # only hash first 0 bytes marker via remote sha if large — store sha via remote
                    pass
            client, hash_out = remote_run_failover(
                client,
                f"sha256sum {ROOT}/outputs/{PFAT_NETLIST_NEW}/NoC_64nodes_post.v "
                f"{ROOT}/outputs/{PFAT_NETLIST_NEW}/NoC_64nodes.sdf",
            )
            (raw_root / "pfat64_netlist_hashes.txt").write_text(hash_out + "\n", encoding="utf-8")
        finally:
            sftp.close()
    finally:
        client.close()

    for rel, data in artifacts.items():
        path = raw_root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    all_rows = prop_fm + pfat_rows
    all_rows.sort(key=lambda r: (r["design"], int(r["load_setpoint_mflit_per_port_s"])))
    write_csv(raw_root / "summary.csv", all_rows)
    write_csv(raw_root / "acceptance.csv", all_rows)
    write_csv(fig_dir / "summary.csv", all_rows)
    write_csv(fig_dir / "aggregated_metrics.csv", all_rows)
    sat = saturation_summary(all_rows)
    write_csv(raw_root / "saturation_summary.csv", sat)
    write_csv(fig_dir / "saturation_summary.csv", sat)

    # hashes of published summaries
    hash_lines = []
    for path in (
        raw_root / "summary.csv",
        raw_root / "acceptance.csv",
        raw_root / "saturation_summary.csv",
        PROP_FM_CSV,
    ):
        hash_lines.append(f"{sha256_file(path)}  {path.relative_to(REPO).as_posix()}")
    for rel, data in artifacts.items():
        hash_lines.append(f"{sha256_bytes(data)}  {rel}")
    (raw_root / "hashes.sha256").write_text("\n".join(hash_lines) + "\n", encoding="utf-8")

    figs = plot_three(all_rows, fig_dir)
    commit, dirty = git_evidence()
    (raw_root / "git_status_short.txt").write_text(
        subprocess.check_output(["git", "status", "--short"], cwd=REPO, text=True, errors="replace"),
        encoding="utf-8",
    )
    nl_counts = {
        d: sum(1 for r in all_rows if r["design"] == d and r["near_lossless"])
        for d in ("PROP_temp64", "PFAT64", "FM64")
    }
    manifest = {
        "schema": "date2027-e1-ur-three-dut-v1",
        "created_utc": datetime.now(timezone.utc).isoformat(),
        "commit": commit,
        "dirty": dirty,
        "injection_model": "v3_exp_header_asap_body",
        "seed": 202701,
        "loads": list(LOADS),
        "rows": len(all_rows),
        "pfat_fill_gls": PFAT_FILL_GLS,
        "pfat_hist_gls": PFAT_HIST_GLS,
        "pfat_netlist_new": PFAT_NETLIST_NEW,
        "pfat_netlist_hist_lowloads": PFAT_NETLIST_HIST,
        "prop_fm_source": str(PROP_FM_CSV.relative_to(REPO)).replace("\\", "/"),
        "prop_netlist": FROZEN_PROP_TEMP64,
        "fm_netlist": FROZEN_FM64,
        "near_lossless_counts": nl_counts,
        "figure_dir": str(fig_dir.relative_to(REPO)).replace("\\", "/"),
        "figures": figs,
        "all_pfat_30_pass": True,
        "all_prop_fm_60_pass": True,
    }
    (raw_root / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (fig_dir / "plot_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# E1 three-DUT UR ASAP results",
        "",
        f"Archive: `{raw_root.relative_to(REPO).as_posix()}`",
        f"Figures: `{fig_dir.relative_to(REPO).as_posix()}`",
        "",
        "Injection: `v3_exp_header_asap_body`, seed 202701, 30 load points.",
        "Evidence: post-synthesis MAXIMUM-SDF GLS estimates.",
        "",
        "PFAT64: 12 historical low-load points + 18 fill points (M220–M800) all TB PASS 55000/55000.",
        "PROP_temp64 / FlatMesh64: reused local 30-point aggregated metrics.",
        "",
        "Latency panel includes only near-lossless points (backlog<=5; PFAT uses measurement backlog).",
        "",
        "## Saturation summary",
        "",
        "| Design | Peak delivered | Highest near-lossless |",
        "|---|---:|---:|",
    ]
    for row in sat:
        lines.append(
            f"| {row['design']} | {row['peak_delivered_mflit_per_port_s']} | "
            f"M{row['near_lossless_load_setpoint']} ({row['near_lossless_delivered_mflit_per_port_s']}) |"
        )
    lines += [
        "",
        f"Near-lossless point counts: {nl_counts}",
        "",
        f"Commit `{commit}` dirty={dirty}.",
        "",
    ]
    (raw_root / "RESULTS.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    (fig_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("E1_THREE_DUT_ARCHIVE_PASS", raw_root, flush=True)
    print("E1_THREE_DUT_FIGURES", fig_dir, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
