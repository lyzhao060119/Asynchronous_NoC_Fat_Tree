param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [ValidateSet("uniform_unicast", "local_unicast", "cross_tile_unicast", "hotspot_unicast", "uniform_multicast", "mixed_unicast_multicast", "overlapping_multicast")]
  [string]$Pattern = "uniform_unicast",
  [int]$Seed = 12345,
  [ValidateRange(1, 4)]
  [int]$NumFlows = 4,
  [ValidateRange(0, 1000000)]
  [int]$PacketGapNs = 0,
  [ValidateRange(0, 1000000)]
  [int]$AckDelayNs = 1,
  [ValidateRange(1, 64)]
  [int]$RectW = 1,
  [ValidateRange(1, 64)]
  [int]$RectH = 1,
  [ValidateRange(1, 8)]
  [int]$EdgeN = 2,
  [string]$GeneratedDirName = "generated",
  [string]$RunRoot = "",
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

function Resolve-DutTopFile([string]$GeneratedDir) {
  $candidates = @(
    (Join-Path $GeneratedDir "quadtree_and_mesh.v"),
    (Join-Path $GeneratedDir "quadtree_and_mesh.sv")
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) {
      return $path
    }
  }
  return $candidates[0]
}

function Test-IsMonolithicTopFile([string]$TopFile) {
  $moduleMatches = Select-String -Path $TopFile -Pattern '^\s*module\s+' | Select-Object -First 2
  return (($moduleMatches | Measure-Object).Count -ge 2)
}

function Get-DeduplicatedGeneratedSources([string]$GeneratedDir) {
  $candidates = Get-ChildItem -Path $GeneratedDir -File |
    Where-Object {
      (($_.Extension -eq ".v") -or ($_.Extension -eq ".sv")) -and
      ($_.Name -notin @("DelayElement.v", "DelayElement.sv", "Mutex2.v", "Mutex2.sv", "MrGo.v", "MrGo.sv"))
    } |
    Sort-Object @{ Expression = { $_.BaseName } }, @{ Expression = { if ($_.Extension -eq ".sv") { 0 } else { 1 } } }, Name

  $selected = [System.Collections.Generic.List[string]]::new()
  $seenBaseNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($source in $candidates) {
    if ($seenBaseNames.Add($source.BaseName)) {
      $selected.Add($source.FullName)
    }
  }
  return $selected.ToArray()
}

function Get-DutSourceFiles([string]$GeneratedDir, [string]$TopFile) {
  if (Test-Path $TopFile) {
    if (Test-IsMonolithicTopFile -TopFile $TopFile) {
      return ,$TopFile
    }
    return Get-DeduplicatedGeneratedSources -GeneratedDir $GeneratedDir
  }

  $sources = Get-DeduplicatedGeneratedSources -GeneratedDir $GeneratedDir
  if ($sources.Count -eq 0) {
    throw "Did not find DUT Verilog sources in $GeneratedDir"
  }

  return ,$sources
}

function Test-DutSourcesExist([string]$GeneratedDir, [string]$TopFile) {
  if (Test-Path $TopFile) {
    return $true
  }
  if (-not (Test-Path $GeneratedDir)) {
    return $false
  }
  $sources = Get-DeduplicatedGeneratedSources -GeneratedDir $GeneratedDir
  return ($sources.Count -gt 0)
}

function New-VerificationIncludeStubs([string[]]$SourceFiles, [string]$StubDir) {
  New-Item -ItemType Directory -Force -Path $StubDir | Out-Null

  $includePattern = '^\s*`include\s+"([^"]*Verification[^"]*\.sv)"'
  $knownIncludes = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
  foreach ($sourceFile in $SourceFiles) {
    Get-Content $sourceFile | ForEach-Object {
      if ($_ -match $includePattern) {
        $includeName = $matches[1]
        if ($knownIncludes.Add($includeName)) {
          $stubPath = Join-Path $StubDir $includeName
          if (-not (Test-Path $stubPath)) {
            Set-Content -Path $stubPath -Encoding Ascii -Value @(
              "// Auto-generated empty verification stub for Vivado simulation."
              "// The emitted DUT references this include even when no verification logic is present."
            )
          }
        }
      }
    }
  }
}

