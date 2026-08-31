#!/bin/bash
# CMR sync NoC64 GLS: MAXIMUM SDF only.  No functional/no-SDF path.
# Thin default TOP_LANES=1.  Fat 1-2-2-2: CMR_SYNC64_TOP_LANES=2.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_SYNC64_RUN_ID:?}
CASE_NAME=${CMR_SYNC64_CASE_NAME:?}
CASE_FILE=${CMR_SYNC64_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_SYNC64_NETLIST_RUN_ID:-$RUN_ID}
CLOCK_PERIOD_NS=${CMR_SYNC64_CLOCK_PERIOD_NS:-1.0}
EXTRA_SIM_ARGS=${CMR_SYNC64_SIM_ARGS:-}
INJECT_MAX_RATE=${CMR_SYNC64_INJECT_MAX_RATE:-0}
STALL_TIMEOUT_NS=${CMR_SYNC64_STALL_TIMEOUT_NS:-50000}
HARD_TIMEOUT_NS=${CMR_SYNC64_HARD_TIMEOUT_NS:-400000}
RX_CAPTURE_NS=${CMR_SYNC64_RX_CAPTURE_NS:-0}
TOP_LANES=${CMR_SYNC64_TOP_LANES:-1}
SDF_SCOPE="tb_cmr_noc64_sync_boundary_failfast.core.noc.dut"
TB_DEFINE=""
if [[ "$TOP_LANES" == "2" ]]; then
  TB_DEFINE="+define+CMR_SYNC64_TOP2"
elif [[ "$TOP_LANES" != "1" ]]; then
  echo "CMR_SYNC64_GLS_FAIL TOP_LANES must be 1 or 2, got $TOP_LANES" >&2
  exit 2
fi

MODE=${CMR_SYNC64_GLS_MODE:-sdf}
if [[ "$MODE" != "sdf" ]]; then
  echo "CMR_SYNC64_GLS_FAIL functional GLS is forbidden; mode=$MODE" >&2
  exit 2
fi

LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
CSV="$ROOT/results/$RUN_ID/csv/sdf_$CASE_NAME.csv"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/SyncNoC_64nodes_post.v"
SDF="$OUT/SyncNoC_64nodes.sdf"

rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"
test -s "$CASE_FILE"
test -s "$NETLIST"
test -s "$SDF"
test -s "$ROOT/sim/tb/sync_noc64_port_adapter.sv"
test -s "$ROOT/sim/tb/tb_noc64_sync_boundary.sv"
test -s "$ROOT/sim/tb/tb_cmr_noc64_sync_boundary_failfast.sv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"

sha256sum "$CASE_FILE" "$NETLIST" "$SDF" "$LIB" \
  "$ROOT/sim/tb/sync_noc64_port_adapter.sv" \
  "$ROOT/sim/tb/tb_noc64_sync_boundary.sv" \
  "$ROOT/sim/tb/tb_cmr_noc64_sync_boundary_failfast.sv" | tee "$LOG/input_hashes.log"
echo "CMR_SYNC64_GLS mode=sdf clock=${CLOCK_PERIOD_NS}ns top_lanes=$TOP_LANES rx_capture=$RX_CAPTURE_NS scope=$SDF_SCOPE" | tee -a "$LOG/input_hashes.log"

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
$NETLIST
$ROOT/sim/tb/sync_noc64_port_adapter.sv
$ROOT/sim/tb/tb_noc64_sync_boundary.sv
$ROOT/sim/tb/tb_cmr_noc64_sync_boundary_failfast.sv
$WORK/sdf_boot.sv
EOF

cd "$WORK"
# shellcheck disable=SC2086
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk $TB_DEFINE -f filelist.f \
  -top tb_cmr_noc64_sync_boundary_failfast -top sdf_boot \
  -o simv -l "$LOG/compile.log"

INJECT_ARG=""
if [[ "$INJECT_MAX_RATE" == "1" ]]; then
  INJECT_ARG="+INJECT_MAX_RATE"
elif [[ "$INJECT_MAX_RATE" != "0" ]]; then
  echo "CMR_SYNC64_GLS_FAIL invalid INJECT_MAX_RATE=$INJECT_MAX_RATE" >&2
  exit 2
fi

set +e
# shellcheck disable=SC2086
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +CLOCK_PERIOD_NS="$CLOCK_PERIOD_NS" +CASE_TICK_NS=20 \
  +RX_CAPTURE_NS="$RX_CAPTURE_NS" \
  +STALL_TIMEOUT_NS="$STALL_TIMEOUT_NS" +HARD_TIMEOUT_NS="$HARD_TIMEOUT_NS" \
  $INJECT_ARG $EXTRA_SIM_ARGS \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"
