param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [ValidateSet("uniform_unicast", "local_unicast", "cross_tile_unicast", "hotspot_unicast")]
  [string]$Pattern = "uniform_unicast",
  [int]$Seed = 12345,
  [ValidateRange(1, 4)]
  [int]$NumFlows = 4,
  [ValidateRange(0, 1000000)]
  [int]$PacketGapNs = 0,
  [ValidateRange(0, 1000000)]
  [int]$AckDelayNs = 1,
  [ValidateRange(1, 2000000000)]
  [int]$WarmupNs = 100000,
  [ValidateRange(1, 2000000000)]
  [int]$MeasureNs = 500000,
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function Resolve-FirstExisting([string[]]$Candidates, [string]$Label) {
  foreach ($path in $Candidates) {
    if (Test-Path $path) {
      return $path
    }
  }
  throw "Cannot find $Label. Checked: $($Candidates -join ', ')"
}

function Assert-LastExitCode([string]$Label) {
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

function Get-PatternCode([string]$PatternName) {
  switch ($PatternName) {
    "uniform_unicast" { return 0 }
    "local_unicast" { return 1 }
    "cross_tile_unicast" { return 2 }
    "hotspot_unicast" { return 3 }
    default { throw "Unsupported pattern: $PatternName" }
  }
}

function Parse-KeyValueLine([string]$Text) {
  $map = [ordered]@{}
  foreach ($segment in $Text.Split(',')) {
    $parts = $segment.Split('=', 2)
    if ($parts.Count -eq 2) {
      $map[$parts[0].Trim()] = $parts[1].Trim()
    }
  }
  return $map
}

function Escape-Csv([string]$Value) {
  '"' + $Value.Replace('"', '""') + '"'
}

$patternCode = Get-PatternCode $Pattern
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"

$runDir = Join-Path $root "sim\work\xsim\quadtree_and_mesh_perf\$runStamp"
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_perf_tb.sv"
$cfgFile = Join-Path $tbDir "quadtree_and_mesh_perf_cfg.vh"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"

$rawDir = Join-Path $root "sim\results\simulation\raw\perf\$runStamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$summaryCsv = Join-Path $csvDir "quadtree_and_mesh_perf_$runStamp.csv"
$logFile = Join-Path $rawDir ("perf_{0}_seed_{1}_flows_{2}_gap_{3}_ack_{4}.log" -f $Pattern, $Seed, $NumFlows, $PacketGapNs, $AckDelayNs)

$generatedNoC = Join-Path $root "generated\quadtree_and_mesh.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedNoC)) {
    sbt "runMain NoC.quadtree_and_mesh"
    Assert-LastExitCode "sbt runMain NoC.quadtree_and_mesh"
  }

  @(
    ('`define PERF_SEED {0}' -f $Seed),
    ('`define PERF_PATTERN {0}' -f $patternCode),
    ('`define PERF_NUM_FLOWS {0}' -f $NumFlows),
    ('`define PERF_PACKET_GAP_NS {0}' -f $PacketGapNs),
    ('`define PERF_ACK_DELAY_NS {0}' -f $AckDelayNs),
    ('`define PERF_WARMUP_NS {0}' -f $WarmupNs),
    ('`define PERF_MEASURE_NS {0}' -f $MeasureNs)
  ) | Set-Content -Path $cfgFile -Encoding Ascii

  & $instGen -OutFile $instVh
  Assert-LastExitCode "gen_dut_inst_vh.ps1"
} finally {
  Pop-Location
}

$delayFile = Resolve-FirstExisting @(
  (Join-Path $root "generated\DelayElement.v"),
  (Join-Path $root "src\main\resources\ASYNC\DelayElement.v")
) "DelayElement.v"

$mrgoFile = Resolve-FirstExisting @(
  (Join-Path $root "generated\MrGo.v"),
  (Join-Path $root "src\main\resources\ASYNC\MrGo.v")
) "MrGo.v"

$mutexFile = Resolve-FirstExisting @(
  (Join-Path $root "generated\Mutex2.v"),
  (Join-Path $root "src\main\resources\ASYNC\Mutex2.v")
) "Mutex2.v"

Push-Location $runDir
try {
  & xvlog --sv --work work `
    -i $tbDir `
    $generatedNoC `
    $delayFile `
    $mrgoFile `
    $mutexFile `
    $tbFile *>&1 | Tee-Object -FilePath $logFile -Append
  Assert-LastExitCode "xvlog"

  & xelab --timescale 1ns/1ps --debug typical -s quadtree_and_mesh_perf_tb_sim work.quadtree_and_mesh_perf_tb *>&1 | Tee-Object -FilePath $logFile -Append
  Assert-LastExitCode "xelab"

  $xsimArgs = @(
    "quadtree_and_mesh_perf_tb_sim",
    "--sv_seed", "$Seed"
  )

  if ($Mode -eq "batch") {
    & xsim @xsimArgs --runall *>&1 | Tee-Object -FilePath $logFile -Append
    Assert-LastExitCode "xsim batch"
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "Log file:"
    Write-Host "  $logFile"
    & xsim @xsimArgs --gui
    Assert-LastExitCode "xsim gui"
  }
} finally {
  Pop-Location
}

if ($Mode -eq "batch") {
  $csvMatch = Select-String -Path $logFile -Pattern '^\[QAM-PERF-CSV\]\s*(.+)$' | Select-Object -Last 1
  if (-not $csvMatch) {
    throw "Did not find [QAM-PERF-CSV] summary line in $logFile"
  }

  $values = Parse-KeyValueLine ($csvMatch.Line -replace '^\[QAM-PERF-CSV\]\s*', '')
  $header = @(
    "dut",
    "tb",
    "seed",
    "traffic_pattern",
    "packet_type",
    "packet_len",
    "rect_w",
    "rect_h",
    "offered_load",
    "num_flows",
    "packet_gap_ns",
    "ack_delay_ns",
    "warmup_ns",
    "measure_ns",
    "avg_latency_ns",
    "p95_latency_ns",
    "p99_latency_ns",
    "injected_flit_per_ns",
    "injected_pkt_per_ns",
    "throughput_flit_per_ns",
    "throughput_pkt_per_ns",
    "injected_packets",
    "injected_flits",
    "delivered_packets",
    "delivered_flits",
    "unexpected_core_flits",
    "unexpected_top_flits",
    "boundary_head_count",
    "pending_heads",
    "status",
    "log_file"
  )

  $row = foreach ($column in $header) {
    switch ($column) {
      "status" { "PASS" }
      "log_file" { Escape-Csv $logFile }
      default {
        if (-not $values.Contains($column)) {
          throw "Missing CSV field '$column' in log summary."
        }
        $value = [string]$values[$column]
        if ($value -match '[,\"]') { Escape-Csv $value } else { $value }
      }
    }
  }

  Set-Content -Path $summaryCsv -Encoding Ascii -Value ($header -join ",")
  Add-Content -Path $summaryCsv -Value ($row -join ",")

  Write-Host ""
  Write-Host "[QAM-PERF] summary csv:"
  Write-Host "  $summaryCsv"
  Write-Host "[QAM-PERF] raw log:"
  Write-Host "  $logFile"
  Write-Host "[QAM-PERF-PATH] summary_csv=$summaryCsv"
  Write-Host "[QAM-PERF-PATH] log_file=$logFile"
}
