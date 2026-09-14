#!/bin/bash
# Dedicated PROP_temp64 post-DC functional and MAXIMUM-SDF simulation.
set -euo pipefail
ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${PROP_TEMP64_RUN_ID:?}
CASE_FILE=${PROP_TEMP64_CASE_FILE:?}
CASE_NAME=${PROP_TEMP64_CASE_NAME:?}
MODE=${PROP_TEMP64_MODE:-sdf}
OUT="$ROOT/outputs/${PROP_TEMP64_NETLIST_RUN_ID:-$RUN_ID}"
LOG="$ROOT/logs/gls/$RUN_ID/$MODE/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/$MODE/$CASE_NAME"
CSV="$ROOT/results/$RUN_ID/csv/${MODE}_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
RAW="$OUT/PROP_temp64_post.v"
SDF="$OUT/PROP_temp64.sdf"
ADAPTER="$ROOT/sim/prop_temp64_$RUN_ID/async_prop_temp64_port_adapter.sv"
TB="$ROOT/sim/prop_temp64_$RUN_ID/tb_noc64_async_boundary.sv"
FAILFAST="$ROOT/sim/prop_temp64_$RUN_ID/tb_cmr_noc64_async_boundary_failfast.sv"
PATCH="$ROOT/sim/prop_temp64_$RUN_ID/patch_gls_netlist.py"
test "$MODE" = func -o "$MODE" = sdf
test -s "$RAW" && test -s "$CASE_FILE" && test -s "$ADAPTER" && test -s "$TB" && test -s "$FAILFAST"
if [[ "$MODE" == sdf ]]; then test -s "$SDF"; fi
mkdir -p "$WORK" "$LOG" "$(dirname "$CSV")"
cd "$WORK"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
sha256sum "$CASE_FILE" "$RAW" "$ADAPTER" "$TB" "$FAILFAST" > "$LOG/input_hashes.log"
if [[ "$MODE" == func ]]; then
  NETLIST="$WORK/PROP_temp64_func.v"
  python3 "$PATCH" "$RAW" "$NETLIST" --mode cmr_func > "$LOG/netlist_patch.log"
  grep -q 'q0 = ~(req0 & q1)' "$NETLIST"
  grep -q 'assign #(1.0)' "$NETLIST"
  TIMING='+notimingcheck +no_notifier'
  BOOT=''
else
  NETLIST="$RAW"
  TIMING='+neg_tchk'
  BOOT="$WORK/sdf_boot.sv"
  sha256sum "$SDF" >> "$LOG/input_hashes.log"
  cat > "$BOOT" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp.noc.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO PROP_temp64 MAXIMUM SDF annotation");
  end
endmodule
EOF
fi
printf '%s\n' "$LIB" "$NETLIST" "$ADAPTER" "$TB" "$FAILFAST" ${BOOT:+"$BOOT"} > filelist.f
vcs -full64 -sverilog -timescale=1ns/1ps $TIMING +define+PROP_TEMP64_TOP16 \
  -f filelist.f -top tb_cmr_noc64_async_boundary_failfast ${BOOT:+-top sdf_boot} \
  -o simv -l "$LOG/compile.log"
set +e
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" +MISSING_CSV="$LOG/missing_expected.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" +CASE_TICK_NS=1 \
  +RX_CAPTURE_NS="${PROP_TEMP64_RX_CAPTURE_NS:-0.1}" \
  +STALL_TIMEOUT_NS="${PROP_TEMP64_STALL_TIMEOUT_NS:-50000}" \
  +HARD_TIMEOUT_NS="${PROP_TEMP64_HARD_TIMEOUT_NS:-400000}" \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
if [[ "$MODE" == sdf ]]; then cp sdf_annotate.log "$LOG/" 2>/dev/null || true; fi
if [[ "$MODE" == sdf ]]; then
  test -s "$LOG/sdf_annotate.log" || { echo "PROP_TEMP64_GLS_FAIL missing SDF annotation log" >&2; exit 3; }
  if grep -Eiq 'Total errors:[[:space:]]*[1-9]|SDF[^[:space:]]*[[:space:]]+error' "$LOG/sdf_annotate.log"; then
    echo "PROP_TEMP64_GLS_FAIL SDF annotation errors" >&2
    exit 3
  fi
fi
if grep -Eiq 'Timing violation|TB_RESULT FAIL|TB_X_FAIL|TB_PROTOCOL_X|TB_UNEXPECTED_FAIL|TB_STALL_FAIL|TB_HARD_TIMEOUT|TB_FATAL|Fatal:' "$LOG/run.log" "$LOG/stdout.log" 2>/dev/null; then
  echo "PROP_TEMP64_GLS_FAIL protocol, timing, or scoreboard error" >&2
  exit 3
fi
if ! grep -q 'TB_RESULT PASS' "$LOG/run.log"; then
  echo "PROP_TEMP64_GLS_FAIL missing TB_RESULT PASS" >&2
  exit 3
fi
echo "PROP_TEMP64_GLS_PASS $CASE_NAME" | tee -a "$LOG/stdout.log"
exit "$rc"
