#!/usr/bin/env python3
"""Build inner-loop / outer-RTM control min/max windows.

    Tctrl_min = Tdata_max * (1 + RTM)
    Tctrl_max = Tctrl_min + extra_slack

Step E (RTM 0%) is one catalog class per run_id.  Step F (RTM 5%) uses
class CMR-OUTER-RTM5 to re-apply every closable window from the last 0%
DDC.  Frozen DEL roles (RCU 4xDEL150) keep max floored at measured
Tctrl_min until a dedicated shrink knife.  OPM Ackin DEL250 is not this
Tctrl.
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path


CLASS_ORDER = (
    "CMR-OPM-01",
    "CMR-RCU-01",
    "CMR-AR-01",
    "CMR-FIFO-01",
    "CMR-HS-01",
    "CMR-HS-02",
    "CMR-WP-01",
    "CMR-RP-01",
    "CMR-TP-01",
)

CLOSABLE = frozenset({"CMR-OPM-01", "CMR-RCU-01", "CMR-AR-01"})
OUTER_CLASS = "CMR-OUTER-RTM5"
CLOSABLE_OR_OUTER = CLOSABLE | {OUTER_CLASS}

REFUSE = {
    "CMR-FIFO-01": "N/A on CircularFIFO DUT (AsyncFifo predecessor only)",
    "CMR-LANE-01": "thin N/A (ADAPTER=0)",
    "CMR-MTX-01": "not a delay RTM",
    "CMR-XOR-01": "corollary of WP-01, not a separate inner-loop class",
    "CMR-OPM-01-CE": "same-close measurement sub-clause, not an inner-loop ID",
    "CMR-HS-01": "later knife; never delay complete / HeadPredictor CP",
    "CMR-HS-02": "library pulse at WriteCounter CK, not a combo min/max window",
    "CMR-WP-01": "interface endpoint 0.20 ns; do not change Fig. 7 XOR",
    "CMR-RP-01": "defined, not yet measured; do not copy write-side DEL",
    "CMR-TP-01": "later knife after OPM/RCU/AR; no TailPassed RTL DEL",
    "TCF-HS-02": "unit ECO already on this DDC; not a router inner-loop class",
    "TCF-RD-01": "data cone closed in step D; Reqout ECO is not this inner loop",
    "CMR-LINK-FWD-01": "step G; use run_remote_cmr_noc16_link.py",
    "CMR-LINK-ENQ-01": "step G; use run_remote_cmr_noc16_link.py",
    "CMR-LINK-ACK-01": "step G; use run_remote_cmr_noc16_link.py",
    "CMR-LINK-IO-01": "step G; use run_remote_cmr_noc16_link.py",
}

STA_DEFAULT = Path(
    "docs/timing_baselines/"
    "20260827_cmr_cfifo_noc16_rd01_eco16_p50_01_paired_sta_summary.json"
)


def normalize_class(name: str) -> str:
    raw = name.strip().upper().replace("_", "-")
    if raw in ("OPM01", "OPM-01"):
        return "CMR-OPM-01"
    if raw in ("RCU01", "RCU-01"):
        return "CMR-RCU-01"
    if raw in ("AR01", "AR-01"):
        return "CMR-AR-01"
    if raw in ("OUTER", "OUTER-RTM5", "CMR-OUTER", "CMR-OUTER-RTM5"):
        return OUTER_CLASS
    if not raw.startswith("CMR-") and not raw.startswith("TCF-"):
        raw = "CMR-" + raw
    return raw


def refuse_reason(rtc_class: str) -> str | None:
    if rtc_class in CLOSABLE_OR_OUTER:
        return None
    if rtc_class in REFUSE:
        return REFUSE[rtc_class]
    return "unknown RTC class (not in step-E/F inner-loop catalog)"


def _round_ns(value: float) -> float:
    return round(value, 3)


def _window(
    tdata: float,
    rtm: float,
    extra: float,
    tctrl_floor: float | None,
) -> tuple[float, float]:
    tmin = _round_ns(tdata * (1.0 + rtm))
    tmax = _round_ns(tmin + extra)
    if tctrl_floor is not None:
        floor = _round_ns(tctrl_floor)
        if tmax < floor:
            tmax = floor
    return tmin, tmax


def build_targets(
    summary: dict,
    rtc_class: str,
    rtm: float,
    extra: float,
) -> dict:
    ids = summary.get("ids", {})
    opm = ids.get("CMR-OPM-01", {})
    rcu = ids.get("CMR-RCU-01", {})
    opm_tdata = float(opm["tdata_max_ns"])
    opm_tctrl = float(opm["tctrl_min_ns"])
    rcu_tdata = float(rcu["tdata_max_ns"])
    rcu_tctrl = float(rcu["tctrl_min_ns"])
    opm_min, opm_max = _window(opm_tdata, rtm, extra, None)
    rcu_min, rcu_max = _window(rcu_tdata, rtm, extra, rcu_tctrl)
    return {
        "rtm_target": rtm,
        "rtc_class": rtc_class,
        "extra_slack_ns": _round_ns(extra),
        "baseline_run": summary.get("baseline"),
        "sta_run": summary.get("run_id"),
        "tdata_source": "paired STA Tdata_max from --sta-summary; datapath max-delay stays sourced first",
        "class_order": list(CLASS_ORDER),
        "closable": sorted(CLOSABLE),
        "outer_applies": ["CMR-OPM-01", "CMR-RCU-01", "CMR-AR-01"],
        "windows": {
            "CMR-OPM-01": {
                "tdata_max_ns": opm_tdata,
                "tctrl_min_measured_ns": opm_tctrl,
                "required_min_ns": opm_min,
                "required_max_ns": opm_max,
                "frozen_del": False,
                "squeeze": True,
                "from": "L1_L4.Q",
                "to": "L5.D (XOR combo; not RegEnable/DataReg.E)",
            },
            "CMR-RCU-01": {
                "tdata_max_ns": rcu_tdata,
                "tctrl_min_measured_ns": rcu_tctrl,
                "required_min_ns": rcu_min,
                "required_max_ns": rcu_max,
                "frozen_del": True,
                "squeeze": False,
                "from": "LatchReg[24].Q (Req_rc)",
                "to": "RouteSelAnd2.g/Z",
            },
            "CMR-AR-01": {
                "tdata_max_ns": 0.0,
                "tctrl_min_measured_ns": 0.0,
                "required_min_ns": 0.0,
                "required_max_ns": 0.0,
                "frozen_del": False,
                "squeeze": False,
                "measure_on_seed": True,
                "from": "HeadPredictor.en_state_reg/Q",
                "to": "LatchReg.E",
            },
        },
        "applied": rtc_class,
        "near_floor_ns": 0.020,
    }


def emit_tcl(targets: dict) -> str:
    opm = targets["windows"]["CMR-OPM-01"]
    rcu = targets["windows"]["CMR-RCU-01"]
    ar = targets["windows"]["CMR-AR-01"]
    return "\n".join(
        [
            "# Generated; do not edit. Inner/outer control min/max.",
            "# RTM=%.3f class=%s extra_slack=%.3f ns."
            % (targets["rtm_target"], targets["rtc_class"], targets["extra_slack_ns"]),
            "# Source STA %s on %s."
            % (targets.get("sta_run"), targets.get("baseline_run")),
            "set CMR_INNER_CLASS %s" % targets["rtc_class"],
            "set CMR_INNER_RTM %.6f" % targets["rtm_target"],
            "set CMR_INNER_EXTRA_SLACK_NS %.3f" % targets["extra_slack_ns"],
            "set CMR_INNER_NEAR_FLOOR_NS %.3f" % targets["near_floor_ns"],
            "set CMR_INNER_OPM_TDATA_NS %.6f" % opm["tdata_max_ns"],
            "set CMR_INNER_OPM_MIN_NS %.3f" % opm["required_min_ns"],
            "set CMR_INNER_OPM_MAX_NS %.3f" % opm["required_max_ns"],
            "set CMR_INNER_RCU_TDATA_NS %.6f" % rcu["tdata_max_ns"],
            "set CMR_INNER_RCU_MIN_NS %.3f" % rcu["required_min_ns"],
            "set CMR_INNER_RCU_MAX_NS %.3f" % rcu["required_max_ns"],
            "set CMR_INNER_RCU_FROZEN_DEL %d" % (1 if rcu["frozen_del"] else 0),
            "set CMR_INNER_AR_MIN_NS %.3f" % ar["required_min_ns"],
            "set CMR_INNER_AR_MAX_NS %.3f" % ar["required_max_ns"],
            "",
        ]
    )


def default_run_id(rtc_class: str, rtm: float) -> str:
    pct = int(round(rtm * 100.0))
    if rtc_class == OUTER_CLASS:
        return "20260827_cmr_cfifo_outer_rtm%d" % pct
    short = rtc_class.lower().replace("cmr-", "").replace("-", "")
    return "20260827_cmr_cfifo_inner_%s_rtm%d" % (short, pct)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sta-summary", type=Path, default=STA_DEFAULT)
    parser.add_argument("--out", type=Path)
    parser.add_argument("--class", dest="rtc_class", default="CMR-OPM-01")
    parser.add_argument("--rtm", type=float, default=0.0)
    parser.add_argument("--extra-slack", type=float, default=0.100)
    args = parser.parse_args()
    rtc_class = normalize_class(args.rtc_class)
    reason = refuse_reason(rtc_class)
    if reason:
        raise SystemExit("CMR_INNER_REFUSE class=%s reason=%s" % (rtc_class, reason))
    if args.rtm < 0.0:
        raise SystemExit("rtm must be >= 0")
    if args.extra_slack < 0.0:
        raise SystemExit("extra-slack must be >= 0")
    if not args.sta_summary.is_file():
        raise SystemExit("missing STA summary %s" % args.sta_summary)
    summary = json.loads(args.sta_summary.read_text(encoding="utf-8"))
    targets = build_targets(summary, rtc_class, args.rtm, args.extra_slack)
    out = args.out
    if out is None:
        out = Path("scripts/asic_dc/cmr") / (default_run_id(rtc_class, args.rtm) + "_targets.tcl")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(emit_tcl(targets), encoding="utf-8")
    out.with_suffix(out.suffix + ".json").write_text(
        json.dumps(targets, indent=2) + "\n", encoding="utf-8"
    )
    print(json.dumps(targets, indent=2))


if __name__ == "__main__":
    main()
