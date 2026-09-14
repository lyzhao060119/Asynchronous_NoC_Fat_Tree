#!/bin/bash
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_PATH_LATCH_RUN_ID:?}
OUT="$ROOT/outputs/$RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/path_latch"
WORK="$ROOT/sim/work/$RUN_ID/path_latch"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
mkdir -p "$LOG" "$WORK"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$OUT/OPMSelector.sdf", tb_opm_selector_path_latch_smoke.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $OUT/OPMSelector.sdf");
  end
endmodule
EOF

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +no_notifier \
  "$LIB" "$OUT/OPMSelector_post.v" "$ROOT/sim/tb/tb_opm_selector_path_latch_smoke.sv" sdf_boot.sv \
  -top tb_opm_selector_path_latch_smoke -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
./simv -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true

if [[ $rc -ne 0 ]] || ! grep -q "TB_RESULT PASS" "$LOG/run.log"; then
  echo "CMR_PATH_LATCH_SDF_FAIL simulation"
  exit 2
fi
if grep -Eq "TB_RESULT FAIL|Timing violation|Both CDN and SDN|TB_FAIL" "$LOG/run.log"; then
  echo "CMR_PATH_LATCH_SDF_FAIL diagnostics"
  exit 2
fi
echo "CMR_PATH_LATCH_SDF_PASS"
