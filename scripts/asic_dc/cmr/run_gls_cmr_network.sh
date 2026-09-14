#!/bin/bash
# Whole-network maximum-delay Standard Delay Format GLS for 256/1024-node DUTs.
# MODE=sdf is the paper path. Do not pass +notimingcheck in sdf mode.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NETWORK_RUN_ID:?}
CASE_NAME=${CMR_NETWORK_CASE_NAME:?}
CASE_FILE=${CMR_NETWORK_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_NETWORK_NETLIST_RUN_ID:-$RUN_ID}
NODES=${CMR_NETWORK_NODES:?}
KIND=${CMR_NETWORK_KIND:?}
TOP=${CMR_NETWORK_TOP:?}
MODE=${CMR_NETWORK_GLS_MODE:-sdf}
EXTRA_SIM_ARGS=${CMR_NETWORK_SIM_ARGS:-}
INJECT_MAX_RATE=${CMR_NETWORK_INJECT_MAX_RATE:-0}
STALL_TIMEOUT_NS=${CMR_NETWORK_STALL_TIMEOUT_NS:-400000}
HARD_TIMEOUT_NS=${CMR_NETWORK_HARD_TIMEOUT_NS:-2000000}

if [[ "$MODE" != "sdf" ]]; then
  echo "CMR_NETWORK_GLS_FAIL paper path requires MODE=sdf, got $MODE" >&2
  exit 2
fi
if [[ "$EXTRA_SIM_ARGS" == *notimingcheck* ]]; then
  echo "CMR_NETWORK_GLS_FAIL +notimingcheck is forbidden in maximum-delay mode" >&2
  exit 2
fi

TB_DEFINE="+define+CMR_NOC_${NODES}"
if [[ "$KIND" == "fm" || "$KIND" == "mesh" ]]; then
  KIND=fm
  TB_DEFINE="$TB_DEFINE +define+CMR_NOC_FM"
else
  KIND=prop
fi

SDF_SCOPE="tb_noc_async_keycase.core.noc.dut"
RX_CAPTURE_NS=${CMR_NETWORK_RX_CAPTURE_NS:-0.1}
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
CSV="$ROOT/results/$RUN_ID/csv/sdf_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST_RAW="$OUT/${TOP}_post.v"
SDF="$OUT/${TOP}.sdf"

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST_RAW"
test -s "$SDF"
test -s "$ROOT/sim/tb/async_noc_scale_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_noc_async_keycase.sv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST_RAW" "$SDF" "$LIB" \
  "$ROOT/sim/tb/async_noc_scale_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc_async_keycase.sv" | tee "$LOG/input_hashes.log"
echo "CMR_NETWORK_GLS mode=sdf nodes=$NODES kind=$KIND top=$TOP rx_capture=$RX_CAPTURE_NS scope=$SDF_SCOPE" | tee -a "$LOG/input_hashes.log"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $SDF_SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $SDF scope=$SDF_SCOPE");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST_RAW
$ROOT/sim/tb/async_noc_scale_port_adapter.sv
$ROOT/sim/tb/tb_noc_async_keycase.sv
$WORK/sdf_boot.sv
EOF

cd "$WORK"
find "$WORK" -exec touch -c {} + 2>/dev/null || true
set +e
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk $TB_DEFINE -f filelist.f \
  -top tb_noc_async_keycase -top sdf_boot \
  -o simv -l "$LOG/compile.log"
vcs_rc=$?
set -e
if [[ ! -x ./simv ]]; then
  echo "CMR_NETWORK_GLS_FAIL vcs rc=$vcs_rc simv missing under $WORK" >&2
  exit 2
fi
if grep -E '\+notimingcheck' "$LOG/compile.log" >/dev/null 2>&1; then
  echo "CMR_NETWORK_GLS_FAIL compile used +notimingcheck" >&2
  exit 2
fi

INJECT_ARG=""
if [[ "$INJECT_MAX_RATE" == "1" ]]; then
  INJECT_ARG="+INJECT_MAX_RATE"
elif [[ "$INJECT_MAX_RATE" != "0" ]]; then
  echo "CMR_NETWORK_GLS_FAIL invalid INJECT_MAX_RATE=$INJECT_MAX_RATE" >&2
  exit 2
fi

set +e
# shellcheck disable=SC2086
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  $INJECT_ARG $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true

if [[ ! -s "$LOG/sdf_annotate.log" ]]; then
  echo "CMR_NETWORK_GLS_FAIL missing sdf_annotate.log" >&2
  exit 2
fi
if ! grep -qiE 'SDF (of|annotate)|annotation' "$LOG/sdf_annotate.log" "$LOG/stdout.log" 2>/dev/null; then
  echo "CMR_NETWORK_GLS_FAIL delay annotation did not complete" >&2
  exit 2
fi
if grep -Eiq 'Total errors:[[:space:]]*[1-9]' "$LOG/sdf_annotate.log"; then
  echo "CMR_NETWORK_GLS_FAIL annotation errors are not zero" >&2
  exit 2
fi
if grep -Eiq 'Timing violation' "$LOG/run.log" "$LOG/stdout.log"; then
  echo "CMR_NETWORK_GLS_FAIL timing violations present" >&2
  exit 2
fi
if grep -E 'TB_X_FAIL|TB_RESULT FAIL|TB_FATAL|TB_STALL_FAIL|TB_HARD_TIMEOUT' "$LOG/run.log" "$LOG/stdout.log"; then
  echo "CMR_NETWORK_GLS_FAIL scoreboard or unknown-value failure" >&2
  exit 2
fi
if ! grep -q 'TB_RESULT PASS' "$LOG/run.log" "$LOG/stdout.log"; then
  echo "CMR_NETWORK_GLS_FAIL missing TB_RESULT PASS" >&2
  exit 2
fi
echo "CMR_NETWORK_GLS_PASS $CASE_NAME" | tee -a "$LOG/stdout.log"
exit "$rc"
