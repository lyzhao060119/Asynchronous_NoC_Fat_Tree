#!/usr/bin/env python3
"""Locked hop delay recipe and run IDs that DC/GLS must not overwrite.

Paper Fat vs Thin delay comparison uses the same Router recipe on every
level: RCU 1xDEL050, zero matched buffers, Ackin 1xDEL050.  Ackin was
not locked to a DontTouchBuf.  Set CMR_FORCE_OVERWRITE_FROZEN=1 only if
you intentionally replace a frozen remote outputs/ or local PPA folder.
"""
from __future__ import annotations

import os

LOCKED_RCU_STEPS = 1
LOCKED_RCU_UNIT_PS = 50
LOCKED_BUF_STAGES = 0
LOCKED_ACKIN_STEPS = 1
LOCKED_ACKIN_UNIT_PS = 50
LOCKED_ACKIN_USE_BUF = False

FROZEN_HOP_NETLIST_RUN_IDS = frozenset(
    {
        "20260830_cmr_thin_l1_hop_del050_ackin050",
        "20260830_cmr_thin_l2_hop_del050_ackin050",
        "20260830_cmr_thin_l3_hop_del050_ackin050",
        "20260830_cmr_fat_l1_hop_del050_ackin050",
        "20260830_cmr_fat_l2_hop_del050_ackin050",
        "20260830_cmr_fat_l3_hop_del050_ackin050",
    }
)
FROZEN_HOP_PPA_RUN_ID = "20260830_cmr_router_level_baseline_del050"
FROZEN_THIN_NOC16_RUN_ID = "20260828_cmr_cfifo_tp_nogrant_p50"
FROZEN_NOC64_ACKIN250_RUN_ID = "20260830_095259_cmr_noc64_p50_1222"
FROZEN_SYNC64_CLOCK_NS = 1.0
FROZEN_SYNC64_THIN_RUN_ID = "20260831_014622_cmr_sync_noc64_thin_p50"
FROZEN_SYNC64_FAT1222_RUN_ID = "20260831_084457_cmr_sync_noc64_fat1222_p50"

FROZEN_WRITE_RUN_IDS = FROZEN_HOP_NETLIST_RUN_IDS | {
    FROZEN_HOP_PPA_RUN_ID,
    FROZEN_THIN_NOC16_RUN_ID,
    FROZEN_NOC64_ACKIN250_RUN_ID,
    FROZEN_SYNC64_THIN_RUN_ID,
    FROZEN_SYNC64_FAT1222_RUN_ID,
}

NOT_FAT_VS_THIN_DELAY = {
    FROZEN_THIN_NOC16_RUN_ID: (
        "Thin NoC16 CFifo network GLS; standalone pointers are del050_buf2 "
        "(Buffer!=0). Not the Fat vs Thin hop delay recipe."
    ),
    "20260830_cmr_thin_l1_hop": (
        "Earlier Thin hop: RCU DEL050 + 16xBUFFD0, Ackin DEL050. Head ~0.958 ns."
    ),
    "20260830_cmr_fat_l1_hop": (
        "Earlier Fat hop: RCU DEL050, buf=0, Ackin DEL250."
    ),
    "20260829_cmr_ft_noc16_lane01_0": (
        "Fat NoC16 1-2-4 ACG FIFO laboratory netlist; Ackin 250."
    ),
    FROZEN_NOC64_ACKIN250_RUN_ID: (
        "Fat NoC64 1-2-2-2 MAXIMUM SDF PASS with Ackin DEL250. Network GLS "
        "predecessor, not the hop delay recipe."
    ),
    FROZEN_SYNC64_THIN_RUN_ID: (
        "Clocked Thin 64-core SyncNoC_64nodes, 1.0 ns SS ZeroWireload. "
        "Not async hop delay."
    ),
    FROZEN_SYNC64_FAT1222_RUN_ID: (
        "Clocked Fat 1-2-2-2 64-core SyncNoC_64nodes, 1.0 ns SS ZeroWireload. "
        "Limiter vs Thin; not async hop delay."
    ),
}


