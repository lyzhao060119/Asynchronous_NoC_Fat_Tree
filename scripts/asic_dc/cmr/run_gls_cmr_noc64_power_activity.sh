#!/bin/bash
# MAXIMUM-SDF activity capture for one immutable paper64 NoC power point.
set -euo pipefail
ROOT=${CMR_REMOTE_ROOT:?}
DATA_ROOT=${CMR_POWER_DATA_ROOT:-$ROOT}
RUN_ID=${CMR_POWER_RUN_ID:?}
NETLIST_RUN_ID=${CMR_POWER_NETLIST_RUN_ID:?}
DESIGN=${CMR_POWER_DESIGN:?}             # FM64, PFAT64, PROP_temp64, or PROP_temp64_static4
CASE_NAME=${CMR_POWER_CASE_NAME:?}
CASE_FILE=${CMR_POWER_CASE_FILE:?}
LOAD=${CMR_POWER_LOAD_MFLIT:?}
TAG=${CMR_POWER_TAG:-$DESIGN/m$LOAD}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$DATA_ROOT/logs/paper64_power/$RUN_ID/$TAG"
WORK="$DATA_ROOT/work/$RUN_ID/power/$TAG"
CSV="$DATA_ROOT/results/paper64_power/$RUN_ID/$TAG/result.csv"
VCD="$LOG/measurement.vcd"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
INPUT_ROOT=${CMR_POWER_INPUT_ROOT:-$ROOT/sim/tb}
VCD_MODE=${CMR_POWER_VCD_MODE:-measurement}
LANE_MONITOR=${CMR_POWER_LANE_MONITOR:-0}
MONITOR_FILE="$INPUT_ROOT/tb_prop_temp64_lane_monitor.sv"

case "$DESIGN" in
  FM64)
    NETLIST="$OUT/CMRMeshNoC_post.v"; SDF="$OUT/CMRMeshNoC.sdf"
    ADAPTER="$INPUT_ROOT/async_noc64_mesh_port_adapter.sv"
    TB_DEFINE="+define+CMR_NOC64_MESH"
    SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_mesh.noc.dut"
    ;;
  PFAT64)
    NETLIST="$OUT/NoC_64nodes_post.v"; SDF="$OUT/NoC_64nodes.sdf"
    ADAPTER="$INPUT_ROOT/async_noc64_port_adapter.sv"
    TB_DEFINE=""
    SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc.noc.dut"
    ;;
  PROP_temp64)
    NETLIST="$OUT/PROP_temp64_post.v"; SDF="$OUT/PROP_temp64.sdf"
    ADAPTER="$INPUT_ROOT/async_prop_temp64_port_adapter.sv"
    TB_DEFINE="+define+PROP_TEMP64_TOP16"
    SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp.noc.dut"
    ;;
  PROP_temp64_static4)
    NETLIST="$OUT/PROP_temp64_static4_post.v"; SDF="$OUT/PROP_temp64_static4.sdf"
    ADAPTER="$INPUT_ROOT/async_prop_temp64_port_adapter.sv"
    TB_DEFINE="+define+PROP_TEMP64_TOP16 +define+PROP_TEMP64_STATIC4"
    SDF_SCOPE="tb_cmr_noc64_async_boundary_failfast.core.g_behavioral_noc_prop_temp.noc.dut"
    ;;
  *) echo "CMR_POWER_ACTIVITY_FAIL unsupported DESIGN=$DESIGN" >&2; exit 2 ;;
esac

TB="$INPUT_ROOT/tb_noc64_async_boundary.sv"
WRAPPER="$INPUT_ROOT/tb_cmr_noc64_async_boundary_failfast.sv"
rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$(dirname "$CSV")"
test -s "$CASE_FILE"; test -s "$NETLIST"; test -s "$SDF"; test -s "$ADAPTER"; test -s "$TB"; test -s "$WRAPPER"
if [[ "$LANE_MONITOR" == 1 ]]; then
  [[ "$DESIGN" == PROP_temp64 || "$DESIGN" == PROP_temp64_static4 ]] || { echo "CMR_POWER_ACTIVITY_FAIL lane monitor unsupported for $DESIGN" >&2; exit 2; }
  test -s "$MONITOR_FILE"
