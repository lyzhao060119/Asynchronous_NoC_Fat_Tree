param(
  [ValidateSet("uniform_unicast", "local_unicast", "cross_tile_unicast", "hotspot_unicast", "uniform_multicast", "mixed_unicast_multicast", "overlapping_multicast")]
  [string]$Pattern = "uniform_multicast",
  [int[]]$Seeds = @(12345, 22345),
  [string]$SeedsCsv = "",
  [int[]]$AckDelaysNs = @(1, 5, 10, 20),
  [string]$AckDelaysCsv = "",
  [ValidateRange(1, 4)]
  [int]$NumFlows = 1,
  [ValidateRange(0, 1000000)]
  [int]$PacketGapNs = 20,
  [ValidateRange(1, 16)]
  [int]$RectW = 4,
  [ValidateRange(1, 16)]
  [int]$RectH = 4,
  [ValidateRange(1, 2000000000)]
  [int]$WarmupNs = 20000,
  [ValidateRange(1, 2000000000)]
  [int]$MeasureNs = 50000,
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

$rawDir = Join-Path $root "sim\results\simulation\raw\perf_ack_sweep\$stamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$suiteCsv = Join-Path $csvDir "quadtree_and_mesh_perf_ack_sweep_$stamp.csv"

New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

if (-not [string]::IsNullOrWhiteSpace($SeedsCsv)) {
  $Seeds = ConvertTo-IntList $SeedsCsv
}
if (-not [string]::IsNullOrWhiteSpace($AckDelaysCsv)) {
  $AckDelaysNs = ConvertTo-IntList $AckDelaysCsv
}

if (($Seeds.Count -lt 1) -or ($AckDelaysNs.Count -lt 1)) {
  throw "[QAM-PERF-ACK] Seeds and AckDelaysNs must both be non-empty."
}

$headerWritten = $false
$regenThisRun = $Regenerate

foreach ($ackDelayNs in $AckDelaysNs) {
  foreach ($seed in $Seeds) {
    $consoleLog = Join-Path $rawDir ("perf_ack_{0}_seed_{1}_ack_{2}.log" -f $Pattern, $seed, $ackDelayNs)

    Write-Host ""
    Write-Host ("[QAM-PERF-ACK] ==== pattern={0} seed={1} ack_delay_ns={2} ====" -f $Pattern, $seed, $ackDelayNs)

    $perfArgs = @(
      "-ExecutionPolicy", "Bypass",
      "-File", $runPerf,
      "-Mode", "batch",
      "-Pattern", $Pattern,
      "-Seed", "$seed",
      "-NumFlows", "$NumFlows",
      "-PacketGapNs", "$PacketGapNs",
      "-AckDelayNs", "$ackDelayNs",
      "-RectW", "$RectW",
      "-RectH", "$RectH",
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
      throw "[QAM-PERF-ACK] run_perf.ps1 failed for seed=$seed ack_delay_ns=$ackDelayNs"
    }

    $summaryLine = $runOutput |
      ForEach-Object { [string]$_ } |
      Where-Object { $_ -match '^\[QAM-PERF-PATH\] summary_csv=(.+)$' } |
      Select-Object -Last 1

    if (-not $summaryLine) {
      throw "[QAM-PERF-ACK] could not find child summary csv path in $consoleLog"
    }

    $childSummary = $summaryLine -replace '^\[QAM-PERF-PATH\] summary_csv=', ''
    if (-not (Test-Path $childSummary)) {
      throw "[QAM-PERF-ACK] child summary csv not found: $childSummary"
    }

    $childLines = Get-Content -Path $childSummary
    if ($childLines.Count -lt 2) {
      throw "[QAM-PERF-ACK] child summary csv missing data row: $childSummary"
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
Write-Host "[QAM-PERF-ACK] summary csv:"
Write-Host "  $suiteCsv"
Write-Host "[QAM-PERF-ACK] suite console logs:"
Write-Host "  $rawDir"
Write-Host "[QAM-PERF-ACK] all runs PASSED"
