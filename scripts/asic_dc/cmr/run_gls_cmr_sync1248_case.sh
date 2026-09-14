#!/bin/bash
# Strict MAXIMUM-SDF GLS for the synchronous Q64 1-2-4-8 open-loop case TB.
set -euo pipefail
ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_SYNC1248_RUN_ID:?}
NETLIST_RUN_ID=${CMR_SYNC1248_NETLIST_RUN_ID:?}
LOAD=${CMR_SYNC1248_LOAD_MFLIT:?}
CASE_FILE=${CMR_SYNC1248_CASE_FILE:?}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/sdf/m${LOAD}"
WORK="$ROOT/sim/work/$RUN_ID/sdf/m${LOAD}"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/SyncNoC_64nodes_post.v"
SDF="$OUT/SyncNoC_64nodes.sdf"
TB="$ROOT/sim/tb/tb_noc64_sync_boundary.sv"
ADAPTER="$ROOT/sim/tb/sync_noc64_port_adapter.sv"
test -s "$NETLIST"; test -s "$SDF"; test -s "$TB"; test -s "$ADAPTER"; test -s "$CASE_FILE"
rm -rf -- "$WORK"; mkdir -p "$WORK" "$LOG"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
sha256sum "$NETLIST" "$SDF" "$TB" "$ADAPTER" "$CASE_FILE" "$LIB" | tee "$LOG/input_hashes.sha256"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
 initial begin
  \$sdf_annotate("$SDF", tb_noc64_sync_boundary.core.noc.dut, , "sdf_annotate.log", "MAXIMUM", ,);
  \$display("TB_INFO SDF_MAX scope=tb_noc64_sync_boundary.core.noc.dut load_mflit=$LOAD");
 end
endmodule
EOF
printf '%s\n' "$LIB" "$NETLIST" "$ADAPTER" "$TB" "$WORK/sdf_boot.sv" > "$WORK/filelist.f"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier +define+CMR_SYNC64_TOP8 -f filelist.f \
  -top tb_noc64_sync_boundary -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv +CLOCK_PERIOD_NS="${CMR_SYNC1248_CLOCK_NS:-1.0}" +CASE_TICK_NS="${CMR_SYNC1248_CASE_TICK_NS:-1.0}" \
  +CASE_FILE="$CASE_FILE" +RESULT_CSV="$LOG/metrics.csv" +EVENT_CSV="$LOG/events.csv" \
  +LATENCY_CSV="$LOG/latency.csv" +V3_METRICS_CSV="$LOG/v3_metrics.csv" \
  ${CMR_SYNC1248_SIM_ARGS:-} -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
if grep -Eqi 'Timing violation|TB_FAIL|TB_FATAL|TB_RESULT FAIL|SDF.*error|Total errors:[[:space:]]*[1-9]' "$LOG/run.log" "$LOG/sdf_annotate.log" 2>/dev/null; then
  echo "CMR_SYNC1248_GLS_FAIL protocol timing or annotation" >&2; exit 3
fi
grep -q 'TB_RESULT PASS' "$LOG/run.log"
grep -q 'Doing SDF annotation ...... Done' "$LOG/run.log"
grep -Eq 'Total errors:[[:space:]]*0' "$LOG/sdf_annotate.log"
test -s "$LOG/metrics.csv"; test -s "$LOG/events.csv"; test -s "$LOG/v3_metrics.csv"
exit "$rc"
