#!/bin/bash
set -euo pipefail
export VCS_HOME=/soft/synopsys/vcs/V-2023.12
export PATH="$VCS_HOME/bin:$PATH"
cd "${1:?pilot directory}"
vcs -full64 -sverilog -timescale=1ns/1ps +neg_tchk +define+NTC+RECREM \
  /process/course_lib/t28hpc+/tcbn28hpcplusbwp12t30p140.v tb.sv -top tb -o simv -l compile.log
./simv -no_save -l run.log
grep -q 'Total errors:[[:space:]]*0' annotation.log
! grep -Eq 'SDFCOM_CFTC|SDFCOM_NL|Timing violation' annotation.log run.log
echo FORMAL256_SDF_PILOT_PASS
