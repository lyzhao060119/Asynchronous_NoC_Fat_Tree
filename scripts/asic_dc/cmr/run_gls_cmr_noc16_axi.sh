#!/bin/bash
# Strict SDF GLS for CMR NoC16 on the Ultra AXI/BRAM harness.
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_NOC16_RUN_ID:?}
CASE_NAME=${CMR_NOC16_CASE_NAME:?}
CASE_FILE=${CMR_NOC16_CASE_FILE:?}
NETLIST_RUN_ID=${CMR_NOC16_NETLIST_RUN_ID:-$RUN_ID}
OUT="$ROOT/outputs/$NETLIST_RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/sdf/$CASE_NAME"
WORK="$ROOT/sim/work/$RUN_ID/sdf/$CASE_NAME"
rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG" "$ROOT/results/$RUN_ID/csv"

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
NETLIST="$OUT/NoC_16nodes_post.v"
SDF="$OUT/NoC_16nodes.sdf"
CSV="$ROOT/results/$RUN_ID/csv/$CASE_NAME.csv"
test -s "$CASE_FILE"
test -s "$NETLIST"
test -s "$SDF"
test -s "$ROOT/sim/tb/async_noc16_axi_bram_wrapper.sv"
test -s "$ROOT/sim/tb/tb_noc16_async_axi_bram.sv"

sha256sum "$CASE_FILE" "$NETLIST" "$SDF" \
  "$ROOT/sim/tb/async_noc16_axi_bram_wrapper.sv" \
  "$ROOT/sim/tb/tb_noc16_async_axi_bram.sv" | tee "$LOG/input_hashes.log"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$SDF", tb_noc16_async_axi_bram.dut.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $SDF");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$NETLIST
$ROOT/sim/tb/async_noc16_axi_bram_wrapper.sv
$ROOT/sim/tb/tb_noc16_async_axi_bram.sv
$WORK/sdf_boot.sv
EOF

cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier -f filelist.f \
  -top tb_noc16_async_axi_bram -top sdf_boot \
  -o simv -l "$LOG/compile.log"
set +e
./simv +CASE="$CASE_FILE" +CSV="$CSV" +NOC16_DIAG_FILE="$LOG/checker_full.log" \
  -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
cp "$CSV" "$LOG/result.csv" 2>/dev/null || true
exit "$rc"
