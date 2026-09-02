#!/bin/bash
# CMR NoC64 GLS: MODE=func (no SDF, patched Mutex/Delay) or MODE=sdf (MAXIMUM).
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NOC64_RUN_ID:?}
CASE_NAME=${CMR_NOC64_CASE_NAME:?}
CASE_FILE=${CMR_NOC64_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_NOC64_NETLIST_RUN_ID:-$RUN_ID}
MODE=${CMR_NOC64_GLS_MODE:-sdf}
PROFILE=${CMR_FAT_LANE_PROFILE:-1222}
EXTRA_SIM_ARGS=${CMR_NOC64_SIM_ARGS:-}
INJECT_MAX_RATE=${CMR_NOC64_INJECT_MAX_RATE:-0}
STALL_TIMEOUT_NS=${CMR_NOC64_STALL_TIMEOUT_NS:-50000}
HARD_TIMEOUT_NS=${CMR_NOC64_HARD_TIMEOUT_NS:-400000}

if [[ "$PROFILE" == "1222" || "$PROFILE" == "FatLane1222" || "$PROFILE" == "1-2-2-2" ]]; then
  PROFILE=1222
  TB_DEFINE="+define+CMR_NOC64_TOP2"
  SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_1222.noc.dut"
elif [[ "$PROFILE" == "thin" || "$PROFILE" == "111" || "$PROFILE" == "1-1-1-1" ]]; then
  PROFILE=thin
  TB_DEFINE="+define+CMR_NOC64_THIN"
  SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_thin.noc.dut"
else
  PROFILE=1248
  TB_DEFINE=""
  SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc.noc.dut"
fi

if [[ "$MODE" == "func" ]]; then
  RX_CAPTURE_NS=${CMR_NOC64_RX_CAPTURE_NS:-5}
  LOG="$ROOT/logs/gls/$RUN_ID/func/$CASE_NAME"
  WORK="$ROOT/sim/work/$RUN_ID/func/$CASE_NAME"
else
  MODE=sdf
  RX_CAPTURE_NS=${CMR_NOC64_RX_CAPTURE_NS:-0.1}
  LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
  WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
fi

OUT="$ROOT/outputs/$NETLIST_RUN_ID"
CSV="$ROOT/results/$RUN_ID/csv/${MODE}_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST_RAW="$OUT/NoC_64nodes_post.v"
SDF="$OUT/NoC_64nodes.sdf"
PATCH_TOOL="$ROOT/scripts/patch_gls_netlist.py"

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST_RAW"
test -s "$ROOT/sim/tb/async_noc64_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_noc64_async_boundary.sv"
test -s "$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST_RAW" "$LIB" \
  "$ROOT/sim/tb/async_noc64_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc64_async_boundary.sv" \
  "$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv" | tee "$LOG/input_hashes.log"
echo "CMR_NOC64_GLS mode=$MODE profile=$PROFILE rx_capture=$RX_CAPTURE_NS scope=$SDF_SCOPE" | tee -a "$LOG/input_hashes.log"

if [[ "$MODE" == "func" ]]; then
  test -s "$PATCH_TOOL"
  NETLIST="$OUT/NoC_64nodes_post_func.v"
  PY=$(command -v python3 || command -v python || true)
  if [[ -z "$PY" ]]; then
    echo "CMR_NOC64_GLS_FAIL no Python interpreter for functional netlist patch" >&2
    exit 2
  fi
  "$PY" "$PATCH_TOOL" "$NETLIST_RAW" "$NETLIST" --mode cmr_func | tee "$LOG/netlist_patch.log"
  if ! grep -q 'q0 = ~(req0 & q1)' "$NETLIST" || ! grep -q 'assign #(1.0)' "$NETLIST"; then
    echo "CMR_NOC64_GLS_FAIL functional Mutex/Delay patch incomplete" >&2
    exit 2
  fi
  sha256sum "$NETLIST" "$PATCH_TOOL" >> "$LOG/input_hashes.log"
  cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$ROOT/sim/tb/async_noc64_port_adapter.sv
$ROOT/sim/tb/tb_noc64_async_boundary.sv
$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv
EOF
  TIMING_ARGS="+notimingcheck +no_notifier"
  TOP_EXTRA=""
else
  test -s "$SDF"
  sha256sum "$SDF" >> "$LOG/input_hashes.log"
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
$ROOT/sim/tb/async_noc64_port_adapter.sv
$ROOT/sim/tb/tb_noc64_async_boundary.sv
$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv
$WORK/sdf_boot.sv
EOF
  TIMING_ARGS="+neg_tchk"
  TOP_EXTRA="-top sdf_boot"
fi

cd "$WORK"
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps $TIMING_ARGS $TB_DEFINE -f filelist.f \
  -top tb_cmr_noc64_async_boundary_failfast $TOP_EXTRA \
  -o simv -l "$LOG/compile.log"

INJECT_ARG=""
if [[ "$INJECT_MAX_RATE" == "1" ]]; then
  INJECT_ARG="+INJECT_MAX_RATE"
elif [[ "$INJECT_MAX_RATE" != "0" ]]; then
  echo "CMR_NOC64_GLS_FAIL invalid INJECT_MAX_RATE=$INJECT_MAX_RATE" >&2
  exit 2
fi

set +e
SIMV_TIMING=""
if [[ "$MODE" == "func" ]]; then
  SIMV_TIMING="$TIMING_ARGS"
fi
# shellcheck disable=SC2086
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  $SIMV_TIMING \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
  +CASE_TICK_NS=20 +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  $INJECT_ARG $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
if [[ "$MODE" == "sdf" ]]; then
  cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
fi
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"
