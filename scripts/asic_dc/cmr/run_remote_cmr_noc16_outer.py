#!/usr/bin/env python3
"""Step F continuation: control shrink then OPM Ackin DEL resize.

Default campaign is ackin_resize from 20260827_cmr_cfifo_outer_rtm5_opm_x20:
keep the 25 OPM AckinDelay instances and size_cell the leaf from DEL250
down (150, 100, 75, 50).  GLS fail keeps the last passing unit (x20 if
the first knife fails).  Splice-delete (ackin_then_e) stalled SDF GLS.
--shrink auto still loops RCU DEL / BUFFD0 / XOR squeeze from a supplied
seed.  Rollback B remains 20260827_cmr_cfifo_noc16_rd01_eco16_p50_01.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

from create_cmr_del_overdesign import build_verdict
from create_cmr_inner_targets import OUTER_CLASS


REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
BASELINES = REPO / "docs" / "timing_baselines"
ROLLBACK = "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
RCU3_RUN = "20260827_cmr_cfifo_outer_rtm5_rcu3"
RCU3_SHA = "050675a382ef0528b9c28a51fda6eb00667f4be87f8b21e458e0822a67274e4e"
OPM_X20_RUN = "20260827_cmr_cfifo_outer_rtm5_opm_x20"
OPM_X20_SHA = "24448454e6684b00839165ad1723abe2155d2bb0826b8d7519aecd88da66ed56"
STA_IDS = ("CMR-OPM-01", "CMR-RCU-01", "CMR-OPM-01-CE")
ACKIN_RTL = (
    "src/main/scala/Router_Architecture/CMR/OPM.scala",
    "src/main/scala/Router_Architecture/CMR/CMRTypes.scala",
)
ACKIN_UNITS = (50,)


def _run_inner(
    run_id: str,
    rtm: float,
    sta_summary: Path,
    extra_slack: float,
    extra: dict[str, str] | None = None,
) -> None:
    env = os.environ.copy()
    if extra:
        env.update(extra)
    cmd = [
        sys.executable,
        str(CMR / "run_remote_cmr_noc16_inner.py"),
        "--class",
        OUTER_CLASS,
        "--rtm",
        str(rtm),
        "--run-id",
        run_id,
        "--sta-summary",
        str(sta_summary),
        "--extra-slack",
        str(extra_slack),
    ]
    subprocess.run(cmd, cwd=REPO, env=env, check=True)


def _is_gls_fail(run_id: str) -> bool:
    gls = _gls_status(run_id)
    cases = gls.get("cases", {})
    if not cases:
        return False
    return any(
        isinstance(info, dict)
        and (
            not info.get("tb_pass", True)
            or info.get("stall_failure")
            or info.get("hard_timeout")
            or info.get("unexpected_failure")
        )
        for info in cases.values()
    )


def _is_dc_fail(run_id: str) -> bool:
    dc_log = CMR / "results" / run_id / "dc.log"
    if not dc_log.is_file():
        return False
    return any(
        line.startswith("CMR_NOC16_DC_FAIL")
        for line in dc_log.read_text(encoding="utf-8", errors="replace").splitlines()
    )


def _run_inner_retry(
    run_id: str,
    rtm: float,
    sta_summary: Path,
    extra_slack: float,
    extra: dict[str, str] | None = None,
) -> None:
    last: Exception | None = None
    for attempt in range(2):
        try:
            _run_inner(run_id, rtm, sta_summary, extra_slack, extra)
            return
        except Exception as exc:
            last = exc
            if _is_gls_fail(run_id) or _is_dc_fail(run_id):
                raise
            print("CMR_OUTER_RETRY", run_id, "attempt", attempt + 2, exc, flush=True)
            time.sleep(10 * (attempt + 1))
    if last is not None:
        raise last


def _read_hashes(run_id: str) -> dict[str, str]:
    path = CMR / "results" / run_id / "reports_dc" / "post_hashes.sha256"
    hashes: dict[str, str] = {}
    if not path.is_file():
        return hashes
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        parts = line.split()
        if len(parts) >= 2:
            hashes[Path(parts[1]).name] = parts[0]
    return hashes


def _read_structure(run_id: str) -> dict[str, str]:
    path = CMR / "results" / run_id / "reports_dc" / "cmr_noc16_structure.rpt"
    out: dict[str, str] = {}
    if not path.is_file():
        return out
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            out[key.strip()] = value.strip()
    return out


def _gls_status(run_id: str) -> dict:
    path = CMR / "results" / run_id / "summary.json"
    if path.is_file():
        return json.loads(path.read_text(encoding="utf-8"))
    return {}


def _sta_blob(summary: dict) -> dict:
    return {
        rtc: {
            "tdata_max_ns": info.get("tdata_max_ns"),
            "tctrl_min_ns": info.get("tctrl_min_ns"),
            "worst_rtm_pct": info.get("worst_rtm_pct"),
            "shortfall_at_rtm_ns": info.get("shortfall_at_rtm_ns"),
            "no_path": info.get("no_path_count"),
        }
        for rtc, info in summary.get("ids", {}).items()
        if rtc in STA_IDS
    }


def _archive(run_id: str, freeze: dict, sta_src: Path | None) -> None:
    BASELINES.mkdir(parents=True, exist_ok=True)
    freeze_path = BASELINES / (run_id + "_outer_freeze.json")
    freeze_path.write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")
    if sta_src and sta_src.is_file():
        shutil.copyfile(sta_src, BASELINES / (run_id + "_paired_sta_summary.json"))
    csv_src = CMR / "results" / run_id / "paired_catalog.csv"
    if csv_src.is_file():
        shutil.copyfile(csv_src, BASELINES / (run_id + "_paired_sta.csv"))
    print("CMR_OUTER_ARCHIVED", freeze_path, flush=True)


def _windows_from_targets(run_id: str) -> dict:
    path = CMR / (run_id + "_targets.tcl.json")
    if not path.is_file():
        return {}
    data = json.loads(path.read_text(encoding="utf-8"))
    out = {}
    for rtc, info in data.get("windows", {}).items():
        if rtc in ("CMR-OPM-01", "CMR-RCU-01"):
            out[rtc] = {
                "min": info.get("required_min_ns"),
                "max": info.get("required_max_ns"),
                "from": info.get("from"),
                "to": info.get("to"),
            }
    return out


def _revert_ackin_rtl() -> None:
    subprocess.run(
        ["git", "checkout", "--", *ACKIN_RTL],
        cwd=REPO,
        check=True,
    )
    print("CMR_OUTER_REVERT_ACKIN_RTL", flush=True)


def _opm_tctrl(summary: dict) -> float | None:
    info = summary.get("ids", {}).get("CMR-OPM-01", {})
    value = info.get("tctrl_min_ns")
    if value is None:
        return None
    return float(value)


def _opm_shortfall(summary: dict) -> float | None:
    info = summary.get("ids", {}).get("CMR-OPM-01", {})
    value = info.get("shortfall_at_rtm_ns")
    if value is None:
        return None
    return float(value)


def _write_freeze(
    run_id: str,
    role: str,
    rtm: float,
    seed_run: str,
    seed_sha: str,
    rcu_steps: int,
    buf_stages: int,
    extra_after: float,
    ackin_steps: int,
    e_max: float | None,
    sta_src: Path | None,
    ackin_unit: int = 250,
) -> dict:
    shrink_sta = CMR / "results" / run_id / "paired_sta_summary.json"
    shrink_summary = (
        json.loads(shrink_sta.read_text(encoding="utf-8"))
        if shrink_sta.is_file()
        else {}
    )
    gls = _gls_status(run_id)
    cases = gls.get("cases", {})
    freeze = {
        "role": "step_F_outer_rtm5_shrink",
        "run_id": run_id,
        "rtc_class": OUTER_CLASS,
        "rtm_target": rtm,
        "seed_run": seed_run,
        "seed_ddc_sha256": seed_sha,
        "rollback_remains": ROLLBACK,
        "del_resized": role in ("OPM_ACKIN", "OPM_ACKIN_RESIZE", "RCU_DEL150", "RCU_DEL150_TO_BUF"),
        "del_shrink_role": role,
        "rcu_del150_expected": 25 * rcu_steps,
        "rcu_matched_buf_expected": 25 * buf_stages,
        "opm_ackin_del250_expected": 25 * ackin_steps if ackin_unit == 250 else 0,
        "opm_ackin_unit_ps": ackin_unit,
        "opm_ackin_leaf_expected": 25 * ackin_steps,
        "extra_slack_ns": extra_after,
        "opm_e_max_ns": e_max,
        "hashes": _read_hashes(run_id),
        "structure": _read_structure(run_id),
        "windows_ns": _windows_from_targets(run_id),
        "paired_sta": _sta_blob(shrink_summary),
        "gls_jobs": {
            name: info.get("job_id")
            for name, info in cases.items()
            if isinstance(info, dict)
        },
    }
    _archive(run_id, freeze, sta_src if sta_src and sta_src.is_file() else None)
    return freeze


def _set_ackin_unit_rtl(unit: int) -> None:
    path = REPO / "src/main/scala/Router_Architecture/CMR/CMRTypes.scala"
    text = path.read_text(encoding="utf-8")
    new = re.sub(
        r'sys\.env\.get\("CMR_OPM_ACKIN_DELAY_UNIT_PS"\)\.map\(_\.toInt\)\.getOrElse\(\d+\)',
        'sys.env.get("CMR_OPM_ACKIN_DELAY_UNIT_PS").map(_.toInt).getOrElse(%d)'
        % unit,
        text,
        count=1,
    )
    if new == text:
        print("CMR_OUTER_ACKIN_UNIT_RTL_UNCHANGED", unit, flush=True)
        return
    path.write_text(new, encoding="utf-8")
    print("CMR_OUTER_ACKIN_UNIT_RTL", unit, flush=True)


def _window_sta_path() -> Path:
    window_sta = BASELINES / (OPM_X20_RUN + "_paired_sta_summary.json")
    if not window_sta.is_file():
        window_sta = CMR / "results" / OPM_X20_RUN / "paired_sta_summary.json"
    if not window_sta.is_file():
        raise SystemExit("missing x20 STA summary for frozen XOR/RCU windows")
    return window_sta


def _campaign_ackin_resize(args: argparse.Namespace) -> None:
    rtm = args.rtm
    seed_run = args.seed_run
    seed_sha = args.seed_sha256
    rcu_steps = args.rcu_steps
    buf_stages = args.buf_stages
    extra_slack = args.extra_slack
    window_sta = _window_sta_path()
    last_unit = 250
    units = tuple(int(x) for x in args.ackin_units.split(",") if x.strip())
    if not units:
        raise SystemExit("empty --ackin-units")
    for unit in units:
        if unit not in (50, 75, 100, 150, 250):
            raise SystemExit("illegal Ackin DelayUnitPs %s" % unit)
    print(
        "CMR_OUTER_CONTINUE campaign ackin_resize seed",
        seed_run,
        "rtm",
        rtm,
        "rcu_steps",
        rcu_steps,
        "buf_stages",
        buf_stages,
        "extra_slack",
        extra_slack,
        "units",
        ",".join(str(u) for u in units),
        flush=True,
    )
    for unit in units:
        run_id = "20260827_cmr_cfifo_outer_rtm5_ackin_u%d" % unit
        env = {
            "CMR_INNER_SEED_RUN": seed_run,
            "CMR_INNER_SEED_SHA256": seed_sha,
            "CMR_RCU_MATCHED_DELAY_STEPS": str(rcu_steps),
            "CMR_RCU_MATCHED_BUF_STAGES": str(buf_stages),
            "CMR_OPM_ACKIN_DELAY_STEPS": "1",
            "CMR_OPM_ACKIN_DELAY_UNIT_PS": str(unit),
            "CMR_DEL_SHRINK_ROLE": "OPM_ACKIN_RESIZE",
            "CMR_OPM_E_MAX_NS": "",
            "CMR_NOC16_RUN_ID": run_id,
        }
        os.environ.pop("CMR_DEL_SHRINK_ROLE", None)
        os.environ.pop("CMR_OPM_E_MAX_NS", None)
        print(
            "CMR_OUTER_SHRINK_START",
            run_id,
            "role OPM_ACKIN_RESIZE unit",
            unit,
            "from",
            seed_run,
            flush=True,
        )
        try:
            _run_inner_retry(run_id, rtm, window_sta, extra_slack, env)
        except Exception as exc:
            print(
                "CMR_OUTER_SHRINK_FAIL keep last pass",
                seed_run,
                "ackin_unit",
                last_unit,
                "skip",
                unit,
                exc,
                flush=True,
            )
            break
        freeze = _write_freeze(
            run_id,
            "OPM_ACKIN_RESIZE",
            rtm,
            seed_run,
            seed_sha,
            rcu_steps,
            buf_stages,
            extra_slack,
            1,
            None,
            CMR / "results" / run_id / "paired_sta_summary.json",
            ackin_unit=unit,
        )
        print("CMR_OUTER_SHRINK_PASS", run_id, "unit", unit, flush=True)
        hashes = freeze["hashes"]
        next_sha = hashes.get("NoC_16nodes.ddc", "")
        if not next_sha:
            raise SystemExit("missing DDC hash after %s" % run_id)
        seed_run = run_id
        seed_sha = next_sha
        last_unit = unit
    if last_unit != 250:
        _set_ackin_unit_rtl(last_unit)
    print(
        "CMR_OUTER_ACKIN_RESIZE_DONE last_unit",
        last_unit,
        "run",
        seed_run,
        flush=True,
    )


def _campaign_ackin_then_e(args: argparse.Namespace) -> None:
    rtm = args.rtm
    seed_run = args.seed_run
    seed_sha = args.seed_sha256
    rcu_steps = args.rcu_steps
    buf_stages = args.buf_stages
    extra_slack = args.extra_slack
    window_sta = BASELINES / (OPM_X20_RUN + "_paired_sta_summary.json")
    if not window_sta.is_file():
        window_sta = CMR / "results" / OPM_X20_RUN / "paired_sta_summary.json"
    if not window_sta.is_file():
        raise SystemExit("missing x20 STA summary for frozen XOR/RCU windows")

    seed_sta = CMR / "results" / seed_run / "paired_sta_summary.json"
    if not seed_sta.is_file():
        seed_sta = BASELINES / (seed_run + "_paired_sta_summary.json")
    tctrl_seed = None
    if seed_sta.is_file():
        tctrl_seed = _opm_tctrl(json.loads(seed_sta.read_text(encoding="utf-8")))

    print(
        "CMR_OUTER_CONTINUE campaign ackin_then_e seed",
        seed_run,
        "rtm",
        rtm,
        "rcu_steps",
        rcu_steps,
        "buf_stages",
        buf_stages,
        "extra_slack",
        extra_slack,
        flush=True,
    )

    ackin_steps = 1
    ackin_run = "20260827_cmr_cfifo_outer_rtm5_ackin0"
    env = {
        "CMR_INNER_SEED_RUN": seed_run,
        "CMR_INNER_SEED_SHA256": seed_sha,
        "CMR_RCU_MATCHED_DELAY_STEPS": str(rcu_steps),
        "CMR_RCU_MATCHED_BUF_STAGES": str(buf_stages),
        "CMR_OPM_ACKIN_DELAY_STEPS": "0",
        "CMR_DEL_SHRINK_ROLE": "OPM_ACKIN",
        "CMR_OPM_E_MAX_NS": "",
        "CMR_NOC16_RUN_ID": ackin_run,
    }
    os.environ.pop("CMR_DEL_SHRINK_ROLE", None)
    os.environ.pop("CMR_OPM_E_MAX_NS", None)
    print("CMR_OUTER_SHRINK_START", ackin_run, "role OPM_ACKIN from", seed_run, flush=True)
    ackin_ok = False
    try:
        _run_inner_retry(ackin_run, rtm, window_sta, extra_slack, env)
        ackin_ok = True
    except Exception as exc:
        dc_log = CMR / "results" / ackin_run / "dc.log"
        dc_failed = False
        if dc_log.is_file():
            dc_failed = any(
                line.startswith("CMR_NOC16_DC_FAIL")
                for line in dc_log.read_text(encoding="utf-8", errors="replace").splitlines()
            )
        if not dc_failed:
            raise
        print(
            "CMR_OUTER_SHRINK_FAIL keep last pass",
            seed_run,
            "skip OPM_ACKIN",
            flush=True,
        )
        ddc = CMR / "results" / ackin_run / "outputs" / "NoC_16nodes.ddc"
        if ddc.is_file():
            _revert_ackin_rtl()
        else:
            print("CMR_OUTER_KEEP_ACKIN_RTL dc_failed %s" % exc, flush=True)

    if ackin_ok:
        freeze = _write_freeze(
            ackin_run,
            "OPM_ACKIN",
            rtm,
            seed_run,
            seed_sha,
            rcu_steps,
            buf_stages,
            extra_slack,
            0,
            None,
            CMR / "results" / ackin_run / "paired_sta_summary.json",
        )
        print("CMR_OUTER_SHRINK_PASS", ackin_run, flush=True)
        hashes = freeze["hashes"]
        seed_run = ackin_run
        seed_sha = hashes.get("NoC_16nodes.ddc", "")
        if not seed_sha:
            raise SystemExit("missing DDC hash after %s" % ackin_run)
        ackin_steps = 0
        seed_sta = CMR / "results" / ackin_run / "paired_sta_summary.json"
        if seed_sta.is_file():
            tctrl_seed = _opm_tctrl(json.loads(seed_sta.read_text(encoding="utf-8")))

    e_values = [0.100]
    e_seed_run = seed_run
    e_seed_sha = seed_sha
    e_tctrl_before = tctrl_seed
    for e_max in e_values:
        tag = int(round(e_max * 1000.0))
        e_run = "20260827_cmr_cfifo_outer_rtm5_opm_e%d" % tag
        env = {
            "CMR_INNER_SEED_RUN": e_seed_run,
            "CMR_INNER_SEED_SHA256": e_seed_sha,
            "CMR_RCU_MATCHED_DELAY_STEPS": str(rcu_steps),
            "CMR_RCU_MATCHED_BUF_STAGES": str(buf_stages),
            "CMR_OPM_ACKIN_DELAY_STEPS": str(ackin_steps),
            "CMR_DEL_SHRINK_ROLE": "",
            "CMR_OPM_E_MAX_NS": "%.3f" % e_max,
            "CMR_NOC16_RUN_ID": e_run,
        }
        os.environ.pop("CMR_DEL_SHRINK_ROLE", None)
        print(
            "CMR_OUTER_SHRINK_START",
            e_run,
            "role OPM_E_MAX",
            e_max,
            "from",
            e_seed_run,
            flush=True,
        )
        try:
            _run_inner_retry(e_run, rtm, window_sta, extra_slack, env)
        except Exception:
            print(
                "CMR_OUTER_SHRINK_FAIL keep last pass",
                e_seed_run,
                "skip OPM_E_MAX",
                e_max,
                flush=True,
            )
            return
        freeze = _write_freeze(
            e_run,
            "OPM_E_MAX",
            rtm,
            e_seed_run,
            e_seed_sha,
            rcu_steps,
            buf_stages,
            extra_slack,
            ackin_steps,
            e_max,
            CMR / "results" / e_run / "paired_sta_summary.json",
        )
        print("CMR_OUTER_SHRINK_PASS", e_run, flush=True)
        hashes = freeze["hashes"]
        next_sha = hashes.get("NoC_16nodes.ddc", "")
        if not next_sha:
            raise SystemExit("missing DDC hash after %s" % e_run)
        e_sta = CMR / "results" / e_run / "paired_sta_summary.json"
        e_summary = json.loads(e_sta.read_text(encoding="utf-8")) if e_sta.is_file() else {}
        sf = _opm_shortfall(e_summary)
        tctrl_after = _opm_tctrl(e_summary)
        if sf is not None and sf > 1.0e-9:
            print("CMR_OUTER_E_STOP shortfall", sf, flush=True)
            return
        dropped = (
            e_tctrl_before is not None
            and tctrl_after is not None
            and tctrl_after < e_tctrl_before - 0.001
        )
        if e_max == 0.100 and dropped:
            e_values.append(0.060)
            e_seed_run = e_run
            e_seed_sha = next_sha
            e_tctrl_before = tctrl_after
        elif e_max == 0.100 and not dropped:
            print(
                "CMR_OUTER_E_STOP tctrl_unchanged",
                tctrl_after,
                "before",
                e_tctrl_before,
                flush=True,
            )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rtm", type=float, default=0.05)
    parser.add_argument("--seed-run", default=os.environ.get("CMR_INNER_SEED_RUN", OPM_X20_RUN))
    parser.add_argument(
        "--seed-sha256",
        default=os.environ.get("CMR_INNER_SEED_SHA256", OPM_X20_SHA),
    )
    parser.add_argument("--rcu-steps", type=int, default=1)
    parser.add_argument("--buf-stages", type=int, default=8)
    parser.add_argument("--extra-slack", type=float, default=0.020)
    parser.add_argument("--buf-n", type=int, default=8)
    parser.add_argument(
        "--shrink",
        choices=(
            "auto",
            "none",
            "RCU_DEL150",
            "RCU_DEL150_TO_BUF",
            "OPM_XOR_SQUEEZE",
            "OPM_ACKIN",
            "OPM_ACKIN_RESIZE",
            "OPM_E_MAX",
            "ackin_then_e",
            "ackin_resize",
        ),
        default=os.environ.get("CMR_OUTER_SHRINK", "ackin_resize"),
    )
    parser.add_argument("--max-knives", type=int, default=6)
    parser.add_argument(
        "--ackin-units",
        default=os.environ.get("CMR_ACKIN_UNITS", "50"),
        help="comma-separated Ackin DelayUnitPs to size_cell",
    )
    return parser.parse_args()


def _knife_run_id(role: str, steps_after: int, buf_n: int, extra: float) -> str:
    if role == "RCU_DEL150":
        return "20260827_cmr_cfifo_outer_rtm5_rcu%d" % steps_after
    if role == "RCU_DEL150_TO_BUF":
        return "20260827_cmr_cfifo_outer_rtm5_rcu%d_buf%d" % (steps_after, buf_n)
    return "20260827_cmr_cfifo_outer_rtm5_opm_x%d" % int(round(extra * 1000.0))


def main() -> None:
    args = _parse_args()
    if args.shrink == "ackin_resize":
        _campaign_ackin_resize(args)
        return
    if args.shrink == "ackin_then_e":
        _campaign_ackin_then_e(args)
        return
    rtm = args.rtm
    seed_run = args.seed_run
    seed_sha = args.seed_sha256
    rcu_steps = args.rcu_steps
    buf_stages = args.buf_stages
    extra_slack = args.extra_slack
    buf_n = args.buf_n
    skipped: set[str] = set()
    first_from_rcu3 = seed_run == RCU3_RUN

    sta_path = CMR / "results" / seed_run / "paired_sta_summary.json"
    if not sta_path.is_file():
        sta_path = BASELINES / (seed_run + "_paired_sta_summary.json")
    if not sta_path.is_file():
        raise SystemExit("missing seed STA summary for %s" % seed_run)

    print(
        "CMR_OUTER_CONTINUE",
        "seed",
        seed_run,
        "rtm",
        rtm,
        "rcu_steps",
        rcu_steps,
        "buf_stages",
        buf_stages,
        "extra_slack",
        extra_slack,
        flush=True,
    )

    if args.shrink == "none":
        print("CMR_OUTER_SKIP_SHRINK", flush=True)
        return

    knives = 0
    while knives < args.max_knives:
        summary = json.loads(sta_path.read_text(encoding="utf-8"))
        verdict = build_verdict(
            summary,
            rtm,
            rcu_steps=rcu_steps,
            extra_slack_ns=extra_slack,
            buf_stages=buf_stages,
            buf_n=buf_n,
        )
        verdict_dir = CMR / "results" / seed_run
        verdict_dir.mkdir(parents=True, exist_ok=True)
        (verdict_dir / "del_overdesign.json").write_text(
            json.dumps(verdict, indent=2) + "\n", encoding="utf-8"
        )
        shutil.copyfile(
            verdict_dir / "del_overdesign.json",
            BASELINES / (seed_run + "_del_overdesign.json"),
        )
        print("CMR_OUTER_DEL_VERDICT", json.dumps(verdict["action"]), flush=True)

        role = verdict.get("first_shrink_role")
        if args.shrink != "auto":
            role = args.shrink
            if role in skipped or not verdict["roles"].get(role, {}).get("eligible"):
                print("CMR_OUTER_NO_ELIGIBLE_DEL forced=%s" % args.shrink, flush=True)
                return
        if not role or role in skipped:
            print("CMR_OUTER_NO_ELIGIBLE_DEL", flush=True)
            return

        steps_after = rcu_steps
        buf_after = buf_stages
        extra_after = extra_slack
        env_extra = {
            "CMR_INNER_SEED_RUN": seed_run,
            "CMR_INNER_SEED_SHA256": seed_sha,
            "CMR_RCU_MATCHED_DELAY_STEPS": str(rcu_steps),
            "CMR_RCU_MATCHED_BUF_STAGES": str(buf_stages),
        }
        env_extra.pop("CMR_DEL_SHRINK_ROLE", None)
        os.environ.pop("CMR_DEL_SHRINK_ROLE", None)

        if role == "RCU_DEL150":
            steps_after = rcu_steps - 1
            env_extra["CMR_DEL_SHRINK_ROLE"] = "RCU_DEL150"
            env_extra["CMR_RCU_MATCHED_DELAY_STEPS"] = str(steps_after)
        elif role == "RCU_DEL150_TO_BUF":
            steps_after = rcu_steps - 1
            buf_after = buf_n
            env_extra["CMR_DEL_SHRINK_ROLE"] = "RCU_DEL150_TO_BUF"
            env_extra["CMR_RCU_MATCHED_DELAY_STEPS"] = str(steps_after)
            env_extra["CMR_RCU_MATCHED_BUF_STAGES"] = str(buf_after)
        elif role == "OPM_XOR_SQUEEZE":
            nxt = verdict["roles"]["OPM_XOR_SQUEEZE"].get("next_extra_slack_ns")
            if nxt is None:
                print("CMR_OUTER_NO_ELIGIBLE_DEL opm_xor", flush=True)
                return
            extra_after = float(nxt)
        else:
            raise SystemExit("CMR_OUTER_REFUSE shrink role=%s" % role)

        run_id = _knife_run_id(role, steps_after, buf_after, extra_after)
        env_extra["CMR_NOC16_RUN_ID"] = run_id
        print("CMR_OUTER_SHRINK_START", run_id, "role", role, "from", seed_run, flush=True)
        try:
            _run_inner(run_id, rtm, sta_path, extra_after, env_extra)
        except Exception:
            if first_from_rcu3 and role == "RCU_DEL150":
                print("CMR_OUTER_SHRINK_FAIL rollback remains", ROLLBACK, flush=True)
                raise
            print(
                "CMR_OUTER_SHRINK_FAIL keep last pass",
                seed_run,
                "skip",
                role,
                flush=True,
            )
            skipped.add(role)
            if args.shrink != "auto":
                raise
            knives += 1
            continue

        shrink_sta = CMR / "results" / run_id / "paired_sta_summary.json"
        shrink_summary = (
            json.loads(shrink_sta.read_text(encoding="utf-8"))
            if shrink_sta.is_file()
            else {}
        )
        gls = _gls_status(run_id)
        cases = gls.get("cases", {})
        freeze = {
            "role": "step_F_outer_rtm5_shrink",
            "run_id": run_id,
            "rtc_class": OUTER_CLASS,
            "rtm_target": rtm,
            "seed_run": seed_run,
            "seed_ddc_sha256": seed_sha,
            "rollback_remains": ROLLBACK,
            "del_resized": role != "OPM_XOR_SQUEEZE",
            "del_shrink_role": role,
            "rcu_del150_expected": 25 * steps_after,
            "rcu_matched_buf_expected": 25 * buf_after,
            "extra_slack_ns": extra_after,
            "hashes": _read_hashes(run_id),
            "structure": _read_structure(run_id),
            "windows_ns": _windows_from_targets(run_id),
            "paired_sta": _sta_blob(shrink_summary),
            "gls_jobs": {
                name: info.get("job_id")
                for name, info in cases.items()
                if isinstance(info, dict)
            },
        }
        _archive(run_id, freeze, shrink_sta if shrink_sta.is_file() else None)
        print("CMR_OUTER_SHRINK_PASS", run_id, flush=True)

        hashes = freeze["hashes"]
        seed_run = run_id
        seed_sha = hashes.get("NoC_16nodes.ddc", "")
        if not seed_sha:
            raise SystemExit("missing DDC hash after %s" % run_id)
        rcu_steps = steps_after
        buf_stages = buf_after
        extra_slack = extra_after
        sta_path = shrink_sta
        first_from_rcu3 = False
        knives += 1
        if args.shrink != "auto":
            return

    print("CMR_OUTER_MAX_KNIVES", args.max_knives, flush=True)


if __name__ == "__main__":
    main()