def refuse_overwrite(run_id: str, *, action: str = "write") -> None:
    if not run_id:
        return
    if run_id not in FROZEN_WRITE_RUN_IDS:
        return
    if os.environ.get("CMR_FORCE_OVERWRITE_FROZEN", "0") == "1":
        print("FROZEN_OVERWRITE_FORCED", action, run_id, flush=True)
        return
    raise SystemExit(
        "refusing to %s frozen run_id %s (RCU 1xDEL050 / buf=0 / Ackin 1xDEL050 "
        "hop lock, Thin CURRENT, NoC64 Ackin-250 predecessor, or signed "
        "clocked SyncNoC64 1.0 ns). "
        "Set CMR_FORCE_OVERWRITE_FROZEN=1 only if you mean to replace it."
        % (action, run_id)
    )


def require_locked_delay_structure(values: dict[str, str], *, label: str) -> None:
    buf_count = int(values.get("RCU_MATCHED_BUF_COUNT", "-1"))
    buf_stages = int(values.get("RCU_MATCHED_BUF_STAGES", "-1"))
    rcu_unit = int(values.get("RCU_MATCHED_DELAY_UNIT_PS", "-1"))
    rcu_steps = int(values.get("RCU_MATCHED_DELAY_STEPS", "-1"))
    ackin_unit = int(values.get("OPM_ACKIN_DELAY_UNIT_PS", "-1"))
    ackin_steps = int(values.get("OPM_ACKIN_DELAY_STEPS", "-1"))
    ackin_buf = values.get("OPM_ACKIN_USE_BUF", "0").strip() in ("1", "true", "True")
    if (
        buf_count != LOCKED_BUF_STAGES
        or buf_stages != LOCKED_BUF_STAGES
        or rcu_unit != LOCKED_RCU_UNIT_PS
        or rcu_steps != LOCKED_RCU_STEPS
        or ackin_unit != LOCKED_ACKIN_UNIT_PS
        or ackin_steps != LOCKED_ACKIN_STEPS
        or ackin_buf != LOCKED_ACKIN_USE_BUF
    ):
        raise RuntimeError(
            "%s delay recipe mismatch: buf=%s/%s rcu=%sx%s ackin=%sx%s use_buf=%s; "
            "locked is RCU 1xDEL050, buf=0, Ackin 1xDEL050, no DontTouchBuf"
            % (label, buf_count, buf_stages, rcu_steps, rcu_unit, ackin_steps, ackin_unit, ackin_buf)
        )


def require_emit_locked_delays(text: str, *, label: str, ackin_unit_ps: int) -> None:
    params = "#(.DelayUnitPs(%d), .DelayValue(%d))" % (
        LOCKED_RCU_UNIT_PS,
        LOCKED_RCU_STEPS,
    )
    matched_ok = (
        ("DelayElement %s MatchedDelay" % params) in text
        or ("DelayElement %s BundlingSignal_MatchedDelay" % params) in text
    )
    ackin = "DelayElement #(.DelayUnitPs(%d), .DelayValue(%d)) AckinDelay" % (
        ackin_unit_ps,
        LOCKED_ACKIN_STEPS,
    )
    if not matched_ok:
        raise SystemExit("%s MatchedDelay is not RCU 1x%sps" % (label, LOCKED_RCU_UNIT_PS))
    if ackin not in text:
        raise SystemExit("%s AckinDelay is not 1x%sps" % (label, ackin_unit_ps))
    if ackin_unit_ps != LOCKED_ACKIN_UNIT_PS:
        print(
            "WARN %s AckinDelay is 1x%sps; Fat vs Thin hop delay lock is 1x%d. "
            "Do not cite this netlist as the paper delay comparison."
            % (label, ackin_unit_ps, LOCKED_ACKIN_UNIT_PS),
            flush=True,
        )
