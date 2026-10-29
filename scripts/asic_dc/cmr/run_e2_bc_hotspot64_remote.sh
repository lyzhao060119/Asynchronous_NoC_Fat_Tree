#!/bin/bash
# DATE 2027 E2: compile each frozen DUT once, then reuse simv for all cases.
set -euo pipefail

STAGE=${1:?compile or run}
DESIGN=${2:?PROP_temp64, PROP_M16, FM64, or PFAT64}
ROOT=${E2_REMOTE_ROOT:?new /prjtemp run directory}
HOME_ROOT=${CMR_ARCHIVE_ROOT:-/home/ghy19/Asynchronous_Router_CMR}
RUN_ID=${E2_RUN_ID:?}
NETLIST_RUN_ID=${E2_NETLIST_RUN_ID:?}
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
WORK_KEY=${E2_WORK_KEY:-$DESIGN}
if [[ ! "$WORK_KEY" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "E2_FAIL unsafe work key $WORK_KEY" >&2; exit 2
fi
COMPILE="$ROOT/work/$WORK_KEY"

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
  PROP_M16)
    RAW="$HOME_ROOT/outputs/$NETLIST_RUN_ID/PROP_temp64_m16_post.v"
    SDF="$HOME_ROOT/outputs/$NETLIST_RUN_ID/PROP_temp64_m16.sdf"
    ADAPTER="$ROOT/src/async_prop_temp64_port_adapter.sv"
    DEFINE='+define+PROP_TEMP64_M16_TOP64'
    SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp_m16.noc.dut'
    ;;
  FM64)
    RAW="$HOME_ROOT/outputs/$NETLIST_RUN_ID/CMRMeshNoC_post.v"
    SDF="$HOME_ROOT/outputs/$NETLIST_RUN_ID/CMRMeshNoC.sdf"
    ADAPTER="$ROOT/src/async_noc64_mesh_port_adapter.sv"
    DEFINE='+define+CMR_NOC64_MESH'
    SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_mesh.noc.dut'
    ;;
  PFAT64)
    RAW="$HOME_ROOT/outputs/$NETLIST_RUN_ID/NoC_64nodes_post.v"
    SDF="$HOME_ROOT/outputs/$NETLIST_RUN_ID/NoC_64nodes.sdf"
    ADAPTER="$ROOT/src/async_noc64_port_adapter.sv"
    DEFINE=''
    SCOPE='tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc.noc.dut'
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
EVENT_CSV="$LOG/events.csv"
FLIT_CSV="$LOG/flit_latency.csv"
if [[ "${E2_COMPACT_OUTPUT:-0}" == 1 ]]; then
  EVENT_CSV=/dev/null
  FLIT_CSV=/dev/null
fi
echo "E2_CASE_RUN design=$DESIGN case=$CASE_NAME job=${LSB_JOBID:-none}" | tee stage.log
sha256sum "$CASE_FILE" "$RAW" "$SDF" | tee input_hashes.log
set +e
"$COMPILE/simv" +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$EVENT_CSV" +LATENCY_CSV="$LOG/latency.csv" \
  +FLIT_LATENCY_CSV="$FLIT_CSV" +MISSING_CSV="$LOG/missing_expected.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 \
  +STALL_TIMEOUT_NS=50000 +HARD_TIMEOUT_NS=400000 \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
# This VCS build resolves the fourth $sdf_annotate argument relative to the
# compiled simv directory. Sweeps for one DUT are therefore dependency-chained
# and never execute concurrently; copy the shared report into case evidence.
SDF_LOG="$COMPILE/sdf_annotate.log"
test -s "$SDF_LOG" || { echo "E2_CASE_FAIL SDF log absent"; exit 4; }
grep -Eq 'Total errors:[[:space:]]*0' "$SDF_LOG" || { echo "E2_CASE_FAIL SDF"; exit 4; }
grep -Eq 'Doing SDF annotation .* Done' "$LOG/run.log" || { echo "E2_CASE_FAIL case annotation missing"; exit 4; }
cp "$SDF_LOG" "$LOG/sdf_annotate.log"
sha256sum "$LOG/sdf_annotate.log" > "$LOG/sdf_reference.sha256"
! grep -Eiq 'Total errors:[[:space:]]*[1-9]|Timing violation|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:' "$SDF_LOG" "$LOG/run.log" "$LOG/stdout.log"
EXPECTED_INJECTED=${E2_EXPECTED_INJECTED:-55000}
if [[ "${E2_ALLOW_MULTICAST:-0}" == 1 ]]; then
  grep -Eq "TB_RESULT PASS injected=${EXPECTED_INJECTED} delivered=[1-9][0-9]* missing=0 unexpected=0 timeout=0" "$LOG/run.log" || { echo "E2_CASE_FAIL multicast counts"; exit 5; }
else
  grep -Eq "TB_RESULT PASS injected=${EXPECTED_INJECTED} delivered=${EXPECTED_INJECTED} missing=0 unexpected=0 timeout=0" "$LOG/run.log" || { echo "E2_CASE_FAIL counts"; exit 5; }
fi
test -s "$CSV"
if ! awk -F, '
  NR == 1 { for (i = 1; i <= NF; i++) col[$i] = i; next }
  NR == 2 {
    split("injected_flits delivered_flits missing_expected_flits unexpected_flits timeout_hit warmup_original_events measurement_original_events pass_fail", names, " ")
    split(expected " 0 0 0 1000 10000 PASS", values, " ")
    check[1]="injected_flits"; check[2]="missing_expected_flits"; check[3]="unexpected_flits"; check[4]="timeout_hit"; check[5]="warmup_original_events"; check[6]="measurement_original_events"; check[7]="pass_fail"
    for (i = 1; i <= 7; i++) if (!(check[i] in col) || $(col[check[i]]) != values[i]) exit 1
    if (!("delivered_flits" in col) || $(col["delivered_flits"]) <= 0) exit 1
    next
  }
  END { if (NR != 2) exit 1 }
' expected="$EXPECTED_INJECTED" "$CSV"; then
  echo "E2_CASE_FAIL CSV counts/pass marker" >&2
  exit 6
fi
echo "E2_CASE_PASS design=$DESIGN case=$CASE_NAME rc=$rc" | tee -a stage.log
if [[ "${E2_COMPACT_OUTPUT:-0}" == 1 ]] && [[ -s "$LOG/latency.csv" ]]; then
  gzip -f "$LOG/latency.csv"
fi
exit "$rc"
