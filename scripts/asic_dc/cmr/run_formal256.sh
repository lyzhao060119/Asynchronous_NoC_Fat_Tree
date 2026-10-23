#!/bin/bash
set -euo pipefail
ROOT=${FORMAL256_ROOT:?}
DESIGN=${1:?}
MODE=${2:?}
source "$ROOT/config.sh"
if [[ "$DESIGN" == Mesh256 ]]; then
  TOP=CMRMeshNoC; NET=$MESH_RUN; DEFINE=+define+CMR_NOC_FM
elif [[ "$DESIGN" == M16_256 ]]; then
  TOP=PROP_temp256_m16; NET=$M16_RUN; DEFINE=+define+CMR_NOC_PROP_TEMP_M16
else exit 2; fi
WORK="$ROOT/work/$DESIGN"
SDF="$ROOT/sdf/$DESIGN.sdf"
test -s "$SDF"
mkdir -p "$WORK"
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
if [[ "$MODE" == compile ]]; then
  cd "$WORK"
  printf 'module sdf_boot; initial $sdf_annotate("%s",tb_noc_async_keycase.core.noc.dut,,"sdf_annotate.log","MAXIMUM",,); endmodule\n' "$SDF" > sdf_boot.sv
  vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +define+NTC+RECREM +define+CMR_NOC_256 "$DEFINE" \
    "$LIB_V" "$ARCHIVE/outputs/$NET/${TOP}_post.v" \
    "$ROOT/src/async_noc_scale_port_adapter.sv" "$ROOT/src/tb_formal256_fast.sv" sdf_boot.sv \
    -top tb_noc_async_keycase -top sdf_boot -o simv -l compile.log
  test -x simv
  sha256sum simv > simv.sha256
  test -s sdf_annotate.log
  grep -q 'Total errors:[[:space:]]*0' sdf_annotate.log
  sha256sum sdf_annotate.log "$SDF" "$ROOT/src/tb_formal256_fast.sv" > annotation_inputs.sha256
  echo "FORMAL256_COMPILE_PASS $DESIGN"
  exit 0
fi
if [[ ! -s "$WORK/annotation_status.json" ]]; then
  /soft/GNU/python3.12/bin/python3 "$ROOT/formal256_campaign.py" audit-annotation --root "$ROOT" --design "$DESIGN"
fi
grep -q '"errors":[[:space:]]*0' "$WORK/annotation_status.json"
grep -q '"negative_separate_checks_limited":[[:space:]]*false' "$WORK/annotation_status.json"
grep -q '"missing_timing_checks":[[:space:]]*0' "$WORK/annotation_status.json"
if [[ "$MODE" == negative ]]; then
  for NEG in DUPLICATE MISSING; do
  LOG="$ROOT/logs/$DESIGN/SCOREBOARD_$NEG"
  mkdir -p "$LOG"
  cd "$LOG"
  ln -sfn "$WORK/sdf_annotate.log" sdf_annotate.log
  "$WORK/simv" -no_save +CASE_FILE="$ROOT/cases/SCOREBOARD_${NEG}_${DESIGN}.case" \
    +RESULT_CSV="$LOG/result.csv" +EVENT_CSV=/dev/null +LATENCY_CSV="$LOG/latency.csv" \
    +FLIT_LATENCY_CSV=/dev/null +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +HARD_TIMEOUT_NS=10000 \
    -l run.log > stdout.log 2>&1 || true
  grep -q 'TB_RESULT FAIL' run.log
  CHECK="$NEG" /soft/GNU/python3.12/bin/python3 -c 'import csv,os; r=next(csv.DictReader(open("result.csv"))); k="unexpected_flits" if os.environ["CHECK"]=="DUPLICATE" else "missing_expected_flits"; assert int(r[k]) > 0'
  grep -q '"errors":[[:space:]]*0' "$WORK/annotation_status.json"
  ! grep -Eiq 'Timing violation|TB_X_FAIL|TB_FATAL' run.log
  echo "FORMAL256_SCOREBOARD_NEGATIVE_PASS $DESIGN $NEG"
  done
  exit 0
fi
CASE=${3:?case stem}
VARIANT=${4:-native}
NAME="$CASE"
[[ "$VARIANT" == repeated ]] && NAME="${CASE}_repeated"
LOG="$ROOT/logs/$DESIGN/$NAME"
mkdir -p "$LOG" "$ROOT/results/$DESIGN"
test -x "$WORK/simv"
cd "$LOG"
ln -sfn "$WORK/sdf_annotate.log" sdf_annotate.log
cp "$WORK/annotation_inputs.sha256" annotation_inputs.sha256 2>/dev/null || true
sha256sum "$ROOT/cases/${CASE}_${DESIGN}_${VARIANT}.case" "$WORK/simv" > input_hashes.sha256
if [[ -s run.log && -s "$ROOT/results/$DESIGN/$NAME.csv" && -s latency.csv ]] &&
   grep -q 'TB_RESULT PASS' run.log &&
   ! grep -Eiq 'Timing violation|TB_X_FAIL|TB_RESULT FAIL|TB_FATAL' run.log; then
  if [[ "$VARIANT" == repeated ]]; then
    /soft/GNU/python3.12/bin/python3 "$ROOT/formal256_campaign.py" collect-case --root "$ROOT" --design "$DESIGN" --stem "$CASE" --repeated
  else
    /soft/GNU/python3.12/bin/python3 "$ROOT/formal256_campaign.py" collect-case --root "$ROOT" --design "$DESIGN" --stem "$CASE"
  fi
  echo "FORMAL256_CASE_REUSE_PASS $DESIGN $CASE"
  exit 0
fi
set +e
"$WORK/simv" -no_save +CASE_FILE="$ROOT/cases/${CASE}_${DESIGN}_${VARIANT}.case" \
  +RESULT_CSV="$ROOT/results/$DESIGN/$NAME.csv" +EVENT_CSV=/dev/null \
  +LATENCY_CSV="$LOG/latency.csv" +FLIT_LATENCY_CSV=/dev/null \
  +V3_METRICS_CSV="$LOG/v3_metrics.csv" +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 \
  +STALL_TIMEOUT_NS=1200000 +HARD_TIMEOUT_NS=6000000 -l run.log > stdout.log 2>&1
rc=$?
set -e
if [[ -s "$ROOT/results/$DESIGN/$NAME.csv" && -s "$LOG/latency.csv" ]]; then
  if [[ "$VARIANT" == repeated ]]; then
    /soft/GNU/python3.12/bin/python3 "$ROOT/formal256_campaign.py" collect-case --root "$ROOT" --design "$DESIGN" --stem "$CASE" --repeated
  else
    /soft/GNU/python3.12/bin/python3 "$ROOT/formal256_campaign.py" collect-case --root "$ROOT" --design "$DESIGN" --stem "$CASE"
  fi
fi
test "$rc" -eq 0
grep -q '"errors":[[:space:]]*0' "$WORK/annotation_status.json"
! grep -Eiq 'Timing violation|TB_X_FAIL|TB_RESULT FAIL|TB_FATAL|TB_STALL_FAIL|TB_HARD_TIMEOUT' run.log stdout.log
grep -q 'TB_RESULT PASS' run.log
test -s "$ROOT/results/$DESIGN/$NAME.csv"
echo "FORMAL256_CASE_PASS $DESIGN $CASE"
