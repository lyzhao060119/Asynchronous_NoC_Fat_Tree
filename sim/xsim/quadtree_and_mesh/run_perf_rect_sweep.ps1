param(
  [ValidateSet("auto", "light", "full")]
  [string]$TbVariant = "auto",
  [ValidateSet("uniform_multicast", "overlapping_multicast")]
  [string]$Pattern = "uniform_multicast",
  [int[]]$Seeds = @(12345, 22345),
  [string]$SeedsCsv = "",
  [int[]]$RectSizes = @(1, 2, 4, 8, 16),
  [string]$RectSizesCsv = "",
  [ValidateRange(1, 4)]
  [int]$NumFlows = 1,
  [ValidateRange(0, 1000000)]
  [int]$PacketGapNs = 20,
  [ValidateRange(0, 1000000)]
  [int]$AckDelayNs = 1,
  [ValidateRange(1, 8)]
  [int]$EdgeN = 2,
  [string]$GeneratedDirName = "generated",
  [string]$RunRoot = "",
  [ValidateRange(1, 2000000000)]
  [int]$WarmupNs = 20000,
  [ValidateRange(1, 2000000000)]
  [int]$MeasureNs = 50000,
  [ValidateRange(1, 2000000000)]
  [int]$HandshakeTimeoutNs = 500000,
  [ValidateRange(1, 2000000000)]
  [int]$GlobalTimeoutNs = 8000000,
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function ConvertTo-IntList([string]$Csv) {
  $values = @()
  foreach ($item in ($Csv -split '[,\s]+')) {
    if ([string]::IsNullOrWhiteSpace($item)) {
      continue
    }
    $values += [int]$item
  }
  return ,$values
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runPerf = Join-Path $PSScriptRoot "run_perf.ps1"
$stamp = Get-Date -Format "yyyyMMdd_HHmmss"

$rawDir = Join-Path $root "sim\results\simulation\raw\perf_rect_sweep\$stamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$suiteCsv = Join-Path $csvDir "quadtree_and_mesh_perf_rect_sweep_$stamp.csv"

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($SeedsCsv)) {
  $Seeds = ConvertTo-IntList $SeedsCsv
}
if (-not [string]::IsNullOrWhiteSpace($RectSizesCsv)) {
  $RectSizes = ConvertTo-IntList $RectSizesCsv
}

if (($Seeds.Count -lt 1) -or ($RectSizes.Count -lt 1)) {
  throw "[QAM-PERF-RECT] Seeds and RectSizes must both be non-empty."
}

$headerWritten = $false
$regenThisRun = $Regenerate

foreach ($rectSize in $RectSizes) {
  foreach ($seed in $Seeds) {
    $consoleLog = Join-Path $rawDir ("perf_rect_{0}_seed_{1}_rect_{2}.log" -f $Pattern, $seed, $rectSize)

    Write-Host ""
    Write-Host ("[QAM-PERF-RECT] ==== pattern={0} seed={1} rect={2}x{2} ====" -f $Pattern, $seed, $rectSize)

    $perfArgs = @(
      "-NoProfile",
      "-ExecutionPolicy", "Bypass",
      "-File", $runPerf,
      "-Mode", "batch",
      "-TbVariant", $TbVariant,
      "-Pattern", $Pattern,
      "-Seed", "$seed",
      "-NumFlows", "$NumFlows",
      "-RectW", "$rectSize",
      "-RectH", "$rectSize",
      "-PacketGapNs", "$PacketGapNs",
      "-AckDelayNs", "$AckDelayNs",
      "-EdgeN", "$EdgeN",
      "-GeneratedDirName", $GeneratedDirName,
      "-WarmupNs", "$WarmupNs",
      "-MeasureNs", "$MeasureNs",
      "-HandshakeTimeoutNs", "$HandshakeTimeoutNs",
      "-GlobalTimeoutNs", "$GlobalTimeoutNs"
    )
    if (-not [string]::IsNullOrWhiteSpace($RunRoot)) {
      $perfArgs += @("-RunRoot", $RunRoot)
    }
    if ($regenThisRun) {
      $perfArgs += "-Regenerate"
    }

    & powershell @perfArgs *>&1 |
      Tee-Object -FilePath $consoleLog |
      Tee-Object -Variable runOutput
    if ($LASTEXITCODE -ne 0) {
      throw "[QAM-PERF-RECT] run_perf.ps1 failed for seed=$seed rect=$rectSize"
    }

    $summaryLine = $runOutput |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ -match '^\[QAM-PERF-PATH\] summary_csv=(.+)$' } |
      Select-Object -Last 1

    if (-not $summaryLine) {
      throw "[QAM-PERF-RECT] could not find child summary csv path in $consoleLog"
    }

    $childSummary = $summaryLine -replace '^\[QAM-PERF-PATH\] summary_csv=', ''
    if (-not (Test-Path $childSummary)) {
      throw "[QAM-PERF-RECT] child summary csv not found: $childSummary"
    }

    $childLines = Get-Content -Path $childSummary
    if ($childLines.Count -lt 2) {
      throw "[QAM-PERF-RECT] child summary csv missing data row: $childSummary"
    }

    if (-not $headerWritten) {
      Set-Content -Path $suiteCsv -Encoding Ascii -Value $childLines[0]
      $headerWritten = $true
    }
    Add-Content -Path $suiteCsv -Value $childLines[1]
    $regenThisRun = $false
  }
}

Write-Host ""
Write-Host "[QAM-PERF-RECT] summary csv:"
Write-Host "  $suiteCsv"
Write-Host "[QAM-PERF-RECT] suite console logs:"
Write-Host "  $rawDir"
Write-Host "[QAM-PERF-RECT] all runs PASSED"
