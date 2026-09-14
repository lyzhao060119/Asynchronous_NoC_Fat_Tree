#!/usr/bin/env python3
"""Step G: inter-level FIFO and L1/L2 link RTCs after the F-closed DDC.

Seed is 20260827_cmr_cfifo_outer_rtm5_rcu_del050_buf16 (1xDEL050 +
16xBUFFD0, Ackin DEL050).  Router inner windows stay frozen
(datapath + CMR-OUTER-RTM5).  This launcher:

  1. paired STA on the seed (measure Tdata/Tctrl, no production SDC)
  2. incremental DC: max-delay on link data, then min-delay on exported Req,
     then Ack-return as a separate class
  3. paired STA + TAB/VCTM p50 strict SDF

Still SYNTH-CLOSED, not PHYS-CLOSED.  Rollback remains
20260827_cmr_cfifo_noc16_rd01_eco16_p50_01.
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
from pathlib import Path

from extract_cmr_paired_sta import rtm_required_and_shortfall
from run_remote_cmr_flow import atomic_put, atomic_put_bytes, remote_run
from run_remote_cmr_noc16_sdf import (
    ROOT,
    connect,
    fetch_tree,
    job_id,
    wait_job,
)


REPO = Path(__file__).resolve().parents[3]
CMR = REPO / "scripts" / "asic_dc" / "cmr"
BASELINES = REPO / "docs" / "timing_baselines"
SEED_RUN = "20260827_cmr_cfifo_outer_rtm5_rcu_del050_buf16"
SEED_SHA = "64eaa1c312394e482e9b367dd8116c74c1d60d8c52a1b55929ab1a15b3c96874"
ROLLBACK = "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
INNER_CLASS = "CMR-OUTER-RTM5"
DP_OVERLAY = CMR / "async_cmr_noc16_datapath.sdc"
INNER_OVERLAY = CMR / "async_cmr_noc16_inner.sdc"
LINK_OVERLAY = CMR / "async_cmr_noc16_link.sdc"
DP_TARGET = CMR / "20260827_cmr_cfifo_datapath_r1_targets.tcl"
INNER_TARGET = CMR / "20260827_cmr_cfifo_outer_rtm5_rcu_del050_buf16_targets.tcl"
LINK_IDS = (
    "CMR-LINK-FWD-01",
    "CMR-LINK-ENQ-01",
    "CMR-LINK-ACK-01",
    "CMR-LINK-IO-01",
    "TCF-RD-01",
    "TCF-HS-02",
)
ROUTER_IDS = ("CMR-OPM-01", "CMR-RCU-01")
NEAR_FLOOR = 0.020


def _generate_link_targets(sta_summary: Path, out: Path, rtm: float, extra: float, phase: str) -> None:
    cmd = [
        sys.executable,
        str(CMR / "create_cmr_link_targets.py"),
        "--sta-summary",
        str(sta_summary),
        "--out",
        str(out),
        "--rtm",
        str(rtm),
        "--extra-slack",
        str(extra),
        "--phase",
        phase,
    ]
    subprocess.run(cmd, cwd=REPO, check=True)


def _run_sta(baseline: str, sta_id: str) -> None:
    env = os.environ.copy()
    env["CMR_NOC16_BASELINE"] = baseline
    env["CMR_INNER_SEED_RUN"] = baseline
    env["CMR_PAIRED_STA_RUN_ID"] = sta_id
    env["CMR_STA_MEASURE_LINKS"] = "1"
    subprocess.run(
        [sys.executable, str(CMR / "run_remote_cmr_noc16_sta_paired.py")],
        cwd=CMR,
        env=env,
        check=True,
    )


def _extract_sta(sta_id: str, baseline: str, result: Path, rtm: float) -> dict:
    sta_dir = CMR / "results" / sta_id / "sta"
    if not sta_dir.is_dir():
        raise SystemExit("missing STA report dir %s" % sta_dir)
    subprocess.run(
        [
            sys.executable,
            str(CMR / "extract_cmr_paired_sta.py"),
            str(sta_dir),
            "--baseline",
            baseline,
            "--run-id",
            sta_id,
            "--output",
            str(result / "paired_sta_summary.json"),
            "--archive-csv",
            str(result / "paired_catalog.csv"),
            "--rtm-target",
            str(rtm),
        ],
        cwd=REPO,
        check=True,
    )
    return json.loads((result / "paired_sta_summary.json").read_text(encoding="utf-8"))


def _check_summary(
    summary: dict, rtm: float, require_links: bool, allow_link_shortfall: bool = False
) -> None:
    ids = summary.get("ids", {})
    for rtc_id in ROUTER_IDS:
        info = ids.get(rtc_id)
        if info is None:
            raise RuntimeError("paired STA missing %s" % rtc_id)
        if info.get("status") == "NO_PATH_FAIL":
            raise RuntimeError("paired STA no-path for %s" % rtc_id)
        _, sf = rtm_required_and_shortfall(
            info.get("tdata_max_ns"),
            info.get("tctrl_min_ns"),
            rtm,
        )
        if sf is not None and sf > 1.0e-9:
            raise RuntimeError(
                "paired STA RTM %.1f%% shortfall for %s: %s ns" % (rtm * 100.0, rtc_id, sf)
            )
    if not require_links:
        return
    for rtc_id in LINK_IDS:
        info = ids.get(rtc_id)
        if info is None:
            raise RuntimeError("link STA missing %s" % rtc_id)
        if info.get("status") == "NO_PATH_FAIL":
            raise RuntimeError("link STA no-path for %s" % rtc_id)
        tdata = info.get("tdata_max_ns")
        if tdata is None or tdata < NEAR_FLOOR:
            continue
        _, sf = rtm_required_and_shortfall(tdata, info.get("tctrl_min_ns"), rtm)
        if sf is not None and sf > 1.0e-9 and not allow_link_shortfall:
            raise RuntimeError(
                "link STA RTM %.1f%% shortfall for %s: %s ns" % (rtm * 100.0, rtc_id, sf)
            )


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


def _archive(run_id: str, freeze: dict, sta_src: Path | None) -> None:
    BASELINES.mkdir(parents=True, exist_ok=True)
    freeze_path = BASELINES / (run_id + "_link_freeze.json")
    freeze_path.write_text(json.dumps(freeze, indent=2) + "\n", encoding="utf-8")
    if sta_src and sta_src.is_file():
        shutil.copyfile(sta_src, BASELINES / (run_id + "_paired_sta_summary.json"))
    csv_src = CMR / "results" / run_id / "paired_catalog.csv"
    if csv_src.is_file():
        shutil.copyfile(csv_src, BASELINES / (run_id + "_paired_sta.csv"))
    print("CMR_LINK_ARCHIVED", freeze_path, flush=True)


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", default="all", choices=("measure", "datapath", "req", "ack", "all"))
    parser.add_argument("--rtm", type=float, default=0.05)
    parser.add_argument("--extra-slack", type=float, default=0.100)
    parser.add_argument("--run-id", default=os.environ.get("CMR_NOC16_RUN_ID", ""))
    parser.add_argument("--seed-run", default=SEED_RUN)
    parser.add_argument("--seed-sha256", default=SEED_SHA)
    return parser.parse_args()


def _run_dc(
    run_id: str,
    seed_run: str,
    seed_sha: str,
    phase: str,
    link_target: Path,
) -> str:
    client = connect()
    seed = "%s/outputs/%s/NoC_16nodes.ddc" % (ROOT, seed_run)
    probe = remote_run(
        client, "test -s %s && sha256sum %s" % (shlex.quote(seed), shlex.quote(seed))
    )
    if seed_sha not in probe:
        raise RuntimeError("link seed DDC hash mismatch: " + probe)

    remote_run(
        client,
        "mkdir -p %s/rtl %s/scripts/dc %s/reports/dc/%s %s/logs/dc %s/outputs/%s"
        % (ROOT, ROOT, ROOT, run_id, ROOT, ROOT, run_id),
    )
    files = {
        CMR / "run_dc_cmr_noc16.tcl": "scripts/dc/run_dc_cmr_noc16.tcl",
        REPO / "scripts/asic_dc/tech_t28ss.tcl": "rtl/tech_t28ss.tcl",
        REPO / "scripts/asic_dc/async_primitives.tcl": "rtl/async_primitives.tcl",
        REPO / "scripts/asic_dc/assert_no_gtech.tcl": "rtl/assert_no_gtech.tcl",
        DP_OVERLAY: "rtl/async_cmr_noc16_datapath.sdc",
        INNER_OVERLAY: "rtl/async_cmr_noc16_inner.sdc",
        LINK_OVERLAY: "rtl/async_cmr_noc16_link.sdc",
        DP_TARGET: "rtl/" + DP_TARGET.name,
        INNER_TARGET: "rtl/" + INNER_TARGET.name,
        link_target: "rtl/" + link_target.name,
    }
    remaining = list(files.items())
    while remaining:
        source, destination = remaining[0]
        print("UPLOAD", destination, flush=True)
        uploaded = False
        last_exc: Exception | None = None
        for attempt in range(2):
            try:
                atomic_put(client, None, source, ROOT + "/" + destination)
                uploaded = True
                break
            except Exception as exc:
                last_exc = exc
                print("UPLOAD_RETRY", destination, "attempt", attempt + 2, exc, flush=True)
                try:
                    client.close()
                except Exception:
                    pass
                time.sleep(8 * (attempt + 1))
                client = connect()
        if not uploaded:
            raise RuntimeError("upload failed %s: %s" % (destination, last_exc))
        remaining.pop(0)

    report_dir = ROOT + "/reports/dc/" + run_id
    wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
    log = ROOT + "/logs/dc/" + run_id + ".log"
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
        "CMR_USE_CIRCULAR_FIFO=1 CMR_BYPASS_INTERLEVEL_FIFO=0 "
        "CMR_DATAPATH_SEED_DDC=%s CMR_DATAPATH_OVERLAY=%s "
        "CMR_DATAPATH_TARGET_FILE=%s CMR_DATAPATH_REPORT_DIR=%s "
        "CMR_INNER_OVERLAY=%s CMR_INNER_TARGET_FILE=%s "
        "CMR_INNER_RTC_CLASS=%s CMR_INNER_REPORT_DIR=%s "
        "CMR_LINK_OVERLAY=%s CMR_LINK_TARGET_FILE=%s "
        "CMR_LINK_PHASE=%s CMR_LINK_REPORT_DIR=%s "
        "CMR_RCU_MATCHED_DELAY_STEPS=%s CMR_RCU_MATCHED_BUF_STAGES=%s "
        "CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
        "CMR_OPM_ACKIN_DELAY_STEPS=%s CMR_OPM_ACKIN_DELAY_UNIT_PS=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_noc16.tcl\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(seed),
            shlex.quote(ROOT + "/rtl/async_cmr_noc16_datapath.sdc"),
            shlex.quote(ROOT + "/rtl/" + DP_TARGET.name),
            shlex.quote(report_dir),
            shlex.quote(ROOT + "/rtl/async_cmr_noc16_inner.sdc"),
            shlex.quote(ROOT + "/rtl/" + INNER_TARGET.name),
            shlex.quote(INNER_CLASS),
            shlex.quote(report_dir),
            shlex.quote(ROOT + "/rtl/async_cmr_noc16_link.sdc"),
            shlex.quote(ROOT + "/rtl/" + link_target.name),
            shlex.quote(phase),
            shlex.quote(report_dir),
            shlex.quote(os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "1")),
            shlex.quote(os.environ.get("CMR_RCU_MATCHED_BUF_STAGES", "16")),
            shlex.quote(os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "50")),
            shlex.quote(os.environ.get("CMR_OPM_ACKIN_DELAY_STEPS", "1")),
            shlex.quote(os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "50")),
            ROOT,
            ROOT,
        )
    )
    atomic_put_bytes(client, None, body.encode(), wrapper)
    remote_run(client, "chmod +x " + wrapper)
    remote_run(client, "rm -f %s %s.err" % (shlex.quote(log), shlex.quote(log)))
    submit = remote_run(
        client,
        "bsub -n 8 -o %s -e %s.err -J cmr_noc16_dc_%s %s"
        % (log, log, run_id, wrapper),
    )
    dc_job = job_id(submit)
    print("DC_JOB", dc_job, "seed", seed_run, "run", run_id, "phase", phase, flush=True)
    dc_failed = False
    try:
        wait_job(client, dc_job, "dc")
    except Exception:
        dc_failed = True
    dc_text = remote_run(
        client,
        "grep -h -E '^CMR_NOC16_|^CMR_INNER_|^CMR_DATAPATH_|^CMR_LINK_|^CMR_DEL_SHRINK|^Error:' "
        "%s %s.err 2>/dev/null; echo '---TAIL---'; tail -n 40 %s %s.err 2>/dev/null"
        % (log, log, log, log),
    )
    result = CMR / "results" / run_id
    result.mkdir(parents=True, exist_ok=True)
    (result / "dc.log").write_text(dc_text, encoding="utf-8", errors="replace")
    sftp = client.open_sftp()
    try:
        fetch_tree(sftp, ROOT + "/reports/dc/" + run_id, result / "reports_dc")
    except IOError:
        pass
    sftp.close()
    print(dc_text[-12000:], flush=True)

    def _marker(name: str) -> bool:
        for line in dc_text.splitlines():
            stripped = line.split(":", 1)[-1] if "/logs/" in line else line
            if stripped.startswith(name) and "puts " not in stripped:
                return True
        return False

    if dc_failed or not _marker("CMR_NOC16_DC_PASS"):
        raise RuntimeError("link incremental DC failed")
    if _marker("CMR_LINK_FAIL") or _marker("CMR_INNER_FAIL") or _marker("CMR_DATAPATH_FAIL"):
        raise RuntimeError("link overlay failed")
    if not _marker("CMR_LINK_PASS"):
        raise RuntimeError("link overlay did not report PASS")
    print("CMR_LINK_DC_PASS", run_id, phase, flush=True)
    client.close()
    return dc_job


def main() -> None:
    args = _parse_args()
    rtm = args.rtm
    extra = args.extra_slack
    phase = args.phase
    seed_run = args.seed_run
    seed_sha = args.seed_sha256
    skip_sdf = os.environ.get("CMR_NOC16_SKIP_SDF", "0") == "1"
    skip_sta = os.environ.get("CMR_LINK_SKIP_STA", "0") == "1"
    skip_dc = os.environ.get("CMR_LINK_SKIP_DC", "0") == "1"
    print(
        "CMR_LINK_SEED",
        seed_run,
        seed_sha,
        "phase",
        phase,
        "rtm",
        rtm,
        flush=True,
    )
    if seed_run != SEED_RUN:
        print("CMR_LINK_SEED_OVERRIDE expected", SEED_RUN, flush=True)
    run_id = args.run_id or os.environ.get("CMR_NOC16_RUN_ID") or (
        "20260827_cmr_cfifo_link_sta" if phase == "measure" else "20260827_cmr_cfifo_link_rtm5"
    )
    result = CMR / "results" / run_id
    result.mkdir(parents=True, exist_ok=True)

    if not DP_OVERLAY.is_file() or not INNER_OVERLAY.is_file() or not LINK_OVERLAY.is_file():
        raise SystemExit("missing datapath, inner, or link overlay")
    if not DP_TARGET.is_file() or not INNER_TARGET.is_file():
        raise SystemExit("missing frozen datapath or inner targets")

    sta_summary = result / "paired_sta_summary.json"
    if phase == "measure" or not sta_summary.is_file():
        sta_id = run_id if phase == "measure" else run_id + "_seed_sta"
        sta_result = CMR / "results" / sta_id
        sta_result.mkdir(parents=True, exist_ok=True)
        _run_sta(seed_run, sta_id)
        summary = _extract_sta(sta_id, seed_run, sta_result, rtm)
        _check_summary(
            summary,
            rtm,
            require_links=True,
            allow_link_shortfall=(phase == "measure"),
        )
        if phase == "measure":
            if sta_result.resolve() != result.resolve():
                shutil.copyfile(
                    sta_result / "paired_sta_summary.json",
                    result / "paired_sta_summary.json",
                )
                if (sta_result / "paired_catalog.csv").is_file():
                    shutil.copyfile(
                        sta_result / "paired_catalog.csv",
                        result / "paired_catalog.csv",
                    )
            freeze = {
                "role": "step_G_link_rtc_measure",
                "run_id": run_id,
                "phase": "measure",
                "rtm_target": rtm,
                "seed_run": seed_run,
                "seed_ddc_sha256": seed_sha,
                "rollback_remains": ROLLBACK,
                "production_sdc": False,
                "synth_closed": False,
                "phys_closed": False,
                "paired_sta": {
                    rtc: summary.get("ids", {}).get(rtc, {})
                    for rtc in list(ROUTER_IDS) + list(LINK_IDS)
                },
            }
            _archive(run_id, freeze, result / "paired_sta_summary.json")
            print("CMR_LINK_MEASURE_PASS", run_id, flush=True)
            return
        shutil.copyfile(sta_result / "paired_sta_summary.json", sta_summary)

    link_target = CMR / (run_id + "_targets.tcl")
    _generate_link_targets(sta_summary, link_target, rtm, extra, phase)

    if skip_dc:
        dc_job = "skipped"
        print("CMR_LINK_DC_SKIP", run_id, flush=True)
    else:
        dc_job = _run_dc(run_id, seed_run, seed_sha, phase, link_target)

    if not skip_sta:
        sta_id = run_id + "_paired_sta"
        _run_sta(run_id, sta_id)
        summary = _extract_sta(sta_id, run_id, result, rtm)
        _check_summary(summary, rtm, require_links=True)
        print("CMR_LINK_STA_PASS", sta_id, flush=True)
    else:
        summary = (
            json.loads(sta_summary.read_text(encoding="utf-8"))
            if sta_summary.is_file()
            else {}
        )

    gls = {}
    if not skip_sdf:
        env = os.environ.copy()
        env["CMR_NOC16_RUN_ID"] = run_id
        env["CMR_NOC16_NETLIST_RUN_ID"] = run_id
        env["CMR_NOC16_RX_CAPTURE_NS"] = "5"
        env["CMR_NOC16_SIM_ARGS"] = "+ACK_TO_NEXT_REQ_GUARD_NS=0.20"
        env["CMR_NOC16_CASES"] = "TAB-NET-UR-3f-r0p50,VCTM-MC5-NM-3f-r0p50"
        env["CMR_NOC16_STRUCTURAL_ENDPOINTS"] = "0"
        env["CMR_USE_CIRCULAR_FIFO"] = "1"
        subprocess.run(
            [sys.executable, str(CMR / "run_remote_cmr_noc16_async_sdf.py")],
            cwd=CMR,
            env=env,
            check=True,
        )
        gls_path = result / "summary.json"
        if gls_path.is_file():
            gls = json.loads(gls_path.read_text(encoding="utf-8"))
        print("CMR_LINK_REGRESSION_PASS", run_id, flush=True)

    cases = gls.get("cases", {})
    freeze = {
        "role": "step_G_link_rtc",
        "run_id": run_id,
        "phase": phase,
        "rtm_target": rtm,
        "extra_slack_ns": extra,
        "seed_run": seed_run,
        "seed_ddc_sha256": seed_sha,
        "rollback_remains": ROLLBACK,
        "dc_job": dc_job,
        "inner_class": INNER_CLASS,
        "del_resized": False,
        "synth_closed": True,
        "phys_closed": False,
        "hashes": _read_hashes(run_id),
        "structure": _read_structure(run_id),
        "paired_sta": {
            rtc: {
                "tdata_max_ns": info.get("tdata_max_ns"),
                "tctrl_min_ns": info.get("tctrl_min_ns"),
                "worst_rtm_pct": info.get("worst_rtm_pct"),
                "shortfall_at_rtm_ns": info.get("shortfall_at_rtm_ns"),
                "no_path": info.get("no_path_count"),
                "status": info.get("status"),
            }
            for rtc, info in summary.get("ids", {}).items()
            if rtc in ROUTER_IDS or rtc in LINK_IDS
        },
        "gls_jobs": {
            name: info.get("job_id")
            for name, info in cases.items()
            if isinstance(info, dict)
        },
    }
    _archive(run_id, freeze, result / "paired_sta_summary.json")
    print("CMR_LINK_SYNTH_CLOSED", run_id, flush=True)


if __name__ == "__main__":
    main()
