#!/bin/bash
# CMR 4x4 mesh NoC16 GLS: MODE=sdf (MAXIMUM).  TOP_LANES=0.  No Func GLS.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_MESH16_RUN_ID:?}
CASE_NAME=${CMR_MESH16_CASE_NAME:?}
CASE_FILE=${CMR_MESH16_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_MESH16_NETLIST_RUN_ID:-$RUN_ID}
MODE=${CMR_MESH16_GLS_MODE:-sdf}
EXTRA_SIM_ARGS=${CMR_MESH16_SIM_ARGS:-}
INJECT_MAX_RATE=${CMR_MESH16_INJECT_MAX_RATE:-0}
STALL_TIMEOUT_NS=${CMR_MESH16_STALL_TIMEOUT_NS:-50000}
HARD_TIMEOUT_NS=${CMR_MESH16_HARD_TIMEOUT_NS:-400000}
TB_DEFINE="+define+CMR_MESH16"
SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_mesh16.noc.dut"

if [[ "$MODE" == "func" ]]; then
  echo "CMR_MESH16_GLS_FAIL func GLS is not used for 4x4 mesh isolation" >&2
  exit 2
fi
MODE=sdf
RX_CAPTURE_NS=${CMR_MESH16_RX_CAPTURE_NS:-0.1}
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"

OUT="$ROOT/outputs/$NETLIST_RUN_ID"
CSV="$ROOT/results/$RUN_ID/csv/${MODE}_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST_RAW="$OUT/CMRMeshNoC_post.v"
SDF="$OUT/CMRMeshNoC.sdf"

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST_RAW"
test -s "$ROOT/sim/tb/async_noc16_mesh_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_noc64_async_boundary.sv"
test -s "$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv"
test -s "$SDF"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST_RAW" "$LIB" "$SDF" \
  "$ROOT/sim/tb/async_noc16_mesh_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc64_async_boundary.sv" \
  "$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv" | tee "$LOG/input_hashes.log"
echo "CMR_MESH16_GLS mode=$MODE rx_capture=$RX_CAPTURE_NS scope=$SDF_SCOPE" | tee -a "$LOG/input_hashes.log"

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
$ROOT/sim/tb/async_noc16_mesh_port_adapter.sv
$ROOT/sim/tb/tb_noc64_async_boundary.sv
$ROOT/sim/tb/tb_cmr_noc64_async_boundary_failfast.sv
$WORK/sdf_boot.sv
EOF
TIMING_ARGS="+neg_tchk"
TOP_EXTRA="-top sdf_boot"

cd "$WORK"
find "$WORK" -exec touch -c {} + 2>/dev/null || true
set +e
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps $TIMING_ARGS $TB_DEFINE -f filelist.f \
  -top tb_cmr_noc64_async_boundary_failfast $TOP_EXTRA \
  -o simv -l "$LOG/compile.log"
vcs_rc=$?
set -e
if [[ ! -x ./simv ]]; then
  echo "CMR_MESH16_GLS_FAIL vcs rc=$vcs_rc simv missing under $WORK" >&2
  exit 2
fi
if [[ "$vcs_rc" -ne 0 ]]; then
  echo "CMR_MESH16_GLS_WARN vcs rc=$vcs_rc continuing because simv exists" >&2
fi

INJECT_ARG=""
if [[ "$INJECT_MAX_RATE" == "1" ]]; then
  INJECT_ARG="+INJECT_MAX_RATE"
elif [[ "$INJECT_MAX_RATE" != "0" ]]; then
  echo "CMR_MESH16_GLS_FAIL invalid INJECT_MAX_RATE=$INJECT_MAX_RATE" >&2
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
exit "$rc"
