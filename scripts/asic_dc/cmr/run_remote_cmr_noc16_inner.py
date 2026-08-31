#!/usr/bin/env python3
"""Step E/F: Fig. 6 inner-loop DC, one RTC class per run_id at RTM 0%,
or CMR-OUTER-RTM5 at RTM 5% from the last closed 0% DDC.

Default seed is the last closed knife: OPM-01 starts from step D;
RCU-01 starts from 20260827_cmr_cfifo_inner_opm01_rtm0;
AR-01 starts from 20260827_cmr_cfifo_inner_rcu01_rtm0.
RTM 5% / OUTER starts from 20260827_cmr_cfifo_inner_ar01_rtm0.
Override with CMR_INNER_SEED_RUN / CMR_INNER_SEED_SHA256.
Does not shrink DEL cells unless CMR_DEL_SHRINK_ROLE is set
(RCU_DEL150 drops the highest remaining MatchedDelay DEL150;
RCU_DEL150_TO_BUF replaces that tail cell with BUFFD0;
RCU_SIZE_TO_DEL050 size_cell's 25 MatchedDelay DEL150 leaves to DEL050;
RCU_TRIM_BUF / RCU_ADD_BUF remove or insert rcu_matched_buf_s* to
CMR_RCU_MATCHED_BUF_STAGES;
OPM_ACKIN splice-removes the 25 AckinDelay DelayElement instances;
OPM_ACKIN_RESIZE size_cell's those 25 leaves to CMR_OPM_ACKIN_DELAY_UNIT_PS).
CMR_OPM_E_MAX_NS applies max-delay-only on L5.Q→DataReg.E.
Rollback remains 20260827_cmr_cfifo_noc16_rd01_eco16_p50_01.
"""
from __future__ import annotations

import argparse
import json
import os
import shlex
import subprocess
import sys
import time
from pathlib import Path

from create_cmr_inner_targets import (
    CLOSABLE_OR_OUTER,
    OUTER_CLASS,
    default_run_id,
    normalize_class,
    refuse_reason,
)
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
CLASS_SEEDS = {
    "CMR-OPM-01": (
        "20260827_cmr_cfifo_datapath_r1",
        "91f6168230fd1d76d73bffcac45f82243f5feb456eb87780a98480fcca4a954d",
    ),
    "CMR-RCU-01": (
        "20260827_cmr_cfifo_inner_opm01_rtm0",
        "670ec96a7ff881b0d662d766dfd52d0cddeb2cec0bd097f7a5d19fc08929ab16",
    ),
    "CMR-AR-01": (
        "20260827_cmr_cfifo_inner_rcu01_rtm0",
        "abf891c90c43600c859ac2567352d257a52810d379461b213986768f2c716bd7",
    ),
}
RTM0_CLOSED = (
    "20260827_cmr_cfifo_inner_ar01_rtm0",
    "b5cbd6b4fad40196e7957ba1abf06bfa77757a1c729fcb2ef2b829bc9c8bca9c",
)
ROLLBACK = "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
DP_OVERLAY = CMR / "async_cmr_noc16_datapath.sdc"
INNER_OVERLAY = CMR / "async_cmr_noc16_inner.sdc"
DP_TARGET = CMR / "20260827_cmr_cfifo_datapath_r1_targets.tcl"
STA_SUMMARY_C = (
    REPO
    / "docs"
    / "timing_baselines"
    / "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json"
)
STA_SUMMARY_E = (
    REPO
    / "docs"
    / "timing_baselines"
    / "20260827_cmr_cfifo_inner_ar01_rtm0_paired_sta_summary.json"
)


def default_sta_summary(rtm: float) -> Path:
    if rtm >= 0.049:
        return STA_SUMMARY_E
    return STA_SUMMARY_C


def resolve_seed(rtc_class: str, rtm: float) -> tuple[str, str]:
    if os.environ.get("CMR_INNER_SEED_RUN"):
        return (
            os.environ["CMR_INNER_SEED_RUN"],
            os.environ.get("CMR_INNER_SEED_SHA256", ""),
        )
    if rtm >= 0.049 or rtc_class == OUTER_CLASS:
        return RTM0_CLOSED
    return CLASS_SEEDS[rtc_class]


