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
        "20260831_cmr_flatmesh_c1p1_del050_ackin050",
        "20260831_cmr_topmesh_c2p2_del050_ackin050",
        "20260831_cmr_pfat_l2_c2p4_del050_ackin050",
        "20260831_cmr_pfat_l3_c4p8_del050_ackin050",
    }
)
FROZEN_HOP_PPA_RUN_ID = "20260830_cmr_router_level_baseline_del050"
FROZEN_PRIMITIVE_HOP_PPA_RUN_ID = "20260901_cmr_primitive_hop_ppa_ru5"
ARCHIVE_PRIMITIVE_HOP_PPA_RUN_ID = "20260831_cmr_primitive_hop_ppa_ru5"
FROZEN_THIN_NOC16_RUN_ID = "20260828_cmr_cfifo_tp_nogrant_p50"
FROZEN_NOC64_ACKIN250_RUN_ID = "20260830_095259_cmr_noc64_p50_1222"
FROZEN_SYNC64_CLOCK_NS = 1.0
FROZEN_SYNC64_THIN_RUN_ID = "20260901_cmr_sync_noc64_thin_p50"
FROZEN_SYNC64_FAT1222_RUN_ID = "20260901_cmr_sync_noc64_fat1222_p50"
FROZEN_SYNC_THIN_HOP_RUN_ID = "20260901_cmr_sync_thin_1x1_1p0ns"
FROZEN_SYNC_PROP_HOP_RUN_ID = "20260901_cmr_sync_prop_2x2_1p0ns"
ARCHIVE_SYNC64_THIN_RUN_ID = "20260831_014622_cmr_sync_noc64_thin_p50"
ARCHIVE_SYNC64_FAT1222_RUN_ID = "20260831_084457_cmr_sync_noc64_fat1222_p50"
ARCHIVE_SYNC_THIN_HOP_RUN_ID = "20260831_cmr_sync_thin_1x1_1p0ns"
ARCHIVE_SYNC_PROP_HOP_RUN_ID = "20260831_cmr_sync_prop_2x2_1p0ns"

# Read-only candidate: TAB 3-flit already unexpected.  GLS may SKIP_DC this
# netlist; never use the id as a new DC/GLS RUN_ID.
FROZEN_MESH64_CANDIDATE_RUN_ID = "20260831_115856_cmr_mesh64_p50"
FROZEN_READONLY_NETLIST_RUN_IDS = frozenset({FROZEN_MESH64_CANDIDATE_RUN_ID})

# Official PROP64 paper netlist: RCU 1xDEL050, Ackin 1xDEL050, OtherPath
# 1xDEL050, bypass inter-level FIFO, lane01=0.  SKIP_DC this id; never
# re-run DC under the same stamp.
FROZEN_PROP64_PAPER_NETLIST_RUN_ID = "20260912_172443_cmr_prop64_rpsdel050_1222"

# Paper ASAP Mesh64 network netlist (Mesh RCU 1xDEL150). SKIP_DC.
FROZEN_MESH64_PAPER_NETLIST_RUN_ID = "20260913_104506_cmr_fm64_rpsdel150"

# PROP_temp64 (B8) experimental network netlist (tree RCU 1xDEL050,
# mesh RCU env DEL150 unused on this DUT, Ackin 1xDEL050). SKIP_DC.
FROZEN_PROP_TEMP64_NETLIST_RUN_ID = "20260913_prop_temp64_asap_uc_m5_200"

# PROP_temp256 B8 paper netlist (4x PROP_temp64 tile + 8 Mesh planes;
# hier DC 20260914_prop_temp256_b8_hier_dc_06). SKIP_DC; never overwrite.
FROZEN_PROP_TEMP256_NETLIST_RUN_ID = "20260914_prop_temp256_b8_hier_dc_06"

# PFAT_temp256 paper baseline (4x PFAT64 1248 tiles + 4 Mesh(1,2);
# hier DC 20260915_122347, restitched with expected_ports=768). SKIP_DC.
FROZEN_PFAT_TEMP256_NETLIST_RUN_ID = "20260915_122347_cmr_pfat_temp256_hier_dc"

# FlatMesh256 paper baseline (hier DC 20260915_122347). SKIP_DC.
FROZEN_FM256_NETLIST_RUN_ID = "20260915_122347_cmr_mesh256_hier_dc"

