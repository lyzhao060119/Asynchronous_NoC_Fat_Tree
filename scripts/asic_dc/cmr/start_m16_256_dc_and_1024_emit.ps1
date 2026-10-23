param(
    [ValidateSet('dc256','emit1024')][string]$Task,
    [string]$ResumeRunId = ''
)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $repo
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$run = if ($ResumeRunId) { $ResumeRunId } else { "${stamp}_m16_${Task}_tt_r1" }
$dir = Join-Path $repo "scripts/asic_dc/cmr/results/$run"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$env:ASYNC_PRIMITIVES = 'asic'
$env:CMR_RCU_MATCHED_DELAY_STEPS = '1'
$env:CMR_RCU_MATCHED_DELAY_UNIT_PS = '100'
$env:CMR_MESH_RCU_MATCHED_DELAY_UNIT_PS = '150'
$env:CMR_OPM_ACKIN_DELAY_UNIT_PS = '50'
$env:CMR_OPM_REQOUT_DELAY_STEPS = '1'
$env:CMR_OPM_REQOUT_DELAY_UNIT_PS = '50'
$env:CMR_OPM_REQOUT_BUFFER_STAGES = '1'
$env:CMR_OPM_TAIL_CAPTURE_DELAY_STEPS = '1'
$env:CMR_OPM_TAIL_CAPTURE_DELAY_UNIT_PS = '50'
$env:CMR_IPM_ACKOUT_GUARD_DELAY_UNIT_PS = '50'
$env:CMR_PATH_STATE_IMPL = 'dff'
$env:CMR_BYPASS_INTERLEVEL_FIFO = '1'
$env:CMR_USE_CIRCULAR_FIFO = '0'
if ($Task -eq 'dc256') {
    $env:CMR_HIER_KIND = 'prop_temp256_m16'
    $env:CMR_HIER_STITCH_RUN_ID = $run
    $env:CMR_FORCE_EMIT = '0'
    $env:CMR_LIBRARY_CORNER = 'tt0p8v25c'
    # Eight four-core children fill the 32-slot account budget after the
    # optional power-analysis job has been stopped.
    $env:CMR_HIER_CHILD_BATCH_SIZE = '8'
    $env:CMR_HIER_CHILD_BSUB = '-n 4'
    $env:CMR_APPLY_IPM_TIMING_RECIPE = '1'
    $env:CMR_HIER_SKIP_GLS = '1'
    if ($ResumeRunId) {
        $env:CMR_HIER_RESUME = '1'
        # Upload updated analysis/recipe scripts; the large emitted RTL is
        # hash-checked and skipped when it already matches.
        $env:CMR_HIER_SKIP_UPLOAD = '0'
        $driverLog = "$dir/driver_resume_${stamp}.log"
        $driverErr = "$dir/driver_resume_${stamp}.err"
    } else {
        $env:CMR_HIER_RESUME = '0'
        $env:CMR_HIER_SKIP_UPLOAD = '0'
        $driverLog = "$dir/driver.log"
        $driverErr = "$dir/driver.err"
    }
    & 'D:\anaconda\python.exe' -u scripts/asic_dc/cmr/run_remote_cmr_hier_dc.py 1> $driverLog 2> $driverErr
} else {
    $env:CMR_FORCE_EMIT = '1'
    $env:SBT_OPTS = '-Xms512M -Xmx12G -Xss4M -XX:+UseG1GC'
    & sbt -batch 'runMain NoC.CMR.PROPtemp1024M16Main' 1> "$dir/emit.log" 2> "$dir/emit.err"
}
$rc = $LASTEXITCODE
"task=$Task run=$run exit_code=$rc" | Set-Content "$dir/exit_status.txt"
exit $rc
