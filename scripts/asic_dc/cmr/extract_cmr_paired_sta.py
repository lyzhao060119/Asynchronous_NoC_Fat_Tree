#!/usr/bin/env python3
"""Build the step-C paired STA table from DC CSV / log output.

Does not recommend production SDC numbers.  RTM is the conservative static
pair Tctrl_min - Tdata_max, rise and fall kept separate.  no_path is a
fail for that ID, not a skip.  CSV shortfall is the 0% (Tctrl >= Tdata)
value; pass a --rtm-target to also score the outer-loop margin.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
import shutil
from collections import defaultdict
from pathlib import Path


CATALOG_STATUS = {
    "CMR-AR-01": "not_measured_this_run",
    "CMR-RCU-01": "measured",
    "CMR-OPM-01": "measured",
    "CMR-OPM-01-CE": "measured_segment",
    "CMR-TP-01": "not_measured_this_run",
    "CMR-LANE-01": "n_a_thin",
    "CMR-HS-01": "not_measured_this_run",
    "CMR-HS-02": "not_measured_this_run",
    "CMR-WP-01": "not_measured_this_run",
    "CMR-XOR-01": "corollary_of_wp01",
    "CMR-RP-01": "not_measured_this_run",
    "CMR-MTX-01": "not_delay_rtm",
    "CMR-FIFO-01": "n_a_circular_fifo",
    "TCF-HS-02": "not_measured_this_run",
    "TCF-RD-01": "not_measured_this_run",
    "CMR-LINK-FWD-01": "not_measured_this_run",
    "CMR-LINK-ENQ-01": "not_measured_this_run",
    "CMR-LINK-ACK-01": "not_measured_this_run",
    "CMR-LINK-IO-01": "not_measured_this_run",
}


def rtm_required_and_shortfall(
    tdata: float | None, tctrl: float | None, rtm: float
) -> tuple[float | None, float | None]:
    if tdata is None or tctrl is None:
        return None, None
    required = tdata * (1.0 + rtm)
    return required, max(0.0, required - tctrl)


def _float(value: str) -> float | None:
    if value in ("", "NA", "NO_PATH", "inf"):
        return None
    try:
        return float(value)
    except ValueError:
        return None


def _load_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file():
        return []
    with path.open(encoding="utf-8", errors="replace", newline="") as handle:
        return list(csv.DictReader(handle))


def _summarize(rows: list[dict[str, str]]) -> dict:
    by_id: dict[str, list[dict]] = defaultdict(list)
    for row in rows:
        by_id[row["id"]].append(row)

    ids = {}
    for rtc_id, group in sorted(by_id.items()):
        parsed = []
        no_path = 0
        for row in group:
            tdata = _float(row.get("tdata_max_ns", ""))
            tctrl = _float(row.get("tctrl_min_ns", ""))
            rtm = _float(row.get("rtm_pct", ""))
            shortfall = _float(row.get("shortfall_ns", ""))
            is_no_path = row.get("no_path", "0") == "1" or tdata is None or tctrl is None
            if is_no_path:
                no_path += 1
            parsed.append({
                "instance": row.get("instance", ""),
                "site": row.get("site", ""),
                "edge": row.get("edge", ""),
                "tdata_max_ns": tdata,
                "tctrl_min_ns": tctrl,
                "rtm_pct": rtm,
                "shortfall_ns": shortfall,
                "no_path": is_no_path,
                "loop_cut": row.get("loop_cut", ""),
            })
        comparable = [item for item in parsed if not item["no_path"]]
        worst = None
        if comparable:
            worst = min(comparable, key=lambda item: item["rtm_pct"] if item["rtm_pct"] is not None else math.inf)
        tdata_max = max((item["tdata_max_ns"] for item in comparable), default=None)
        tctrl_min = min((item["tctrl_min_ns"] for item in comparable), default=None)
        if rtc_id == "CMR-OPM-01-CE":
            status = "segment_pin_miss" if no_path else "measured_segment"
        elif no_path:
            status = "NO_PATH_FAIL"
        else:
            status = "measured"
        ids[rtc_id] = {
            "rows": len(group),
            "instances": len({item["instance"] for item in parsed}),
            "no_path_count": no_path,
            "status": status,
            "tdata_max_ns": tdata_max,
            "tctrl_min_ns": tctrl_min,
            "worst_rtm_pct": None if worst is None else worst["rtm_pct"],
            "worst_shortfall_ns": None if worst is None else worst["shortfall_ns"],
            "worst": worst,
            "loop_cut": parsed[0]["loop_cut"] if parsed else "",
        }
    return ids


def _md_table(catalog: dict, measured: dict) -> str:
    lines = [
        "| ID | Status | Sites | Tdata_max (ns) | Tctrl_min (ns) | Worst RTM % | Shortfall (ns) | no-path | Loop cut |",
        "|---|---|---:|---:|---:|---:|---:|---:|---|",
    ]
    for rtc_id, default_status in CATALOG_STATUS.items():
        info = measured.get(rtc_id)
        if info is None:
            lines.append(
                f"| {rtc_id} | {default_status} | - | - | - | - | - | - | - |"
            )
            continue
        tdata = "-" if info["tdata_max_ns"] is None else f"{info['tdata_max_ns']:.4f}"
        tctrl = "-" if info["tctrl_min_ns"] is None else f"{info['tctrl_min_ns']:.4f}"
        if (
            info["tdata_max_ns"] is not None
            and info["tdata_max_ns"] == 0.0
            and info["worst_rtm_pct"] is not None
            and info["worst_rtm_pct"] > 1.0e6
        ):
            rtm = "n/a (Tdata=0)"
        else:
            rtm = "-" if info["worst_rtm_pct"] is None else f"{info['worst_rtm_pct']:.3f}"
        sf = "-" if info["worst_shortfall_ns"] is None else f"{info['worst_shortfall_ns']:.4f}"
        status = info["status"]
        loop = info["loop_cut"].replace("|", "/")
        lines.append(
            f"| {rtc_id} | {status} | {info['rows']} | {tdata} | {tctrl} | {rtm} | {sf} | {info['no_path_count']} | {loop} |"
        )
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report_dir", type=Path)
    parser.add_argument("--log", type=Path)
    parser.add_argument(
        "--baseline", default="20260828_cmr_cfifo_tp_nogrant_p50"
    )
    parser.add_argument("--run-id")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--archive-csv", type=Path)
    parser.add_argument(
        "--rtm-target",
        type=float,
        default=0.0,
        help="Score shortfall at this RTM (0.0 = Tctrl>=Tdata; 0.05 = 5%% outer).",
    )
    args = parser.parse_args()

    csv_path = args.report_dir / "paired_catalog.csv"
    rows = _load_csv(csv_path)
    measured = _summarize(rows)
    for info in measured.values():
        required, shortfall = rtm_required_and_shortfall(
            info.get("tdata_max_ns"),
            info.get("tctrl_min_ns"),
            args.rtm_target,
        )
        info["required_tctrl_ns"] = required
        info["shortfall_at_rtm_ns"] = shortfall
    log_text = ""
    if args.log and args.log.is_file():
        log_text = args.log.read_text(encoding="utf-8", errors="replace")
    result = {
        "baseline": args.baseline,
        "run_id": args.run_id or args.report_dir.name,
        "report_dir": str(args.report_dir),
        "csv": str(csv_path) if csv_path.is_file() else None,
        "production_sdc": False,
        "delay_cells_changed": False,
        "rtm_target": args.rtm_target,
        "row_count": len(rows),
        "ids": measured,
        "catalog_coverage": CATALOG_STATUS,
        "done_marker": "CMR_PAIRED_STA_DONE" in log_text,
        "markdown_table": _md_table(CATALOG_STATUS, measured),
    }
    rendered = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    if args.archive_csv and csv_path.is_file():
        args.archive_csv.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(csv_path, args.archive_csv)
    print(rendered, end="")
    print(result["markdown_table"], end="")


if __name__ == "__main__":
    main()