FROZEN_WRITE_RUN_IDS = FROZEN_HOP_NETLIST_RUN_IDS | {
    "20260912_205700_cmr_thin_l1_hop_rpsdel050",
    "20260912_205700_cmr_flatmesh_c1p1_rpsdel050",
    "20260912_205700_cmr_fat_l1_hop_rpsdel050",
    "20260912_205700_cmr_prop_2x2_hop_rpsdel050",
    "20260912_205700_cmr_topmesh_c2p2_rpsdel050",
    "20260912_205700_cmr_pfat_l2_c2p4_rpsdel050",
    "20260912_205700_cmr_pfat_l3_c4p8_rpsdel050",
    "20260901_cmr_sync_thin_1x1_1p0ns",
    "20260901_cmr_sync_prop_2x2_1p0ns",
    "20260912_205700_cmr_primitive_hop_ppa_rpsdel050",

    FROZEN_HOP_PPA_RUN_ID,
    FROZEN_PRIMITIVE_HOP_PPA_RUN_ID,
    ARCHIVE_PRIMITIVE_HOP_PPA_RUN_ID,
    FROZEN_THIN_NOC16_RUN_ID,
    FROZEN_NOC64_ACKIN250_RUN_ID,
    FROZEN_SYNC64_THIN_RUN_ID,
    FROZEN_SYNC64_FAT1222_RUN_ID,
    FROZEN_SYNC_THIN_HOP_RUN_ID,
    FROZEN_SYNC_PROP_HOP_RUN_ID,
    ARCHIVE_SYNC64_THIN_RUN_ID,
    ARCHIVE_SYNC64_FAT1222_RUN_ID,
    ARCHIVE_SYNC_THIN_HOP_RUN_ID,
    ARCHIVE_SYNC_PROP_HOP_RUN_ID,
    FROZEN_PROP64_PAPER_NETLIST_RUN_ID,
    FROZEN_MESH64_PAPER_NETLIST_RUN_ID,
    FROZEN_PROP_TEMP64_NETLIST_RUN_ID,
    FROZEN_PROP_TEMP256_NETLIST_RUN_ID,
    FROZEN_PFAT_TEMP256_NETLIST_RUN_ID,
    FROZEN_FM256_NETLIST_RUN_ID,
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
    ARCHIVE_SYNC64_THIN_RUN_ID: (
        "Phase 2 archive: 2-cycle Head Thin SyncNoC64 1.0 ns. Not paper. "
        "Not async hop delay."
    ),
    ARCHIVE_SYNC64_FAT1222_RUN_ID: (
        "Phase 2 archive: 3-cycle Head path Fat 1-2-2-2 SyncNoC64 1.0 ns. "
        "Not paper. Not async hop delay."
    ),
    FROZEN_SYNC64_THIN_RUN_ID: (
        "Phase 2.5 1-cycle Head Thin SyncNoC64, 1.0 ns SS ZeroWireload. "
        "Not async hop delay."
    ),
    FROZEN_SYNC64_FAT1222_RUN_ID: (
        "Phase 2.5 1-cycle Head Fat 1-2-2-2 SyncNoC64, 1.0 ns SS ZeroWireload. "
        "Limiter vs Thin; not async hop delay."
    ),
}


def refuse_overwrite(run_id: str, *, action: str = "write") -> None:
    if not run_id:
        return
    if run_id in FROZEN_READONLY_NETLIST_RUN_IDS:
        if os.environ.get("CMR_FORCE_OVERWRITE_FROZEN", "0") == "1":
            print("FROZEN_OVERWRITE_FORCED", action, run_id, flush=True)
            return
        raise SystemExit(
            "refusing to %s read-only mesh64 candidate %s (TAB 3-flit already "
            "unexpected). SKIP_DC that netlist; new DC must use a cmr_descal_ id."
            % (action, run_id)
        )
    if run_id not in FROZEN_WRITE_RUN_IDS:
        return
    if os.environ.get("CMR_FORCE_OVERWRITE_FROZEN", "0") == "1":
        print("FROZEN_OVERWRITE_FORCED", action, run_id, flush=True)
        return
    raise SystemExit(
        "refusing to %s frozen run_id %s (RCU 1xDEL050 / buf=0 / Ackin 1xDEL050 "
        "hop lock, Thin CURRENT, NoC64 Ackin-250 predecessor, Phase 2 archive "
        "Sync 2/3-cycle Head, Phase 2.5 signed Sync 1-cycle Head 1.0 ns, or "
        "official PROP64 paper netlist 20260912_172443, Mesh64 paper "
        "20260913_104506, PROP_temp64 20260913_prop_temp64, or "
        "PROP_temp256 20260914_prop_temp256_b8_hier_dc_06). "
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


def require_emit_locked_delays(
    text: str, *, label: str, ackin_unit_ps: int, rcu_unit_ps: int = LOCKED_RCU_UNIT_PS
) -> None:
    params = "#(.DelayUnitPs(%d), .DelayValue(%d))" % (
        rcu_unit_ps,
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
        raise SystemExit("%s MatchedDelay is not RCU 1x%sps" % (label, rcu_unit_ps))
    if ackin not in text:
        raise SystemExit("%s AckinDelay is not 1x%sps" % (label, ackin_unit_ps))
    if ackin_unit_ps != LOCKED_ACKIN_UNIT_PS:
        print(
            "WARN %s AckinDelay is 1x%sps; Fat vs Thin hop delay lock is 1x%d. "
            "Do not cite this netlist as the paper delay comparison."
            % (label, ackin_unit_ps, LOCKED_ACKIN_UNIT_PS),
            flush=True,
        )
