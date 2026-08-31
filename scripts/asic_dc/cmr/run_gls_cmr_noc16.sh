#!/bin/bash
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NOC16_RUN_ID:?}
CASE_NAME=${CMR_NOC16_CASE_NAME:?}
CASE_FILE=${CMR_NOC16_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_NOC16_NETLIST_RUN_ID:-$RUN_ID}
EXTRA_SIM_ARGS=${CMR_NOC16_SIM_ARGS:-}
INJECT_MAX_RATE=${CMR_NOC16_INJECT_MAX_RATE:-0}
RX_CAPTURE_NS=${CMR_NOC16_RX_CAPTURE_NS:-0.09}
STALL_TIMEOUT_NS=${CMR_NOC16_STALL_TIMEOUT_NS:-50000}
HARD_TIMEOUT_NS=${CMR_NOC16_HARD_TIMEOUT_NS:-400000}
PHASE_PROBE=${CMR_NOC16_PHASE_PROBE:-0}
UNEXPECTED_PROBE=${CMR_NOC16_UNEXPECTED_PROBE:-0}
HOP_PROBE=${CMR_NOC16_HOP_PROBE:-0}
L2_IPM1_PROBE=${CMR_NOC16_L2_IPM1_PROBE:-0}
L2_OPMSEL_PROBE=${CMR_NOC16_L2_OPMSEL_PROBE:-0}
UPFIFO_PROBE=${CMR_NOC16_UPFIFO_PROBE:-0}
L1P1_PROBE=${CMR_NOC16_L1P1_PROBE:-0}
L1ADAPT_PROBE=${CMR_NOC16_L1ADAPT_PROBE:-0}
MISROUTE_PROBE=${CMR_NOC16_MISROUTE_PROBE:-0}
THIN_STALL_PROBE=${CMR_NOC16_THIN_STALL_PROBE:-0}
FUNCTIONAL_STALL_PROBE=${CMR_NOC16_FUNCTIONAL_STALL_PROBE:-0}
IPM1_ACK_PROBE=${CMR_NOC16_IPM1_ACK_PROBE:-0}
IPM3_ACK_PROBE=${CMR_NOC16_IPM3_ACK_PROBE:-0}
PHASE_SELECTOR_PROBE=${CMR_NOC16_PHASE_SELECTOR_PROBE:-0}
PORT10_X_PROBE=${CMR_NOC16_PORT10_X_PROBE:-0}
ACG_X_PROBE=${CMR_NOC16_ACG_X_PROBE:-0}
NOFIFO_STALL_PROBE=${CMR_NOC16_NOFIFO_STALL_PROBE:-0}
P30_PORT5_PROBE=${CMR_NOC16_P30_PORT5_PROBE:-0}
VCTM_TAIL_PROBE=${CMR_NOC16_VCTM_TAIL_PROBE:-0}
VCTM_TAIL_TRACE=${CMR_NOC16_VCTM_TAIL_TRACE:-0}
VCTM_WP07_PROBE=${CMR_NOC16_VCTM_WP07_PROBE:-0}
ROUTESELAND_X_PROBE=${CMR_NOC16_ROUTESELAND_X_PROBE:-0}
ROUTESELAND_X_FULL=${CMR_NOC16_ROUTESELAND_X_FULL:-0}
L2AX_PROBE=${CMR_NOC16_L2AX_PROBE:-0}
CFIFO05_PROBE=${CMR_NOC16_CFIFO05_PROBE:-0}
CFIFO06_PROBE=${CMR_NOC16_CFIFO06_PROBE:-0}
STRUCTURAL_ENDPOINTS=${CMR_NOC16_STRUCTURAL_ENDPOINTS:-0}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/NoC_16nodes_post.v"
SDF="$OUT/NoC_16nodes.sdf"
CSV="$ROOT/results/$RUN_ID/csv/$CASE_NAME.csv"
test -s "$CASE_FILE"
test -s "$NETLIST"
test -s "$SDF"

sha256sum "$CASE_FILE" "$NETLIST" "$SDF" \
  "$ROOT/sim/tb/async_noc16_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc16_async_boundary.sv" \
  "$ROOT/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv" | tee "$LOG/input_hashes.log"

SDF_SCOPE="tb_cmr_noc16_async_boundary_failfast.core.g_behavioral_noc.noc.dut"
STRUCTURAL_DEFINE=""
if [[ "$STRUCTURAL_ENDPOINTS" == "1" ]]; then
  for source in \
    async_endpoint_source_turnaround_delay.sv async_endpoint_ack_delay.sv \
    async_endpoint_bank20.sv async_noc16_boundary_dut.sv MousetrapStage.v \
    DLatchBank.v; do
    test -s "$ROOT/sim/tb/$source"
    echo "$ROOT/sim/tb/$source" >> "$WORK/structural_filelist.f"
    sha256sum "$ROOT/sim/tb/$source" >> "$LOG/input_hashes.log"
  done
  SDF_SCOPE="tb_cmr_noc16_async_boundary_failfast.core.g_structural_endpoints.fabric.noc.dut"
  STRUCTURAL_DEFINE="+define+CMR_STRUCTURAL_ENDPOINTS"
elif [[ "$STRUCTURAL_ENDPOINTS" != "0" ]]; then
  echo "CMR_GLS_FAIL invalid STRUCTURAL_ENDPOINTS=$STRUCTURAL_ENDPOINTS" >&2
  exit 2