def _generate_datapath_targets() -> None:
    if DP_TARGET.is_file():
        return
    subprocess.run(
        [
            sys.executable,
            str(CMR / "create_cmr_datapath_targets.py"),
            "--sta-summary",
            str(STA_SUMMARY_C),
            "--out",
            str(DP_TARGET),
            "--scale",
            "0.95",
            "--rd01-tdata",
            "0.295973",
        ],
        cwd=REPO,
        check=True,
    )


def _generate_inner_targets(
    rtc_class: str, rtm: float, extra: float, out: Path, sta_summary: Path
) -> None:
    subprocess.run(
        [
            sys.executable,
            str(CMR / "create_cmr_inner_targets.py"),
            "--sta-summary",
            str(sta_summary),
            "--out",
            str(out),
            "--class",
            rtc_class,
            "--rtm",
            str(rtm),
            "--extra-slack",
            str(extra),
        ],
        cwd=REPO,
        check=True,
    )


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--class",
        dest="rtc_class",
        default=os.environ.get("CMR_INNER_RTC_CLASS", "CMR-OPM-01"),
    )
    parser.add_argument(
        "--rtm",
        type=float,
        default=float(os.environ.get("CMR_INNER_RTM", "0")),
    )
    parser.add_argument(
        "--extra-slack",
        type=float,
        default=float(os.environ.get("CMR_INNER_EXTRA_SLACK_NS", "0.100")),
    )
    parser.add_argument("--run-id", default=os.environ.get("CMR_NOC16_RUN_ID", ""))
    parser.add_argument("--sta-summary", type=Path, default=None)
    return parser.parse_args()


