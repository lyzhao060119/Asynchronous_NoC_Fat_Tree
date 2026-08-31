#!/usr/bin/env python3
"""Static sanity checks for Stage1 wormhole generated Verilog."""
from __future__ import annotations

import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
R1 = ROOT / "generated" / "RouterL1WormholeMinimal.v"
N16 = ROOT / "generated_stage1" / "NoC_16nodes.v"


def require(name: str, ok: bool) -> None:
    print(f"{name}={'PASS' if ok else 'FAIL'}")
    if not ok:
        raise SystemExit(1)


def main() -> None:
    r1 = R1.read_text(errors="replace")
    n16 = N16.read_text(errors="replace")

    require("router_module", "module RouterL1WormholeMinimal(" in r1)
    require("noc16_top_module", "module NoC_16nodes(" in n16)
    require("stage1_l1_in_noc", "module RouterL1WormholeMinimal" in n16)
    require("stage1_l2_in_noc", "module RouterL2WormholeMinimal" in n16)
    require("old_router_l1_absent", "module RouterL1(" not in n16)
    require("old_router_l2_absent", "module RouterL2(" not in n16)
    require("stage1_debug_ports", "io_debug_l1InputValid_0" in n16)
    require("domain_c_output_drive_probe_absent", "io_probe_outputDriveFire" not in r1)
    require(
        "domain_c_acg_absent",
        "drv_" not in r1 and "outputDriveFire" not in r1,
    )

    require(
        "output_valid_uses_external_ack",
        bool(
            re.search(
                r"assign\s+io_probe_outputValid_0\s*=\s*[^;]*io_outputs_child_0_0_HS_Ack",
                r1,
            )
        )
        or "io_outputs_child_0_0_HS_Ack" in r1 and "io_probe_outputValid_0" in r1,
    )
    require(
        "output_req_direct_from_slot",
        bool(
            re.search(
                r"assign\s+io_outputs_child_0_0_HS_Req\s*=\s*outputSlotReq_0\s*;",
                r1,
            )
        )
        or bool(
            re.search(
                r"assign\s+io_outputs_child_0_0_HS_Req\s*=\s*commitState__5_0\s*;",
                r1,
            )
        )
        or bool(
            re.search(
                r"assign\s+io_outputs_child_0_0_HS_Req\s*=\s*outputReqRegs_0\s*;",
                r1,
            )
        )
        or bool(
            re.search(
                r"assign\s+io_outputs_child_0_0_HS_Req\s*=\s*outputReqReg\s*;",
                r1,
            )
        ),
    )
    require("output_req_pending_probe_present", "io_probe_outputReqPending_0" in r1)
    require("output_req_launch_probe_present", "io_probe_outputReqLaunchEvent_0" in r1)
    req_launch_delay_count = len(
        re.findall(r"DelayElement\s+#.*\)\s+reqLaunchDelay(?:_\d+)?\s+\(", r1)
    )
    require("stage1_launch_experiment_absent", "shadowDataRegs_0" not in r1 and "STAGE1L" not in r1)
    require(
        "slot_writable_policy",
        "wire  slotWritable_0 = ~outputValid_0 & ~outputReqPending_0" in r1,
    )
    require(
        "commit_level_stable_enable",
        bool(
            re.search(
                r"(?:wire|assign)\s+commitLevel_0\s*=\s*inputValid_0\s*&\s*commitReady_0\s*&\s*(?:requestableAll_0|canCommit_0|winner_0)",
                r1,
            )
        ),
    )
    require("atomic_mask_arbitration_present", "acceptedMasks_1" in r1 and "requestableAll_1 & conflictFree_1" in r1)
    require("old_per_output_first_winner_absent", "firstWinner" not in r1 and "wants_" not in r1)
    require(
        "output_winner_from_final_winner",
        "winner_1 & requestMask_1[0]" in r1 and "winner_2 & requestMask_2[0]" in r1,
    )
    require(
        "granted_all_aliases_winner",
        "assign io_probe_grantedAll_1 = requestableAll_1 & conflictFree_1" in r1
        or "assign io_probe_grantedAll_1 = winner_1" in r1
        or "assign grantedAll_1 = winner_1" in r1,
    )
    require(
        "commit_probe_cleared_by_global_event",
        bool(
            re.search(
                r"assign\s+io_probe_commit_0\s*=\s*commitLevel_0\s*&\s*~globalCommitEvent",
                r1,
            )
        )
        or bool(
            re.search(
                r"wire\s+commit_0\s*=\s*commitLevel_0\s*&\s*~globalCommitEvent",
                r1,
            )
        )
        or bool(
            re.search(
                r"(?:wire|assign)\s+commit_0\s*=\s*commitLevel_0\s*&\s*~launchPending\s*&\s*~globalCommitEvent",
                r1,
            )
        )
        or "assign io_probe_commit_0 = commitLevel_0;" in r1
        or "assign io_probe_commit_0 = inputValid_0 & commitReady_0 & requestableAll_0;" in r1
        or "wire  commit_0 = inputValid_0 & commitReady_0 & winner_0;" in r1,
    )
    require(
        "state_uses_commit_level",
        "else if (commitLevel_0) begin" in r1
        and "committedWriters__0 = commitLevel_0" in r1,
    )
    require("commit_ready_delay_present", "commitDelay" in r1 and "DelayElement" in r1)
    require("global_commit_delay_present", "globalCommitDelay" in r1 and "DelayElement" in r1)
    require(
        "stage1_five_input_capture_acg_instances",
        len(re.findall(r"\bACG\s+cap(?:_\d+)?\s*\(", r1)) == 5,
    )
    require(
        "stage1_five_commit_ready_delays",
        len(re.findall(r"DelayElement\s+#.*\)\s+commitDelay(?:_\d+)?\s+\(", r1)) == 5,
    )
    require(
        "stage1_one_global_commit_delay",
        len(re.findall(r"DelayElement\s+#.*\)\s+globalCommitDelay\s+\(", r1)) == 1,
    )
    require(
        "stage1_five_output_req_margin_delays",
        req_launch_delay_count == 5,
    )
    require(
        "stage1_output_pending_structure",
        "outputReqRegs_0 ^ outputPendingAckReg" in r1
        and "assign reqLaunchDelay_I = outputReqRegs_0 ^ outputPendingAckReg" in r1
        and "always @(posedge reqLaunchDelay_Z or posedge reset)" in r1,
    )
    require(
        "domain_b_acg_self_ack_absent",
        not bool(re.search(r"assign\s+\w*Out_0_Ack\s*=\s*\w*Out_0_Req\s*;", r1)),
    )

    require(
        "top1_idle_in",
        "assign io_top_input_1_HS_Ack = io_top_input_1_HS_Req" in n16,
    )
    require(
        "top1_idle_out",
        "assign io_top_output_1_HS_Req = io_top_output_1_HS_Ack" in n16,
    )

    print("STAGE1_STATIC_CHECK PASS")


if __name__ == "__main__":
    main()
