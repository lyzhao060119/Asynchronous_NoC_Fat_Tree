param([int]$EmitterPid)
$ErrorActionPreference = 'Stop'
$repoPath = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $repoPath
if (Get-Process -Id $EmitterPid -ErrorAction SilentlyContinue) {
    Wait-Process -Id $EmitterPid -ErrorAction SilentlyContinue
}
$auditPassed = $true
foreach ($kind in @('m16', 'mesh')) {
    & 'D:\anaconda\python.exe' scripts/asic_dc/cmr/check_split_emit.py "generated_cmr/split1024_20261020/$kind"
    if ($LASTEXITCODE -ne 0) { $auditPassed = $false }
}
if ($auditPassed) { Write-Output 'CMR_SPLIT_1024_BOTH_AUDIT_PASS' }
else { Write-Output 'CMR_SPLIT_1024_BOTH_AUDIT_FAIL'; exit 1 }