function Get-DutTopLaneCount([string]$TopFile, [int]$Fallback = 4) {
  if (-not (Test-Path $TopFile)) {
    return $Fallback
  }

  $maxLane = -1
  $lanePattern = 'io_East_fromPEs_\d+_(\d+)_HS_Req'
  Get-Content $TopFile | ForEach-Object {
    if ($_ -match $lanePattern) {
      $laneIdx = [int]$matches[1]
      if ($laneIdx -gt $maxLane) {
        $maxLane = $laneIdx
      }
    }
  }

  if ($maxLane -lt 0) {
    return $Fallback
  }
  return ($maxLane + 1)
}

function Resolve-JavaHome() {
  if (-not [string]::IsNullOrWhiteSpace($env:JAVA_HOME)) {
    $javaExe = Join-Path $env:JAVA_HOME "bin\java.exe"
    if (Test-Path $javaExe) {
      return $env:JAVA_HOME
    }
  }

  $javacCmd = Get-Command javac -ErrorAction SilentlyContinue
  if ($javacCmd) {
    return Split-Path -Parent (Split-Path -Parent $javacCmd.Source)
  }

  $javaCandidates = @(
    "C:\Program Files\Eclipse Adoptium\jdk-21.0.8.9-hotspot",
    "C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot"
  )
  foreach ($candidate in $javaCandidates) {
    if (Test-Path (Join-Path $candidate "bin\java.exe")) {
      return $candidate
    }
  }

  throw "Could not resolve a valid JAVA_HOME for sbt."
}

function Resolve-FirtoolBinary() {
  $cachedRoot = Join-Path $env:LOCALAPPDATA "org.chipsalliance\llvm-firtool\cache"
  if (Test-Path $cachedRoot) {
    $cachedBins = Get-ChildItem -Path $cachedRoot -Recurse -Filter "firtool" -File -ErrorAction SilentlyContinue |
      Sort-Object FullName -Descending
    if ($cachedBins.Count -gt 0) {
      return $cachedBins[0].FullName
    }
  }
  throw "Could not resolve firtool from the local cache."
}

function Convert-FirToSplitSv([string]$FirFile, [string]$OutDir) {
  if (-not (Test-Path $FirFile)) {
    throw "Cannot convert missing FIR file: $FirFile"
  }

  $firtool = Resolve-FirtoolBinary
  $firtoolStdout = Join-Path $runDir "firtool_stdout.log"
  $firtoolStderr = Join-Path $runDir "firtool_stderr.log"
  Remove-Item -LiteralPath $firtoolStdout, $firtoolStderr -ErrorAction SilentlyContinue

  $args = @(
    $FirFile,
    "--format=fir",
    "--split-verilog",
    "-o=$OutDir",
    "-O=debug",
    "--disable-opt",
    "--disable-all-randomization",
    "--strip-debug-info",
    "--disable-aggressive-merge-connections",
    "--mlir-disable-threading"
  )

  $proc = Start-Process -FilePath $firtool `
    -ArgumentList $args `
    -NoNewWindow `
    -Wait `
    -PassThru `
    -RedirectStandardOutput $firtoolStdout `
    -RedirectStandardError $firtoolStderr

  if ($proc.ExitCode -ne 0) {
    throw "firtool failed with exit code $($proc.ExitCode). See $firtoolStdout and $firtoolStderr"
  }
}

