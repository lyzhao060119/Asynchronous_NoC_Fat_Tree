#!/usr/bin/env python3
"""Step F: ask whether one control role is overdesigned at RTM 5%.

Uses paired STA Tdata_max / Tctrl_min.  Does not write SDC or change cells.
One role at a time, in plan order:

    RCU drop one DEL150
        -> RCU replace tail DEL150 with BUFFD0
        -> OPM XOR extra_slack squeeze
        -> FIFO 1xDEL150 (N/A)
        -> OPM Ackin DEL250 (pulse floor, never from D/E)
        -> endpoint 0.20 ns (not in this compile)

A full DEL drop is eligible only when leftover Tctrl is at least one
measured DEL150 step (~0.20 ns on this path, from 4->3).  Residual
finer than that uses BUFFD0, not another DEL150.  Ackin is the V2 pulse
floor, not OPM-01 Tctrl.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from extract_cmr_paired_sta import rtm_required_and_shortfall


DEL150_NS = 0.150
MEASURED_DEL150_NS = 0.200
BUFFD0_NS = 0.010
DEL250_NS = 0.250
ENDPOINT_NS = 0.20
NEAR_FLOOR_NS = 0.020
ROLLBACK = "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01"
ROLE_ORDER = (
    "RCU_DEL150",
    "RCU_DEL150_TO_BUF",
    "OPM_XOR_SQUEEZE",
    "FIFO_DEL150",
    "OPM_ACKIN",
    "WP_ENDPOINT_0P20",
)


def _overdesign(tdata: float | None, tctrl: float | None, rtm: float) -> dict:
    required, shortfall = rtm_required_and_shortfall(tdata, tctrl, rtm)
    extra = None
    if tdata is not None and tctrl is not None and required is not None:
        extra = tctrl - required
    return {
        "tdata_max_ns": tdata,
        "tctrl_min_ns": tctrl,
        "required_tctrl_ns": required,
        "shortfall_at_rtm_ns": shortfall,
        "overdesign_ns": extra,
    }


def _next_opm_extra(current: float, near_floor: float) -> float | None:
    if current > 0.075:
        return 0.050
    if current > near_floor + 1.0e-9:
        return 0.020
    return None


def build_verdict(
    summary: dict,
    rtm: float,
    *,
    rcu_steps: int = 4,
    measured_step_ns: float = MEASURED_DEL150_NS,
    extra_slack_ns: float = 0.100,
    buf_stages: int = 0,
    buf_n: int = 8,
    near_floor_ns: float = NEAR_FLOOR_NS,
    ackin_steps: int = 1,
) -> dict:
    ids = summary.get("ids", {})
    rcu = ids.get("CMR-RCU-01", {})
    opm = ids.get("CMR-OPM-01", {})
    rcu_od = _overdesign(rcu.get("tdata_max_ns"), rcu.get("tctrl_min_ns"), rtm)
    opm_od = _overdesign(opm.get("tdata_max_ns"), opm.get("tctrl_min_ns"), rtm)
    rcu_extra = rcu_od["overdesign_ns"]
    rcu_steps_over = None if rcu_extra is None else rcu_extra / measured_step_ns
    rcu_closed = bool(
        rcu_od["shortfall_at_rtm_ns"] is not None
        and rcu_od["shortfall_at_rtm_ns"] == 0.0
    )
    rcu_can_drop = bool(
        rcu_closed
        and rcu_extra is not None
        and rcu_extra >= measured_step_ns
        and rcu_steps >= 2
    )
    rcu_can_buf = bool(
        rcu_closed
        and rcu_extra is not None
        and not rcu_can_drop
        and rcu_extra >= BUFFD0_NS
        and rcu_steps >= 2
        and buf_stages == 0
    )
    next_extra = _next_opm_extra(extra_slack_ns, near_floor_ns)
    opm_can_squeeze = bool(
        next_extra is not None
        and opm_od["shortfall_at_rtm_ns"] is not None
        and opm_od["shortfall_at_rtm_ns"] == 0.0
    )

    roles = {
        "RCU_DEL150": {
            "present_on_dut": True,
            "rtc": "CMR-RCU-01",
            "current": "%dxDEL150 (%d cells)" % (rcu_steps, 25 * rcu_steps),
            "nominal_step_ns": DEL150_NS,
            "measured_step_ns": measured_step_ns,
            "steps": rcu_steps,
            "cell_count": 25 * rcu_steps,
            **rcu_od,
            "steps_of_overdesign": rcu_steps_over,
            "eligible": rcu_can_drop,
            "recommended_next": (
                "%dxDEL150 (drop highest DelayUnit_delay on all 25 RCUs)"
                % (rcu_steps - 1)
                if rcu_can_drop
                else "keep %dxDEL150" % rcu_steps
            ),
            "note": "MatchedDelay on Req_rc.  This is the RCU-01 Tctrl DEL.",
        },
        "RCU_DEL150_TO_BUF": {
            "present_on_dut": True,
            "rtc": "CMR-RCU-01",
            "current": "%dxDEL150; matched_buf_stages=%d" % (rcu_steps, buf_stages),
            "nominal_step_ns": BUFFD0_NS,
            "buf_n": buf_n,
            "steps": rcu_steps,
            **rcu_od,
            "eligible": rcu_can_buf,
            "recommended_next": (
                "replace tail DEL150 with %dxBUFFD0 on all 25 RCUs (leave %dxDEL150)"
                % (buf_n, rcu_steps - 1)
                if rcu_can_buf
                else "keep remaining DEL150"
            ),
            "note": (
                "Finer than one measured DEL150 (~0.20 ns).  Do not drop "
                "another full DEL150; splice BUFFD0 on the tail load."
            ),
        },
        "OPM_XOR_SQUEEZE": {
            "present_on_dut": True,
            "rtc": "CMR-OPM-01",
            "current": "extra_slack=%.3f ns on L1_L4.Q -> L5.D" % extra_slack_ns,
            "extra_slack_ns": extra_slack_ns,
            "next_extra_slack_ns": next_extra,
            "near_floor_ns": near_floor_ns,
            **opm_od,
            "eligible": opm_can_squeeze,
            "recommended_next": (
                "cut OPM extra_slack to %.3f ns" % next_extra
                if opm_can_squeeze
                else "OPM XOR extra_slack already at near-floor or ineligible"
            ),
            "note": (
                "Squeeze XOR combo only.  Do not constrain RegEnable / "
                "DataReg.E from this role.  Ackin delete and L5.Q→DataReg.E "
                "max-delay are explicit F knives, not this auto loop."
            ),
        },
        "FIFO_DEL150": {
            "present_on_dut": False,
            "rtc": "CMR-FIFO-01",
            "current": "0 (CircularFIFO; AsyncFifo predecessor only)",
            "eligible": False,
            "recommended_next": "n/a",
            "note": "N/A on this DUT. TCF-RD-01 is a BUFFD0 ECO, not a DEL role.",
        },
        "OPM_ACKIN": {
            "present_on_dut": ackin_steps > 0,
            "rtc": "CMR-OPM-01-CE",
            "current": (
                "1xDEL250 (25 cells)"
                if ackin_steps > 0
                else "deleted (Ultra combinational Ackin)"
            ),
            "nominal_step_ns": DEL250_NS,
            "steps": ackin_steps,
            "eligible": False,
            "recommended_next": (
                "keep 1xDEL250 (auto); explicit campaign size_cell to a smaller DEL*"
                if ackin_steps > 0
                else "already deleted"
            ),
            "opm01_d_vs_e": opm_od,
            "note": (
                "Ackin DEL is the V2 close-loop pulse floor, not OPM-01 Tctrl. "
                "Auto loop stays ineligible.  Explicit F knife OPM_ACKIN_RESIZE "
                "size_cell's the 25 leaves (keep the instance).  OPM_ACKIN "
                "splice-remove stalled SDF GLS."
            ),
        },
        "WP_ENDPOINT_0P20": {
            "present_on_dut": False,
            "rtc": "CMR-WP-01",
            "current": "source DEL150+DEL050 = 0.20 ns (not in this compile)",
            "nominal_step_ns": ENDPOINT_NS,
            "eligible": False,
            "recommended_next": "n/a",
            "note": "NoC-only DDC has no source endpoint.  Plan H postponed WP SDC.",
        },
    }

    first = None
    for name in ROLE_ORDER:
        if roles[name]["eligible"]:
            first = name
            break

    if first:
        action = "shrink %s one step; fail rolls back to %s" % (first, ROLLBACK)
    else:
        action = "no eligible control shrink; 5% floor reached for remaining roles"

    return {
        "rtm_target": rtm,
        "sta_run": summary.get("run_id"),
        "baseline": summary.get("baseline"),
        "rcu_steps": rcu_steps,
        "buf_stages": buf_stages,
        "ackin_steps": ackin_steps,
        "extra_slack_ns": extra_slack_ns,
        "measured_step_ns": measured_step_ns,
        "roles": roles,
        "first_shrink_role": first,
        "action": action,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--sta-summary",
        type=Path,
        default=Path(
            "docs/timing_baselines/"
            "20260827_cmr_cfifo_inner_ar01_rtm0_paired_sta_summary.json"
        ),
    )
    parser.add_argument("--rtm", type=float, default=0.05)
    parser.add_argument("--rcu-steps", type=int, default=4)
    parser.add_argument("--measured-step-ns", type=float, default=MEASURED_DEL150_NS)
    parser.add_argument("--extra-slack", type=float, default=0.100)
    parser.add_argument("--buf-stages", type=int, default=0)
    parser.add_argument("--buf-n", type=int, default=8)
    parser.add_argument("--ackin-steps", type=int, default=1)
    parser.add_argument("--near-floor", type=float, default=NEAR_FLOOR_NS)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    summary = json.loads(args.sta_summary.read_text(encoding="utf-8"))
    verdict = build_verdict(
        summary,
        args.rtm,
        rcu_steps=args.rcu_steps,
        measured_step_ns=args.measured_step_ns,
        extra_slack_ns=args.extra_slack,
        buf_stages=args.buf_stages,
        buf_n=args.buf_n,
        near_floor_ns=args.near_floor,
        ackin_steps=args.ackin_steps,
    )
    text = json.dumps(verdict, indent=2) + "\n"
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(text, encoding="utf-8")
    print(text, end="")


if __name__ == "__main__":
    main()
