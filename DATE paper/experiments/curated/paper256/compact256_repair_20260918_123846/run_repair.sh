#!/bin/bash
set -uo pipefail
ROOT=/home/ghy19/Asynchronous_Router_CMR; RUN=compact256_repair_20260918_123846_repair; WORK=/home/ghy19/Asynchronous_Router_CMR/sim/work/compact256_repair_20260918_123846_repair/sdf/PROP_temp256_m16; LOGROOT=/home/ghy19/Asynchronous_Router_CMR/logs/gls/compact256_repair_20260918_123846_repair
M16RAW=/home/ghy19/Asynchronous_Router_CMR/outputs/20260917_prop_temp256_m16_rcudel100_hier_dc_01/PROP_temp256_m16_post.v; M16SDF=/home/ghy19/Asynchronous_Router_CMR/outputs/20260917_prop_temp256_m16_rcudel100_hier_dc_01/PROP_temp256_m16.sdf; FMSIMV=/home/ghy19/Asynchronous_Router_CMR/sim/work/20260918_085618_prop_m16_mesh256_full_retry1/sdf/FM256/simv
mkdir -p "$WORK" "$LOGROOT" "$ROOT/results/$RUN/csv"
cat > "$WORK/sdf_boot.sv" <<EOF
module sdf_boot; initial begin \$sdf_annotate("/home/ghy19/Asynchronous_Router_CMR/outputs/20260917_prop_temp256_m16_rcudel100_hier_dc_01/PROP_temp256_m16.sdf", tb_noc_async_keycase.core.noc.dut, , "sdf_annotate.log", "MAXIMUM", ,); end endmodule
EOF
cat > "$WORK/filelist.f" <<EOF
/process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v
/home/ghy19/Asynchronous_Router_CMR/outputs/20260917_prop_temp256_m16_rcudel100_hier_dc_01/PROP_temp256_m16_post.v
$ROOT/scripts/experiments/$RUN/async_noc_scale_port_adapter.sv
$ROOT/scripts/experiments/$RUN/tb_noc_async_keycase.sv
$WORK/sdf_boot.sv
EOF
module load vcs 2>/dev/null || module load vcs/vcs2023.12 2>/dev/null || true
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd "$WORK" || exit 10
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +define+CMR_NOC_256 +define+CMR_NOC_PROP_TEMP_M16 -f filelist.f -top tb_noc_async_keycase -top sdf_boot -o simv -l "$LOGROOT/compile_m16.log"
if [[ $? -ne 0 || ! -x simv ]]; then echo REPAIR_COMPILE_FAIL; exit 11; fi
runm() {
  stem="$1"; monitor="$2"; log="$LOGROOT/$stem"; csv="$ROOT/results/$RUN/csv/sdf_$stem.csv"; mkdir -p "$log"; monarg=""
  [[ "$monitor" == yes ]] && monarg="+UPPER_MESH_CSV=$log/upper_mesh_accepted.csv"
  ./simv -no_save +CASE_FILE="$ROOT/sim/cases_network/$stem.case" +RESULT_CSV="$csv" +EVENT_CSV="$log/events.csv" +LATENCY_CSV="$log/latency.csv" +FLIT_LATENCY_CSV="$log/flit_latency.csv" +V3_METRICS_CSV="$log/v3_metrics.csv" +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +STALL_TIMEOUT_NS=1200000 +HARD_TIMEOUT_NS=6000000 $monarg -l "$log/run.log" > "$log/stdout.log" 2>&1
  rc=$?; cp sdf_annotate.log "$log/sdf_annotate.log" 2>/dev/null || true
  if [[ $rc -eq 0 ]] && grep -q 'Total errors:[[:space:]]*0' "$log/sdf_annotate.log" && grep -q 'TB_RESULT PASS' "$log/run.log" && ! grep -Eiq 'Timing violation|TB_X_FAIL|TB_RESULT FAIL|TB_FATAL|TB_STALL_FAIL|TB_HARD_TIMEOUT' "$log/run.log" "$log/stdout.log"; then echo CASE_ACCEPTED "$stem"; return 0; fi
  echo CASE_FAILED "$stem" rc="$rc"; return 1
}
smoke=1
for stem in MC-F16-2TILE_compact256_repair_20260918_123846_m5_native_PROP_temp256_m16_top0 MC-F16-2TILE_compact256_repair_20260918_123846_m5_repeated_PROP_temp256_m16_top0; do runm "$stem" no || smoke=0; done
if [[ $smoke -eq 1 ]]; then for stem in LOCALITY256_compact256_repair_20260918_123846_m120_p0p24705882352941178_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p5_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p75_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p9_PROP_temp256_m16_top0 MC-F16-2TILE_compact256_repair_20260918_123846_m20_native_PROP_temp256_m16_top0 MC-F16-2TILE_compact256_repair_20260918_123846_m20_repeated_PROP_temp256_m16_top0 MC-F16-2TILE_compact256_repair_20260918_123846_m40_native_PROP_temp256_m16_top0 MC-F16-2TILE_compact256_repair_20260918_123846_m40_repeated_PROP_temp256_m16_top0; do mon=no; [[ "$stem" == LOCALITY256_* ]] && mon=yes; runm "$stem" "$mon" || true; done
else
 echo F16_M20_M40_SKIPPED_M5_SMOKE_FAILED
 for stem in LOCALITY256_compact256_repair_20260918_123846_m120_p0p24705882352941178_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p5_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p75_PROP_temp256_m16_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p9_PROP_temp256_m16_top0; do runm "$stem" yes || true; done
