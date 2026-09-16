#!/bin/bash
set -euo pipefail
STAGE=${1:?compile or run}
DESIGN=${2:?Dynamic4 or Static4}
ROOT=${DIR_SKEW_REMOTE_ROOT:?}
ARCHIVE=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
RUN_ID=${DIR_SKEW_RUN_ID:?}
COMPILE="$ROOT/work/$DESIGN"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
case "$DESIGN" in
  Dynamic4)
    NETLIST_RUN=20260913_prop_temp64_asap_uc_m5_200
    PREFIX=PROP_temp64
    DEFINE='+define+PROP_TEMP64_TOP16'
    ;;
  Static4)
    NETLIST_RUN=20260915_144500_prop_temp64_static4_dc
    PREFIX=PROP_temp64_static4
    DEFINE='+define+PROP_TEMP64_TOP16 +define+PROP_TEMP64_STATIC4'
    ;;
  *) echo "DIR_SKEW_FAIL unknown design=$DESIGN"; exit 2 ;;
esac
RAW="$ARCHIVE/outputs/$NETLIST_RUN/${PREFIX}_post.v"
SDF="$ARCHIVE/outputs/$NETLIST_RUN/${PREFIX}.sdf"
TB="$ROOT/src/tb_noc64_async_boundary.sv"
FAILFAST="$ROOT/src/tb_cmr_noc64_async_boundary_failfast.sv"
ADAPTER="$ROOT/src/async_prop_temp64_port_adapter.sv"
MONITOR="$ROOT/src/tb_prop_temp64_lane_monitor.sv"
SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp.noc.dut'
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

if [[ "$STAGE" == compile ]]; then
  mkdir -p "$COMPILE"
  for f in "$RAW" "$SDF" "$LIB" "$TB" "$FAILFAST" "$ADAPTER" "$MONITOR"; do test -s "$f"; done
  cat > "$COMPILE/sdf_boot.sv" <<EOF
module sdf_boot;
 initial begin
  \$sdf_annotate("$SDF", $SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
  \$display("TB_INFO DIR-SKEW1 $DESIGN MAXIMUM SDF annotation");
 end
endmodule
EOF
  printf '%s\n' "$LIB" "$RAW" "$ADAPTER" "$TB" "$FAILFAST" "$MONITOR" "$COMPILE/sdf_boot.sv" > "$COMPILE/filelist.f"
  sha256sum "$RAW" "$SDF" "$LIB" "$ADAPTER" "$TB" "$FAILFAST" "$MONITOR" | tee "$COMPILE/input_hashes.log"
  cd "$COMPILE"
  vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk $DEFINE -f filelist.f \
    -top tb_cmr_noc64_async_boundary_failfast -top sdf_boot \
    -top tb_prop_temp64_lane_monitor -o simv -l compile.log
  test -x simv
  grep -Eq 'Total errors:[[:space:]]*0' sdf_annotate.log
  echo "DIR_SKEW_COMPILE_PASS design=$DESIGN run=$RUN_ID"
  exit 0
fi

[[ "$STAGE" == run ]]
CASE_FILE=${DIR_SKEW_CASE_FILE:?}
CASE_NAME=${DIR_SKEW_CASE_NAME:?}
LOG="$ROOT/logs/$DESIGN/$CASE_NAME"
CSV="$ROOT/results/$DESIGN/$CASE_NAME.csv"
mkdir -p "$LOG" "$(dirname "$CSV")"
test -x "$COMPILE/simv" && test -s "$CASE_FILE"
cd "$LOG"
echo "DIR_SKEW_CASE_RUN design=$DESIGN case=$CASE_NAME job=${LSB_JOBID:-none}" | tee stage.log
sha256sum "$CASE_FILE" "$RAW" "$SDF" | tee input_hashes.log
set +e
"$COMPILE/simv" +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
 +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
 +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" +MISSING_CSV="$LOG/missing_expected.csv" \
 +V3_METRICS_CSV="$LOG/v3_metrics.csv" +LANE_CSV="$LOG/lane_counts.csv" \
 +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +STALL_TIMEOUT_NS=100000 +HARD_TIMEOUT_NS=1000000 \
 -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
test "$rc" -eq 0
grep -Eq 'Total errors:[[:space:]]*0' "$COMPILE/sdf_annotate.log"
grep -Eq 'Doing SDF annotation .* Done' "$LOG/run.log"
grep -Eq 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' "$LOG/run.log"
grep -Eq 'CMR_LANE_MONITOR_PASS rows=128' "$LOG/run.log"
test -s "$CSV" && test -s "$LOG/events.csv" && test -s "$LOG/latency.csv" && test -s "$LOG/flit_latency.csv"
test "$(wc -l < "$LOG/lane_counts.csv")" -eq 129
! grep -Eiq 'Timing violation|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:' "$LOG/run.log" "$LOG/stdout.log"
sha256sum "$COMPILE/sdf_annotate.log" > "$LOG/sdf_reference.sha256"
echo "DIR_SKEW_CASE_PASS design=$DESIGN case=$CASE_NAME rc=$rc" | tee -a stage.log
