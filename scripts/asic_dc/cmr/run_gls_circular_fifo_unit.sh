#!/bin/bash
set -euo pipefail
ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_CFIFO_RUN_ID:?}
OUT="$ROOT/outputs/$RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/circular_fifo_unit"
WORK="$ROOT/sim/work/$RUN_ID/circular_fifo_unit"
rm -rf -- "$WORK"
mkdir -p "$WORK" "$LOG"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
test -s "$OUT/CircularFifoUnit_post.v"
test -s "$OUT/CircularFifoUnit.sdf"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$OUT/CircularFifoUnit.sdf", tb_circular_fifo_gls.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TCF_GLS_SDF $OUT/CircularFifoUnit.sdf");
  end
endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$OUT/CircularFifoUnit_post.v
$ROOT/sim/tb/tb_circular_fifo_gls.sv
$WORK/sdf_boot.sv
EOF
sha256sum "$LIB" "$OUT/CircularFifoUnit_post.v" "$OUT/CircularFifoUnit.sdf" "$ROOT/sim/tb/tb_circular_fifo_gls.sv" > "$LOG/input_hashes.log"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk -f filelist.f -top tb_circular_fifo_gls -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true
exit "$rc"