fi
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
sha256sum "$CASE_FILE" "$NETLIST" "$SDF" "$LIB" "$ADAPTER" "$TB" "$WRAPPER" > "$LOG/input_hashes.sha256"
if [[ "$LANE_MONITOR" == 1 ]]; then sha256sum "$MONITOR_FILE" >> "$LOG/input_hashes.sha256"; fi
printf 'design=%s\nload_mflit_per_port_s=%s\nnetlist_run_id=%s\nsdf_scope=%s\n' "$DESIGN" "$LOAD" "$NETLIST_RUN_ID" "$SDF_SCOPE" >> "$LOG/input_hashes.sha256"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", $SDF_SCOPE, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF_MAX scope=$SDF_SCOPE power_activity=1");
  end
endmodule
EOF
printf '%s\n' "$LIB" "$NETLIST" "$ADAPTER" "$TB" "$WRAPPER" "$WORK/sdf_boot.sv" > "$WORK/filelist.f"
monitor_top=(-top tb_cmr_noc64_async_boundary_failfast -top sdf_boot)
if [[ "$LANE_MONITOR" == 1 ]]; then
  printf '%s\n' "$MONITOR_FILE" >> "$WORK/filelist.f"
  monitor_top+=(-top tb_prop_temp64_lane_monitor)
fi
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk $TB_DEFINE -f filelist.f \
  "${monitor_top[@]}" -o simv -l "$LOG/compile.log"
dump_args=("+DUMP_VCD=$VCD")
case "$VCD_MODE" in
  measurement) dump_args+=(+DUMP_MEASUREMENT_ONLY) ;;
  full_drain) ;;
  *) echo "CMR_POWER_ACTIVITY_FAIL unsupported VCD_MODE=$VCD_MODE" >&2; exit 2 ;;
esac
set +e
./simv +CASE_FILE="$CASE_FILE" +RESULT_CSV="$CSV" \
  +EVENT_CSV="$LOG/events.csv" +LATENCY_CSV="$LOG/latency.csv" \
  +FLIT_LATENCY_CSV="$LOG/flit_latency.csv" +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
  +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +STALL_TIMEOUT_NS=50000 +HARD_TIMEOUT_NS=400000 \
  +LANE_CSV="$LOG/lane_counts.csv" \
  "${dump_args[@]}" -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
tb_pass='TB_RESULT PASS injected=55000 delivered=55000 missing=0 unexpected=0 timeout=0'
if [[ "$VCD_MODE" == full_drain ]]; then tb_pass='TB_RESULT PASS'; fi
if [[ "$rc" -ne 0 ]] || ! grep -q "$tb_pass" "$LOG/run.log" || \
   grep -Eqi 'TB_FATAL|TB_RESULT FAIL|Timing violation|Total errors:[[:space:]]*[1-9]' "$LOG/run.log" "$LOG/sdf_annotate.log" || \
   ! grep -Eq 'Total errors:[[:space:]]*0' "$LOG/sdf_annotate.log" || ! test -s "$VCD" || \
   grep -Eqi 'TB_MISSING|TB_UNEXPECTED|TB_X_FAIL|TB_FATAL|Fatal:' "$LOG/run.log"; then
  echo "CMR_POWER_ACTIVITY_FAIL design=$DESIGN load=$LOAD" >&2
  exit 3
fi
if [[ "$LANE_MONITOR" == 1 ]]; then
  grep -q 'CMR_LANE_MONITOR_PASS rows=128' "$LOG/run.log" && test -s "$LOG/lane_counts.csv" || { echo "CMR_POWER_ACTIVITY_FAIL missing lane counters" >&2; exit 3; }
fi
echo "CMR_POWER_ACTIVITY_PASS design=$DESIGN load=$LOAD vcd=$VCD"
