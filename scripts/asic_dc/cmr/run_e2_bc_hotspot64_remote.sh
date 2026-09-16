#!/bin/bash
# DATE 2027 E2: compile each frozen DUT once, then reuse simv for all cases.
set -euo pipefail

STAGE=${1:?compile or run}
DESIGN=${2:?PROP_temp64 or FM64}
ROOT=${E2_REMOTE_ROOT:?new /prjtemp run directory}
HOME_ROOT=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
RUN_ID=${E2_RUN_ID:?}
NETLIST_RUN_ID=${E2_NETLIST_RUN_ID:?}
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
COMPILE="$ROOT/work/$DESIGN"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

case "$DESIGN" in
  PROP_temp64)
    RAW="$HOME_ROOT/outputs/$NETLIST_RUN_ID/PROP_temp64_post.v"
    SDF="$HOME_ROOT/outputs/$NETLIST_RUN_ID/PROP_temp64.sdf"
    ADAPTER="$ROOT/src/async_prop_temp64_port_adapter.sv"
    DEFINE='+define+PROP_TEMP64_TOP16'
    SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp.noc.dut'
    ;;
  FM64)
    RAW="$HOME_ROOT/outputs/$NETLIST_RUN_ID/CMRMeshNoC_post.v"
    SDF="$HOME_ROOT/outputs/$NETLIST_RUN_ID/CMRMeshNoC.sdf"
    ADAPTER="$ROOT/src/async_noc64_mesh_port_adapter.sv"
    DEFINE='+define+CMR_NOC64_MESH'
    SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_mesh.noc.dut'
    ;;
  *) echo "E2_FAIL unknown design $DESIGN" >&2; exit 2 ;;
esac
TB="$ROOT/src/tb_noc64_async_boundary.sv"
FAILFAST="$ROOT/src/tb_cmr_noc64_async_boundary_failfast.sv"

if [[ "$STAGE" == compile ]]; then
  test -s "$RAW" && test -s "$SDF" && test -s "$LIB"
  test -s "$ADAPTER" && test -s "$TB" && test -s "$FAILFAST"
  mkdir -p "$COMPILE"
  cat > "$COMPILE/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO E2 $DESIGN MAXIMUM SDF annotation");
  end
endmodule
EOF
  printf '%s\n' "$LIB" "$RAW" "$ADAPTER" "$TB" "$FAILFAST" "$COMPILE/sdf_boot.sv" > "$COMPILE/filelist.f"
  sha256sum "$RAW" "$SDF" "$LIB" "$ADAPTER" "$TB" "$FAILFAST" | tee "$COMPILE/input_hashes.log"
  cd "$COMPILE"
  set +e
  vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk "$DEFINE" -f filelist.f \
    -top tb_cmr_noc64_async_boundary_failfast -top sdf_boot -o simv -l compile.log
  rc=$?
  set -e
  test -x simv || { echo "E2_COMPILE_FAIL design=$DESIGN rc=$rc"; exit 3; }
  echo "E2_COMPILE_PASS design=$DESIGN run=$RUN_ID rc=$rc"
  exit 0
fi

if [[ "$STAGE" != run ]]; then echo "E2_FAIL stage=$STAGE" >&2; exit 2; fi
CASE_FILE=${E2_CASE_FILE:?}
CASE_NAME=${E2_CASE_NAME:?}
LOG="$ROOT/logs/$DESIGN/$CASE_NAME"
CSV="$ROOT/results/$DESIGN/$CASE_NAME.csv"
test -x "$COMPILE/simv" && test -s "$CASE_FILE"
mkdir -p "$LOG" "$(dirname "$CSV")"
cd "$LOG"
echo "E2_CASE_RUN design=$DESIGN case=$CASE_NAME job=${LSB_JOBID:-none}" | tee stage.log
sha256sum "$CASE_FILE" "$RAW" "$SDF" | tee input_hashes.log
set +e
"$COMPILE/simv" +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" +MISSING_CSV="$LOG/missing_expected.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 \
  +STALL_TIMEOUT_NS=50000 +HARD_TIMEOUT_NS=400000 \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
# VCS generates a single MAXIMUM-SDF report per compiled DUT.  Its hash and
# path are recorded in every case; each simv run must additionally report that
# this case executed annotation. Never pretend this shared report is unique.
SHARED_SDF_LOG="$COMPILE/sdf_annotate.log"
test -s "$SHARED_SDF_LOG" || { echo "E2_CASE_FAIL shared SDF log absent"; exit 4; }
grep -Eq 'Total errors:[[:space:]]*0' "$SHARED_SDF_LOG" || { echo "E2_CASE_FAIL SDF"; exit 4; }
grep -Eq 'Doing SDF annotation .* Done' "$LOG/run.log" || { echo "E2_CASE_FAIL case annotation missing"; exit 4; }
sha256sum "$SHARED_SDF_LOG" > "$LOG/sdf_reference.sha256"
! grep -Eiq 'Total errors:[[:space:]]*[1-9]|Timing violation|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:' "$SHARED_SDF_LOG" "$LOG/run.log" "$LOG/stdout.log"
grep -Eq 'TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0' "$LOG/run.log" || { echo "E2_CASE_FAIL counts"; exit 5; }
test -s "$CSV"
if ! awk -F, '
  NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
  NR == 2 {
    split("injected_flits delivered_flits missing_expected_flits unexpected_flits timeout_hit warmup_original_events measurement_original_events pass_fail", names, " ")
    split("55000 55000 0 0 0 1000 10000 PASS", values, " ")
    for (i = 1; i <= 8; i++) if (!(names[i] in col) || $(col[names[i]]) != values[i]) exit 1
    next
  }
  END { if (NR != 2) exit 1 }
' "$CSV"; then
  echo "E2_CASE_FAIL CSV counts/pass marker" >&2
  exit 6
fi
echo "E2_CASE_PASS design=$DESIGN case=$CASE_NAME rc=$rc" | tee -a stage.log
exit "$rc"
