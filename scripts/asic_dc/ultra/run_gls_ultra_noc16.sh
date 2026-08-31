#!/bin/bash
# Strict SDF GLS for NoC16.  The AXI/BRAM wrapper and TB are the same files
# used by the local xsim runner; only the DUT implementation differs.
set -euo pipefail
ROOT=${ULTRA_REMOTE_ROOT:?}; RUN_ID=${ULTRA_NOC16_RUN_ID:?}
CASE_NAME=${ULTRA_NOC16_CASE_NAME:?}; CASE_FILE=${ULTRA_NOC16_CASE_FILE:?}
# A trace is allowed to have its own log/result namespace while consuming an
# immutable post-DC implementation from an earlier signoff run.  Normal runs
# leave this unset, so the historical one-run layout is unchanged.
NETLIST_RUN_ID=${ULTRA_NOC16_NETLIST_RUN_ID:-$RUN_ID}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
rm -rf -- "$WORK"; mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}; export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/NoC_16nodes_post.v"
CSV="$ROOT/results/$RUN_ID/csv/$CASE_NAME.csv"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin \$sdf_annotate("$OUT/NoC_16nodes.sdf", tb_noc16_async_axi_bram.dut.dut, , "sdf_annotate.log", "MAXIMUM", ,); \$display("TB_INFO SDF annotate $OUT/NoC_16nodes.sdf"); end endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$ROOT/sim/tb/async_noc16_axi_bram_wrapper.sv
$ROOT/sim/tb/tb_noc16_async_axi_bram.sv
$WORK/sdf_boot.sv
EOF
cd "$WORK"
# Keep the netlist-specific diagnostic aliases out of normal compiles.  A
# trace run explicitly enables them below, so a later DC netlist may freely
# rename its internal nodes without breaking ordinary SDF regression runs.
TRACE_DEFINES=()
if [[ "${ULTRA_NOC16_TAB_TRACE:-0}" == "1" && "$CASE_NAME" == TAB* ]]; then
  TRACE_DEFINES=(+define+ASYNC_NOC16_ULTRA_TRACE +define+ASYNC_NOC16_ULTRA_TRACE_POST)
fi
# No +nospecify and no +notimingcheck: this is the physical strict-SDF run.
vcs -full64 -sverilog -timescale=1ns/1ps +no_notifier ${TRACE_DEFINES[@]+"${TRACE_DEFINES[@]}"} -f filelist.f \
  -top tb_noc16_async_axi_bram -top sdf_boot -o simv -l "$LOG/compile.log"
TRACE_ARGS=()
if [[ "${ULTRA_NOC16_TAB_TRACE:-0}" == "1" && "$CASE_NAME" == TAB* ]]; then
  TRACE_PORT="${ULTRA_NOC16_TAB_TRACE_PORT:-6}"
  TRACE_PKT="${ULTRA_NOC16_TAB_TRACE_PKT:-89}"
  TRACE_ARGS=(+ASYNC_NOC16_EDGE_TRACE +TAB_TRACE_PORT="$TRACE_PORT" +TAB_TRACE_PKT="$TRACE_PKT" \
              +TAB_TRACE_FILE="$LOG/tab_port${TRACE_PORT}_packet${TRACE_PKT}.trace" \
              +TAB_TRACE_VCD="$LOG/tab_port${TRACE_PORT}_packet${TRACE_PKT}.vcd")
fi
set +e
./simv +CASE="$CASE_FILE" +CSV="$CSV" +NOC16_DIAG_FILE="$LOG/checker_full.log" ${TRACE_ARGS[@]+"${TRACE_ARGS[@]}"} \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"