fi
# Existing FM simv; SDF must match its compiled annotation wrapper.
cat > "$WORK/fm_sdf_boot.sv" <<EOF
module fm_sdf_boot; initial begin $sdf_annotate("/home/ghy19/Asynchronous_Router_CMR/outputs/20260915_122347_cmr_mesh256_hier_dc/CMRMeshNoC.sdf", tb_noc_async_keycase.core.noc.dut, , "sdf_annotate.log", "MAXIMUM", ,); end endmodule
EOF
# Its original simv already has the old sdf_boot. Confirm annotation is for FlatMesh by using that compiled path's report.
for stem in LOCALITY256_compact256_repair_20260918_123846_m120_p0p24705882352941178_FM256_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p5_FM256_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p75_FM256_top0 LOCALITY256_compact256_repair_20260918_123846_m120_p0p9_FM256_top0; do
 log="$LOGROOT/$stem"; csv="$ROOT/results/$RUN/csv/sdf_$stem.csv"; mkdir -p "$log"
 (cd /home/ghy19/Asynchronous_Router_CMR/sim/work/20260918_085618_prop_m16_mesh256_full_retry1/sdf/FM256 && ./simv -no_save +CASE_FILE="$ROOT/sim/cases_network/$stem.case" +RESULT_CSV="$csv" +EVENT_CSV="$log/events.csv" +LATENCY_CSV="$log/latency.csv" +FLIT_LATENCY_CSV="$log/flit_latency.csv" +V3_METRICS_CSV="$log/v3_metrics.csv" +CASE_TICK_NS=1 +RX_CAPTURE_NS=0.1 +STALL_TIMEOUT_NS=1200000 +HARD_TIMEOUT_NS=6000000 -l "$log/run.log" > "$log/stdout.log" 2>&1)
 rc=$?; cp /home/ghy19/Asynchronous_Router_CMR/sim/work/20260918_085618_prop_m16_mesh256_full_retry1/sdf/FM256/sdf_annotate.log "$log/sdf_annotate.log" 2>/dev/null || true
 if [[ $rc -eq 0 ]] && grep -q 'Total errors:[[:space:]]*0' "$log/sdf_annotate.log" && grep -q 'TB_RESULT PASS' "$log/run.log" && ! grep -Eiq 'Timing violation|TB_X_FAIL|TB_RESULT FAIL|TB_FATAL|TB_STALL_FAIL|TB_HARD_TIMEOUT' "$log/run.log" "$log/stdout.log"; then echo CASE_ACCEPTED "$stem"; else echo CASE_FAILED "$stem" rc="$rc"; fi
done
echo CMR_REPAIR_RUN_FINISHED
