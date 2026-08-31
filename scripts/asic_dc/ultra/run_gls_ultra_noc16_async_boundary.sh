#!/bin/bash
# Strict NoC16 + structural endpoint SDF simulation from one physical top.
set -euo pipefail
ROOT=${ULTRA_REMOTE_ROOT:?}; RUN_ID=${ULTRA_NOC16_RUN_ID:?}
CASE_NAME=${ULTRA_NOC16_CASE_NAME:?}; CASE_FILE=${ULTRA_NOC16_CASE_FILE:?}
OUT="$ROOT/outputs/$RUN_ID"; LOG="$ROOT/logs/gls/$RUN_ID/async_sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/async_sdf/$CASE_NAME"
rm -rf -- "$WORK"; mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/async_csv"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}; export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin
  \$sdf_annotate("$OUT/boundary/AsyncNoC16BoundaryDUT.sdf", tb_noc16_async_boundary_structural.core.g_structural_endpoints.fabric, , "boundary_sdf_annotate.log", "MAXIMUM", ,);
end endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$OUT/boundary/AsyncNoC16BoundaryDUT_post.v
$ROOT/sim/tb/tb_noc16_async_boundary.sv
$WORK/sdf_boot.sv
EOF
cd "$WORK"
TRACE_DEFINE=""
if [[ "${ULTRA_NOC16_CORE0_TO15_TRACE:-0}" == "1" ]]; then
  TRACE_DEFINE="+define+ASYNC_NOC16_CORE0_TO15_TRACE"
fi
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier $TRACE_DEFINE -f filelist.f \
  -top tb_noc16_async_boundary_structural -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
declare -a TRACE_ARGS=()
if [[ "${ULTRA_NOC16_CORE0_TO15_TRACE:-0}" == "1" ]]; then
  TRACE_ARGS=(+CORE0_TO15_TRACE "+CORE0_TO15_TRACE_FILE=$LOG/core0_to_core15.trace" "+CORE0_TO15_TRACE_VCD=$LOG/core0_to_core15.vcd")
fi
./simv +CASE_FILE="$CASE_FILE" \
  +RESULT_CSV="$ROOT/results/$RUN_ID/async_csv/$CASE_NAME.csv" \
  +EVENT_CSV="$ROOT/results/$RUN_ID/async_csv/$CASE_NAME.events.csv" \
  +LATENCY_CSV="$ROOT/results/$RUN_ID/async_csv/$CASE_NAME.latency.csv" \
  "${TRACE_ARGS[@]:-}" \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp boundary_sdf_annotate.log "$LOG" 2>/dev/null || true
if grep -q "Override previous declaration" "$LOG/compile.log"; then
  echo "TB_PLATFORM_FAIL duplicate_module_override" | tee -a "$LOG/run.log"
  exit 3
fi
exit "$rc"