function Get-PatternCode([string]$PatternName) {
  switch ($PatternName) {
    "uniform_unicast" { return 0 }
    "local_unicast" { return 1 }
    "cross_tile_unicast" { return 2 }
    "hotspot_unicast" { return 3 }
    "uniform_multicast" { return 4 }
    "mixed_unicast_multicast" { return 5 }
    "overlapping_multicast" { return 6 }
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

$resolvedRunRoot = if ([string]::IsNullOrWhiteSpace($RunRoot)) { Join-Path $root ".xsim_perf" } else { $RunRoot }
$runDir = Join-Path $resolvedRunRoot $runStamp
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbModule = if ($EdgeN -gt 2) { "quadtree_and_mesh_perf_1024_light_tb" } else { "quadtree_and_mesh_perf_tb" }
$tbFile = Join-Path $tbDir ($tbModule + ".sv")
$cfgFile = Join-Path $tbDir "quadtree_and_mesh_perf_cfg.vh"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"

$rawDir = Join-Path $root "sim\results\simulation\raw\perf\$runStamp"
$csvDir = Join-Path $root "sim\results\simulation\csv"
$summaryCsv = Join-Path $csvDir "quadtree_and_mesh_perf_$runStamp.csv"
$logFile = Join-Path $rawDir ("perf_{0}_seed_{1}_flows_{2}_gap_{3}_ack_{4}.log" -f $Pattern, $Seed, $NumFlows, $PacketGapNs, $AckDelayNs)

$generatedDir = Join-Path $root $GeneratedDirName
$generatedNoC = Resolve-DutTopFile -GeneratedDir $generatedDir
$dutSources = @()
$stubIncludeDir = Join-Path $runDir "verification_stubs"
$topLane = 4
$useEmbeddedBlackboxes = $false

New-Item -ItemType Directory -Force -Path $runDir | Out-Null
New-Item -ItemType Directory -Force -Path $rawDir | Out-Null
New-Item -ItemType Directory -Force -Path $csvDir | Out-Null

if (($EdgeN -gt 2) -and ($Pattern -notin @("uniform_unicast", "local_unicast", "cross_tile_unicast", "hotspot_unicast"))) {
  throw "[QAM-PERF] The lightweight 1024-node Vivado testbench currently supports only uniform/local/cross_tile/hotspot unicast."
}

Push-Location $root
try {
  $env:JAVA_HOME = Resolve-JavaHome
  if ($env:Path -notlike "*$($env:JAVA_HOME)\bin*") {
    $env:Path = "$($env:JAVA_HOME)\bin;$($env:Path)"
  }
  if ($EdgeN -gt 2) {
    $heapOpts = "-Xms2g -Xmx16g -Xss8m -XX:ReservedCodeCacheSize=1024m"
    $env:SBT_OPTS = $heapOpts
    $env:JAVA_TOOL_OPTIONS = $heapOpts
  }

  if ($Regenerate -or -not (Test-DutSourcesExist -GeneratedDir $generatedDir -TopFile $generatedNoC)) {
    $targetDirArg = $GeneratedDirName
    if ($EdgeN -eq 2) {
      sbt "runMain NoC.quadtree_and_mesh --verify-256 --target-dir $targetDirArg"
      Assert-LastExitCode "sbt runMain NoC.quadtree_and_mesh --verify-256"
    } elseif ($EdgeN -eq 4) {
      sbt "runMain NoC.quadtree_and_mesh --paper-1024 --target-dir $targetDirArg"
      Assert-LastExitCode "sbt runMain NoC.quadtree_and_mesh --paper-1024"
    } else {
      sbt "runMain NoC.quadtree_and_mesh --quad-num-x $EdgeN --quad-num-y $EdgeN --target-dir $targetDirArg"
      Assert-LastExitCode "sbt runMain NoC.quadtree_and_mesh custom edge size"
    }

    if ($EdgeN -gt 2) {
      Convert-FirToSplitSv -FirFile (Join-Path $generatedDir "quadtree_and_mesh.fir") -OutDir $generatedDir
    }
  }
  $dutSources = @(Get-DutSourceFiles -GeneratedDir $generatedDir -TopFile $generatedNoC)
  $topLane = Get-DutTopLaneCount -TopFile $generatedNoC -Fallback 4
  $useEmbeddedBlackboxes = ($dutSources.Count -eq 1) -and (Test-IsMonolithicTopFile -TopFile $dutSources[0])

  @(
    ('`define PERF_SEED {0}' -f $Seed),
    ('`define PERF_PATTERN {0}' -f $patternCode),
    ('`define PERF_NUM_FLOWS {0}' -f $NumFlows),
    ('`define PERF_PACKET_GAP_NS {0}' -f $PacketGapNs),
    ('`define PERF_ACK_DELAY_NS {0}' -f $AckDelayNs),
    ('`define PERF_RECT_W {0}' -f $RectW),
    ('`define PERF_RECT_H {0}' -f $RectH),
    ('`define PERF_EDGE_N {0}' -f $EdgeN),
    ('`define PERF_TOP_LANE {0}' -f $topLane),
    ('`define PERF_WARMUP_NS {0}' -f $WarmupNs),
    ('`define PERF_MEASURE_NS {0}' -f $MeasureNs)
  ) | Set-Content -Path $cfgFile -Encoding Ascii

  & powershell -NoProfile -ExecutionPolicy Bypass -File $instGen -OutFile $instVh -EdgeN $EdgeN -TopLane $topLane
  Assert-LastExitCode "gen_dut_inst_vh.ps1"
} finally {
  Pop-Location
}

$delayFile = Resolve-FirstExisting @(
  (Join-Path $generatedDir "DelayElement.sv"),
  (Join-Path $generatedDir "DelayElement.v"),
  (Join-Path $root "generated\DelayElement.v"),
  (Join-Path $root "src\main\resources\ASYNC\DelayElement.v")
) "DelayElement.v"

$mrgoFile = Resolve-FirstExisting @(
  (Join-Path $generatedDir "MrGo.sv"),
  (Join-Path $generatedDir "MrGo.v"),
  (Join-Path $root "generated\MrGo.v"),
  (Join-Path $root "src\main\resources\ASYNC\MrGo.v")
) "MrGo.v"

$mutexFile = Resolve-FirstExisting @(
  (Join-Path $generatedDir "Mutex2.sv"),
  (Join-Path $generatedDir "Mutex2.v"),
  (Join-Path $root "generated\Mutex2.v"),
  (Join-Path $root "src\main\resources\ASYNC\Mutex2.v")
) "Mutex2.v"

Push-Location $runDir
try {
  $oldTemp = $env:TEMP
  $oldTmp = $env:TMP
  $env:TEMP = $runDir
  $env:TMP = $runDir
  Remove-Item -LiteralPath "xsim.dir" -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $stubIncludeDir -Recurse -Force -ErrorAction SilentlyContinue

  $xvlogFileList = Join-Path $runDir "xvlog_sources.f"
  $xvlogSources = [System.Collections.Generic.List[string]]::new()
  foreach ($source in $dutSources) {
    $xvlogSources.Add([string]$source)
  }
  if (-not $useEmbeddedBlackboxes) {
    $xvlogSources.Add([string]$delayFile)
    $xvlogSources.Add([string]$mrgoFile)
    $xvlogSources.Add([string]$mutexFile)
  }
  $xvlogSources.Add([string]$tbFile)
  $xvlogSources | Set-Content -Path $xvlogFileList -Encoding Ascii

  New-VerificationIncludeStubs -SourceFiles $dutSources -StubDir $stubIncludeDir

  & xvlog --sv --work work `
    -i $generatedDir `
    -i $stubIncludeDir `
    -i $tbDir `
    -f $xvlogFileList *>&1 | Tee-Object -FilePath $logFile -Append
  Assert-LastExitCode "xvlog"

  $xelabArgs = @(
    "--timescale", "1ns/1ps",
    "--debug", "off",
    "--mt", "off"
  )
  if ($EdgeN -gt 2) {
    $xelabArgs += @(
      "--O0",
      "--Odisable_cdfg",
      "--Odisable_unused_removal",
      "--Odisable_process_opt",
      "--nosignalhandlers"
    )
  }
  $xelabArgs += @(
    "-s", ($tbModule + "_sim"),
    ("work." + $tbModule)
  )

  & xelab @xelabArgs *>&1 | Tee-Object -FilePath $logFile -Append
  Assert-LastExitCode "xelab"

  $xsimArgs = @(
    ($tbModule + "_sim"),
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
  $env:TEMP = $oldTemp
  $env:TMP = $oldTmp
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
    "network_nodes",
    "edge_n",
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
    "avg_completion_latency_ns",
    "p95_completion_latency_ns",
    "p99_completion_latency_ns",
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
    "boundary_tail_count",
    "pending_packets",
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