fi

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $SDF_SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $SDF");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$ROOT/sim/tb/async_noc16_port_adapter.sv
$ROOT/sim/tb/tb_noc16_async_boundary.sv
$ROOT/sim/tb/tb_cmr_noc16_async_boundary_failfast.sv
$WORK/sdf_boot.sv
EOF
if [[ "$STRUCTURAL_ENDPOINTS" == "1" ]]; then
  cat "$WORK/structural_filelist.f" >> "$WORK/filelist.f"
fi
PROBE_TOP=""
if [[ "$PHASE_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_phase_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_phase_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_phase_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_phase_probe"
fi
if [[ "$UNEXPECTED_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_unexpected_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_unexpected_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_unexpected_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_unexpected_probe"
fi
if [[ "$HOP_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_800800b_hop_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_800800b_hop_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_800800b_hop_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_800800b_hop_probe"
fi
if [[ "$L2_IPM1_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_800800b_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_l2_ipm1_800800b_probe"
fi
if [[ "$L2_OPMSEL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_l2_opmsel_800800b_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_l2_opmsel_800800b_probe"
fi
if [[ "$UPFIFO_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_l2_ipm1_upfifo_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_l2_ipm1_upfifo_probe"
fi
if [[ "$L1P1_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_l1_11_parent1_opm_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_l1_11_parent1_opm_probe"
fi
if [[ "$L1ADAPT_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_l1_ipm1_adapter_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_l1_ipm1_adapter_probe"
fi
if [[ "$MISROUTE_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_fat_tree_8004004_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_fat_tree_8004004_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_fat_tree_8004004_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_fat_tree_8004004_probe"
fi
if [[ "$THIN_STALL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_core8_stall_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_core8_stall_probe"
fi
if [[ "$FUNCTIONAL_STALL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_functional_stall_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_functional_stall_probe"
fi
if [[ "$IPM1_ACK_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_ipm1_ack_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_ipm1_ack_probe"
fi
if [[ "$IPM3_ACK_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_ipm3_ack_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_ipm3_ack_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_ipm3_ack_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_ipm3_ack_probe"
fi
if [[ "$PHASE_SELECTOR_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_phase_selector_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_phase_selector_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_phase_selector_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_phase_selector_probe"
fi
if [[ "$PORT10_X_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_port10_x_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_port10_x_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_port10_x_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_port10_x_probe"
fi
if [[ "$ACG_X_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_acg_deq_x_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_acg_deq_x_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_acg_deq_x_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_acg_deq_x_probe"
fi
if [[ "$NOFIFO_STALL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_thin_nofifo_stall_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_thin_nofifo_stall_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_thin_nofifo_stall_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_thin_nofifo_stall_probe"
fi
if [[ "$P30_PORT5_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_p30_port5_x_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_p30_port5_x_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_p30_port5_x_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_p30_port5_x_probe"
fi
if [[ "$VCTM_TAIL_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_vctm_tail_stall_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_vctm_tail_stall_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_vctm_tail_stall_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_vctm_tail_stall_probe"
fi
if [[ "$VCTM_TAIL_TRACE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_vctm_tail_release_trace.sv"
  echo "$ROOT/sim/tb/tb_cmr_vctm_tail_release_trace.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_vctm_tail_release_trace.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_vctm_tail_release_trace"
fi
if [[ "$VCTM_WP07_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_vctm_wp07_mat_routesel.sv"
  echo "$ROOT/sim/tb/tb_cmr_vctm_wp07_mat_routesel.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_vctm_wp07_mat_routesel.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_vctm_wp07_mat_routesel"
fi
if [[ "$ROUTESELAND_X_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_routeseland_first_x.sv"
  echo "$ROOT/sim/tb/tb_cmr_routeseland_first_x.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_routeseland_first_x.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_routeseland_first_x"
  if [[ "$ROUTESELAND_X_FULL" == "1" ]]; then
    STRUCTURAL_DEFINE="$STRUCTURAL_DEFINE +define+CMR_ROUTESELAND_FULL"
  fi
fi
if [[ "$L2AX_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_l2_opm1_reqin3_first_x.sv"
  echo "$ROOT/sim/tb/tb_cmr_l2_opm1_reqin3_first_x.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_l2_opm1_reqin3_first_x.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_l2_opm1_reqin3_first_x"
fi
if [[ "$CFIFO05_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_cfifo05_zero_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_cfifo05_zero_probe.sv" >> "$WORK/filelist.f"
  sha256sum "$ROOT/sim/tb/tb_cmr_cfifo05_zero_probe.sv" >> "$LOG/input_hashes.log"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_cfifo05_zero_probe"
fi
if [[ "$CFIFO06_PROBE" == "1" ]]; then
  test -s "$ROOT/sim/tb/tb_cmr_cfifo06_internal_probe.sv"
  echo "$ROOT/sim/tb/tb_cmr_cfifo06_internal_probe.sv" >> "$WORK/filelist.f"
  PROBE_TOP="$PROBE_TOP -top tb_cmr_cfifo06_internal_probe"
fi

cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk $STRUCTURAL_DEFINE -f filelist.f \
  -top tb_cmr_noc16_async_boundary_failfast -top sdf_boot $PROBE_TOP \
  -o simv -l "$LOG/compile.log"
set +e
INJECT_ARG=""
if [[ "$INJECT_MAX_RATE" == "1" ]]; then
  INJECT_ARG="+INJECT_MAX_RATE"
elif [[ "$INJECT_MAX_RATE" != "0" ]]; then
  echo "CMR_GLS_FAIL invalid INJECT_MAX_RATE=$INJECT_MAX_RATE" >&2
  exit 2
fi
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  $INJECT_ARG $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"
