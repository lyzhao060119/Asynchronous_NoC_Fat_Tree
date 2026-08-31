#!/bin/bash
set -euo pipefail

ROOT=${CMR_REMOTE_ROOT:?}
RUN_ID=${CMR_LANE_MUTEX_RUN_ID:?}
OUT="$ROOT/outputs/$RUN_ID"
LOG="$ROOT/logs/gls/$RUN_ID/lane_mutex"
WORK="$ROOT/sim/work/$RUN_ID/lane_mutex"
LIB=${STD_CELL_V:-/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v}
SIM_TIMEOUT_SEC=${CMR_LANE_MUTEX_TIMEOUT_SEC:-90}
mkdir -p "$LOG" "$WORK"

cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot;
  initial begin
    \$sdf_annotate("$OUT/CMRLaneSelectorMutex2Harness.sdf", tb_cmr_lane_mutex_contention.dut, , "sdf_annotate.log", "MAXIMUM", ,);
    \$display("TB_INFO SDF annotate $OUT/CMRLaneSelectorMutex2Harness.sdf");
  end
endmodule
EOF

module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=${VCS_HOME:-/soft/synopsys/vcs/V-2023.12}
export PATH="$VCS_HOME/bin:$PATH"
cd "$WORK"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +define+CMR_POST_SYNTH \
  "$LIB" "$OUT/CMRLaneSelectorMutex2Harness_post.v" \
  "$ROOT/sim/tb/tb_cmr_lane_mutex_contention.sv" sdf_boot.sv \
  -top tb_cmr_lane_mutex_contention -top sdf_boot -o simv -l "$LOG/compile.log"
set +e
timeout --preserve-status "${SIM_TIMEOUT_SEC}s" ./simv -l "$LOG/run.log" 2>&1 | tee "$LOG/stdout.log"
rc=${PIPESTATUS[0]}
set -e
cp sdf_annotate.log "$LOG/sdf_annotate.log" 2>/dev/null || true

if [[ $rc -ne 0 ]] || ! grep -q "TB_RESULT PASS" "$LOG/run.log"; then
  echo "CMR_LANE_MUTEX_SDF_FAIL simulation"
  exit 2
fi
if grep -Eq "TB_RESULT FAIL|TB_FAIL|Timing violation|IFNSDFA" "$LOG/run.log" "$LOG/sdf_annotate.log"; then
  echo "CMR_LANE_MUTEX_SDF_FAIL diagnostics"
  exit 2
fi
echo "CMR_LANE_MUTEX_SDF_PASS"
