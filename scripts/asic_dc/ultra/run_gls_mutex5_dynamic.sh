#!/bin/bash
set -euo pipefail
ROOT=${ULTRA_REMOTE_ROOT:?}; RUN_ID=${ULTRA_MUTEX5_RUN_ID:?}
OUT="$ROOT/outputs/mutex5/$RUN_ID"; LOG="$ROOT/logs/mutex5/$RUN_ID/sdf"; WORK="$ROOT/sim/work/mutex5_$RUN_ID/sdf"
mkdir -p "$LOG"; rm -rf -- "$WORK"; mkdir -p "$WORK"
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}; export PATH="$VCS_HOME/bin:$PATH"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
cp "$ROOT/sim/tb/tb_mutex5_dynamic_sdf.sv" "$WORK/"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial \$sdf_annotate("$OUT/Mutex5Anchor.sdf", tb_mutex5_dynamic_sdf.dut, , "sdf_annotate.log", "MAXIMUM", ,); endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
$LIB
$OUT/Mutex5Anchor_post.v
$WORK/tb_mutex5_dynamic_sdf.sv
$WORK/sdf_boot.sv
EOF
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +no_notifier -f filelist.f -top tb_mutex5_dynamic_sdf -top sdf_boot -o simv -l "$LOG/compile.log"
./simv -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
cp sdf_annotate.log "$LOG/" 2>/dev/null || true
