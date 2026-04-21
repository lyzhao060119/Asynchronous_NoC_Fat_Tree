param(
  [ValidateSet("uniform_unicast", "local_unicast", "cross_tile_unicast", "hotspot_unicast", "uniform_multicast", "mixed_unicast_multicast", "overlapping_multicast")]
  [string]$Pattern = "uniform_unicast",
  [int[]]$Seeds = @(12345, 22345, 32345),
  [int[]]$PacketGapsNs = @(0, 10, 20, 40),
  [string]$SeedsCsv = "",
  [string]$PacketGapsCsv = "",
  [ValidateRange(1, 4)]
  [int]$NumFlows = 4,
  [ValidateRange(0, 1000000)]
  [int]$AckDelayNs = 1,
  [ValidateRange(1, 64)]
  [int]$RectW = 1,
  [ValidateRange(1, 64)]
  [int]$RectH = 1,
  [ValidateRange(1, 8)]
  [int]$EdgeN = 2,
  [string]$GeneratedDirName = "generated",
  [ValidateRange(1, 2000000000)]
  [int]$WarmupNs = 100000,
  [ValidateRange(1, 2000000000)]
  [int]$MeasureNs = 500000,
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

$rawDir = Join-Path $root "sim\results\simulation\raw\perf_suite\$stamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$suiteCsv = Join-Path $csvDir "quadtree_and_mesh_perf_suite_$stamp.csv"

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

$headerWritten = $false
$regenThisRun = $Regenerate

if (-not [string]::IsNullOrWhiteSpace($SeedsCsv)) {
  $Seeds = ConvertTo-IntList $SeedsCsv
}
if (-not [string]::IsNullOrWhiteSpace($PacketGapsCsv)) {
  $PacketGapsNs = ConvertTo-IntList $PacketGapsCsv
}

if (($Seeds.Count -lt 1) -or ($PacketGapsNs.Count -lt 1)) {
  throw "[QAM-PERF-SUITE] Seeds and PacketGapsNs must both be non-empty."
}

foreach ($gapNs in $PacketGapsNs) {
  foreach ($seed in $Seeds) {
    $consoleLog = Join-Path $rawDir ("perf_suite_{0}_seed_{1}_gap_{2}.log" -f $Pattern, $seed, $gapNs)

    Write-Host ""
    Write-Host ("[QAM-PERF-SUITE] ==== pattern={0} seed={1} gap_ns={2} ====" -f $Pattern, $seed, $gapNs)

    $perfArgs = @(
      "-ExecutionPolicy", "Bypass",
      "-File", $runPerf,
      "-Mode", "batch",
      "-Pattern", $Pattern,
      "-Seed", "$seed",
      "-NumFlows", "$NumFlows",
      "-PacketGapNs", "$gapNs",
      "-AckDelayNs", "$AckDelayNs",
      "-RectW", "$RectW",
      "-RectH", "$RectH",
      "-EdgeN", "$EdgeN",
      "-GeneratedDirName", $GeneratedDirName,
      "-WarmupNs", "$WarmupNs",
      "-MeasureNs", "$MeasureNs"
    )
    if ($regenThisRun) {
      $perfArgs += "-Regenerate"
    }

    & powershell @perfArgs *>&1 |
      Tee-Object -FilePath $consoleLog |
      Tee-Object -Variable runOutput
    if ($LASTEXITCODE -ne 0) {
      throw "[QAM-PERF-SUITE] run_perf.ps1 failed for seed=$seed gap=$gapNs"
    }

    $summaryLine = $runOutput |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ -match '^\[QAM-PERF-PATH\] summary_csv=(.+)$' } |
      Select-Object -Last 1

    if (-not $summaryLine) {
      throw "[QAM-PERF-SUITE] could not find child summary csv path in $consoleLog"
    }

    $childSummary = $summaryLine -replace '^\[QAM-PERF-PATH\] summary_csv=', ''
    if (-not (Test-Path $childSummary)) {
      throw "[QAM-PERF-SUITE] child summary csv not found: $childSummary"
    }

    $childLines = Get-Content -Path $childSummary
    if ($childLines.Count -lt 2) {
      throw "[QAM-PERF-SUITE] child summary csv missing data row: $childSummary"
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
Write-Host "[QAM-PERF-SUITE] summary csv:"
Write-Host "  $suiteCsv"
Write-Host "[QAM-PERF-SUITE] suite console logs:"
Write-Host "  $rawDir"
Write-Host "[QAM-PERF-SUITE] all runs PASSED"
