param(
  [int[]]$Seeds = @(12345, 22345, 32345, 42345, 52345),
  [string]$RunRoot = "",
  [int]$Cases = 24,
  [ValidateRange(1, 3)]
  [int]$MaxPkts = 3,
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function Add-CsvRow {
  param(
    [string]$Path,
    [string]$Seed,
    [string]$Cases,
    [string]$MaxPkts,
    [string]$Status,
    [string]$ExitCode,
    [string]$ElapsedSec,
    [string]$LogFile
  )

  $escapedLog = '"' + $LogFile.Replace('"', '""') + '"'
  Add-Content -Path $Path -Value "$Seed,$Cases,$MaxPkts,$Status,$ExitCode,$ElapsedSec,$escapedLog"
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runRand = Join-Path $PSScriptRoot "run_rand.ps1"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$rawDir = Join-Path $root "sim\results\simulation\raw\rand_correctness\$stamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$summaryCsv = Join-Path $csvDir "quadtree_and_mesh_rand_correctness_$stamp.csv"

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

Set-Content -Path $summaryCsv -Encoding Ascii -Value "seed,cases,max_pkts,status,exit_code,elapsed_sec,log_file"

$failCount = 0
$regenThisRun = $Regenerate
$reuseRunDir = ""

Write-Host "[RAND-SUITE] building reusable snapshot..."
$buildArgs = @(
  "-ExecutionPolicy", "Bypass",
  "-File", $runRand,
  "-Mode", "batch",
  "-RunRoot", $RunRoot,
  "-Seed", "$($Seeds[0])",
  "-Cases", "$Cases",
  "-MaxPkts", "$MaxPkts",
  "-BuildOnly"
)
if ($regenThisRun) {
  $buildArgs += "-Regenerate"
}

& powershell @buildArgs *>&1 | Tee-Object -Variable buildOutput
if ($LASTEXITCODE -ne 0) {
  throw "[RAND-SUITE] snapshot build failed"
}

$runDirLine = $buildOutput |
  ForEach-Object { [string]$_ } |
  Where-Object { $_ -match '^\[QAM-RAND-PATH\] run_dir=(.+)$' } |
  Select-Object -Last 1
if (-not $runDirLine) {
  throw "[RAND-SUITE] could not find reusable run_dir in build output"
}
$reuseRunDir = $runDirLine -replace '^\[QAM-RAND-PATH\] run_dir=', ''
Write-Host "[RAND-SUITE] reusable run_dir:"
Write-Host "  $reuseRunDir"
$regenThisRun = $false

foreach ($seed in $Seeds) {
  $logFile = Join-Path $rawDir ("seed_{0}_cases_{1}_maxpkts_{2}.log" -f $seed, $Cases, $MaxPkts)
  $exitCode = 0
  $status = "PASS"
  $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

  Write-Host ""
  Write-Host ("[RAND-SUITE] ==== seed={0} cases={1} maxPkts={2} ====" -f $seed, $Cases, $MaxPkts)

  try {
    $randArgs = @(
      "-ExecutionPolicy", "Bypass",
      "-File", $runRand,
      "-Mode", "batch",
      "-ReuseRunDir", $reuseRunDir,
      "-RunRoot", $RunRoot,
      "-Seed", "$seed",
      "-Cases", "$Cases",
      "-MaxPkts", "$MaxPkts"
    )

    & powershell @randArgs *>&1 | Tee-Object -FilePath $logFile
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
      throw "run_rand.ps1 failed with exit code $exitCode"
    }
  } catch {
    $status = "FAIL"
    $failCount = $failCount + 1
    $_ | Out-File -FilePath $logFile -Append
    if ($exitCode -eq 0) {
      $exitCode = 1
    }
  } finally {
    $stopwatch.Stop()
    Add-CsvRow `
      -Path $summaryCsv `
      -Seed "$seed" `
      -Cases "$Cases" `
      -MaxPkts "$MaxPkts" `
      -Status $status `
      -ExitCode "$exitCode" `
      -ElapsedSec ("{0:F3}" -f $stopwatch.Elapsed.TotalSeconds) `
      -LogFile $logFile
  }

  Write-Host ("[RAND-SUITE] seed={0} status={1} elapsed={2:F3}s" -f $seed, $status, $stopwatch.Elapsed.TotalSeconds)
}

Write-Host ""
Write-Host "[RAND-SUITE] summary csv:"
Write-Host "  $summaryCsv"
Write-Host "[RAND-SUITE] raw logs:"
Write-Host "  $rawDir"

if ($failCount -ne 0) {
  throw "[RAND-SUITE] completed with $failCount failing seed(s)."
}

Write-Host "[RAND-SUITE] all seeds PASSED"