def main() -> None:
    args = _parse_args()
    rtc_class = normalize_class(args.rtc_class)
    reason = refuse_reason(rtc_class)
    if reason:
        raise SystemExit("CMR_INNER_REFUSE class=%s reason=%s" % (rtc_class, reason))
    if rtc_class not in CLOSABLE_OR_OUTER:
        raise SystemExit("CMR_INNER_REFUSE class=%s not closable this step" % rtc_class)
    rtm = args.rtm
    extra = args.extra_slack
    run_id = args.run_id or os.environ.get("CMR_NOC16_RUN_ID") or default_run_id(
        rtc_class, rtm
    )
    skip_sdf = os.environ.get("CMR_NOC16_SKIP_SDF", "0") == "1"
    skip_sta = os.environ.get("CMR_INNER_SKIP_STA", "0") == "1"
    sta_summary = args.sta_summary or Path(
        os.environ.get("CMR_INNER_STA_SUMMARY", str(default_sta_summary(rtm)))
    )
    seed_run, seed_sha = resolve_seed(rtc_class, rtm)
    if not seed_sha:
        raise SystemExit("CMR_INNER_SEED_SHA256 required when overriding seed run")
    result = CMR / "results" / run_id
    inner_target = CMR / (run_id + "_targets.tcl")

    _generate_datapath_targets()
    _generate_inner_targets(rtc_class, rtm, extra, inner_target, sta_summary)
    if not DP_OVERLAY.is_file() or not INNER_OVERLAY.is_file():
        raise SystemExit("missing datapath or inner overlay")
    if not DP_TARGET.is_file() or not inner_target.is_file():
        raise SystemExit("missing datapath or inner targets")

    client = connect()
    seed = "%s/outputs/%s/NoC_16nodes.ddc" % (ROOT, seed_run)
    probe = remote_run(
        client, "test -s %s && sha256sum %s" % (shlex.quote(seed), shlex.quote(seed))
    )
    if seed_sha not in probe:
        raise RuntimeError("inner-loop seed DDC hash mismatch: " + probe)

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
        DP_TARGET: "rtl/" + DP_TARGET.name,
        inner_target: "rtl/" + inner_target.name,
    }
    sftp = None
    remaining = list(files.items())
    while remaining:
        source, destination = remaining[0]
        print("UPLOAD", destination, flush=True)
        uploaded = False
        last_exc: Exception | None = None
        for attempt in range(2):
            try:
                atomic_put(client, sftp, source, ROOT + "/" + destination)
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

    overlay = ROOT + "/rtl/async_cmr_noc16_datapath.sdc"
    inner = ROOT + "/rtl/async_cmr_noc16_inner.sdc"
    dp_target = ROOT + "/rtl/" + DP_TARGET.name
    inner_tf = ROOT + "/rtl/" + inner_target.name
    report_dir = ROOT + "/reports/dc/" + run_id
    wrapper = ROOT + "/logs/dc/" + run_id + ".sh"
    log = ROOT + "/logs/dc/" + run_id + ".log"
    shrink_role = os.environ.get("CMR_DEL_SHRINK_ROLE", "")
    rcu_steps = os.environ.get("CMR_RCU_MATCHED_DELAY_STEPS", "4")
    buf_stages = os.environ.get("CMR_RCU_MATCHED_BUF_STAGES", "0")
    rcu_unit = os.environ.get("CMR_RCU_MATCHED_DELAY_UNIT_PS", "150")
    ackin_steps = os.environ.get("CMR_OPM_ACKIN_DELAY_STEPS", "")
    ackin_unit = os.environ.get("CMR_OPM_ACKIN_DELAY_UNIT_PS", "")
    opm_e_max = os.environ.get("CMR_OPM_E_MAX_NS", "")
    body = (
        "#!/bin/bash\nsource /etc/profile 2>/dev/null || true\n"
        "module load syn 2>/dev/null || true\n"
        "export CMR_REMOTE_ROOT=%s CMR_NOC16_RUN_ID=%s "
        "CMR_USE_CIRCULAR_FIFO=1 CMR_BYPASS_INTERLEVEL_FIFO=0 "
        "CMR_DATAPATH_SEED_DDC=%s CMR_DATAPATH_OVERLAY=%s "
        "CMR_DATAPATH_TARGET_FILE=%s CMR_DATAPATH_REPORT_DIR=%s "
        "CMR_INNER_OVERLAY=%s CMR_INNER_TARGET_FILE=%s "
        "CMR_INNER_RTC_CLASS=%s CMR_INNER_REPORT_DIR=%s "
        "CMR_DEL_SHRINK_ROLE=%s CMR_RCU_MATCHED_DELAY_STEPS=%s "
        "CMR_RCU_MATCHED_BUF_STAGES=%s CMR_RCU_MATCHED_DELAY_UNIT_PS=%s "
        "CMR_OPM_ACKIN_DELAY_STEPS=%s "
        "CMR_OPM_ACKIN_DELAY_UNIT_PS=%s CMR_OPM_E_MAX_NS=%s\n"
        "cd %s\nexec dc_shell-t -64 -f %s/scripts/dc/run_dc_cmr_noc16.tcl\n"
        % (
            ROOT,
            shlex.quote(run_id),
            shlex.quote(seed),
            shlex.quote(overlay),
            shlex.quote(dp_target),
            shlex.quote(report_dir),
            shlex.quote(inner),
            shlex.quote(inner_tf),
            shlex.quote(rtc_class),
            shlex.quote(report_dir),
            shlex.quote(shrink_role),
            shlex.quote(rcu_steps),
            shlex.quote(buf_stages),
            shlex.quote(rcu_unit),
            shlex.quote(ackin_steps),
            shlex.quote(ackin_unit),
            shlex.quote(opm_e_max),
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
    print(
        "DC_JOB",
        dc_job,
        "seed",
        seed_run,
        "run",
        run_id,
        "class",
        rtc_class,
        "rtm",
        rtm,
        flush=True,
    )
    dc_failed = False
    try:
        wait_job(client, dc_job, "dc")
    except Exception:
        dc_failed = True
    dc_text = remote_run(
        client,
        "grep -E '^CMR_NOC16_|^CMR_INNER_|^CMR_DATAPATH_|^CMR_DEL_SHRINK|^Error:' "
        "%s %s.err 2>/dev/null; echo '---TAIL---'; tail -n 40 %s %s.err 2>/dev/null"
        % (log, log, log, log),
    )
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
        return any(line.startswith(name) for line in dc_text.splitlines())

    if dc_failed or not _marker("CMR_NOC16_DC_PASS"):
        raise RuntimeError("inner-loop incremental DC failed")
    if _marker("CMR_INNER_FAIL"):
        raise RuntimeError("inner overlay failed")
    if _marker("CMR_DATAPATH_FAIL"):
        raise RuntimeError("datapath overlay failed")
    if not _marker("CMR_INNER_PASS"):
        raise RuntimeError("inner overlay did not report PASS")
    print("CMR_INNER_DC_PASS", run_id, rtc_class, flush=True)
    client.close()

    manifest = {
        "role": (
            "step_F_outer_rtm5" if rtm >= 0.049 else "step_E_inner_loop_rtm0"
        ),
        "run_id": run_id,
        "rtc_class": rtc_class,
        "rtm_target": rtm,
        "extra_slack_ns": extra,
        "seed_run": seed_run,
        "seed_ddc_sha256": seed_sha,
        "rollback_remains": ROLLBACK,
        "dc_job": dc_job,
        "one_class_per_run": rtc_class != OUTER_CLASS,
        "del_resized": bool(os.environ.get("CMR_DEL_SHRINK_ROLE")),
        "del_shrink_role": os.environ.get("CMR_DEL_SHRINK_ROLE", ""),
        "rcu_matched_delay_steps": os.environ.get(
            "CMR_RCU_MATCHED_DELAY_STEPS", "4"
        ),
        "rcu_matched_buf_stages": os.environ.get(
            "CMR_RCU_MATCHED_BUF_STAGES", "0"
        ),
        "rcu_matched_delay_unit_ps": os.environ.get(
            "CMR_RCU_MATCHED_DELAY_UNIT_PS", "150"
        ),
        "opm_ackin_delay_steps": os.environ.get(
            "CMR_OPM_ACKIN_DELAY_STEPS", ""
        ),
        "opm_ackin_delay_unit_ps": os.environ.get(
            "CMR_OPM_ACKIN_DELAY_UNIT_PS", ""
        ),
        "opm_e_max_ns": os.environ.get("CMR_OPM_E_MAX_NS", ""),
    }
    (result / "inner_knife_manifest.json").write_text(
        json.dumps(manifest, indent=2) + "\n", encoding="utf-8"
    )

    if not skip_sta:
        sta_id = run_id + "_paired_sta"
        env = os.environ.copy()
        env["CMR_NOC16_BASELINE"] = run_id
        env["CMR_PAIRED_STA_RUN_ID"] = sta_id
        subprocess.run(
            [sys.executable, str(CMR / "run_remote_cmr_noc16_sta_paired.py")],
            cwd=CMR,
            env=env,
            check=True,
        )
        sta_dir = CMR / "results" / sta_id / "sta"
        if sta_dir.is_dir():
            subprocess.run(
                [
                    sys.executable,
                    str(CMR / "extract_cmr_paired_sta.py"),
                    str(sta_dir),
                    "--baseline",
                    run_id,
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
        summary_path = result / "paired_sta_summary.json"
        if summary_path.is_file():
            summary = json.loads(summary_path.read_text(encoding="utf-8"))
            for rtc_id, info in summary.get("ids", {}).items():
                if info.get("status") == "NO_PATH_FAIL":
                    raise RuntimeError(
                        "paired STA no-path for %s after inner knife %s"
                        % (rtc_id, rtc_class)
                    )
                if rtc_id not in ("CMR-OPM-01", "CMR-RCU-01"):
                    continue
                _, sf = rtm_required_and_shortfall(
                    info.get("tdata_max_ns"),
                    info.get("tctrl_min_ns"),
                    rtm,
                )
                if sf is not None and sf > 1.0e-9:
                    raise RuntimeError(
                        "paired STA RTM %.1f%% shortfall for %s after %s: %s ns"
                        % (rtm * 100.0, rtc_id, rtc_class, sf)
                    )
        print("CMR_INNER_STA_PASS", sta_id, flush=True)

    if skip_sdf:
        print("CMR_INNER_DC_ONLY_PASS", run_id, rtc_class, flush=True)
        return

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
    print("CMR_INNER_REGRESSION_PASS", run_id, rtc_class, flush=True)


if __name__ == "__main__":
    main()
