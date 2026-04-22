param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [string]$RunRoot = "",
  [string]$ReuseRunDir = "",
  [int]$Seed = 1379260429,
  [int]$Cases = 24,
  [ValidateRange(1, 3)]
  [int]$MaxPkts = 3,
  [ValidateRange(1, 8)]
  [int]$EdgeN = 2,
  [string]$GeneratedDirName = "generated",
  [switch]$BuildOnly,
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

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

function Assert-XelabSucceededOrSnapshotReady([string]$SnapshotName) {
  if ($LASTEXITCODE -eq 0) {
    return
  }

  $snapshotDir = Join-Path "xsim.dir" $SnapshotName
  $kernelExe = Join-Path $snapshotDir "xsimk.exe"
  $snapshotReloc = Join-Path $snapshotDir "xsim.reloc"

  if ((Test-Path $kernelExe) -and (Test-Path $snapshotReloc)) {
    Write-Warning "xelab returned exit code $LASTEXITCODE after building snapshot '$SnapshotName'. Continuing because the snapshot artifacts are present."
    return
  }

  throw "xelab failed with exit code $LASTEXITCODE"
}

function Resolve-DutTopFile([string]$GeneratedDir) {
  $candidates = @(
    (Join-Path $GeneratedDir "quadtree_and_mesh.sv"),
    (Join-Path $GeneratedDir "quadtree_and_mesh.v")
  )
  foreach ($path in $candidates) {
    if (Test-Path $path) {
      return $path
    }
  }
  return $candidates[0]
}

function Test-IsMonolithicTopFile([string]$TopFile) {
  if (-not (Test-Path $TopFile)) {
    return $false
  }
  $moduleMatches = Select-String -Path $TopFile -Pattern '^\s*module\s+' | Select-Object -First 2
  return (($moduleMatches | Measure-Object).Count -ge 2)
}

function Test-ContainsModuleDefinition([string]$SourceFile, [string]$ModuleName) {
  if (-not (Test-Path $SourceFile)) {
    return $false
  }
  $pattern = '^\s*module\s+' + [regex]::Escape($ModuleName) + '(\s|#|\()'
  return [bool](Select-String -Path $SourceFile -Pattern $pattern -Quiet)
}

function Test-ProvidesAllModules([string[]]$SourceFiles, [string[]]$ModuleNames) {
  foreach ($moduleName in $ModuleNames) {
    $found = $false
    foreach ($sourceFile in $SourceFiles) {
      if (Test-ContainsModuleDefinition -SourceFile $sourceFile -ModuleName $moduleName) {
        $found = $true
        break
      }
    }
    if (-not $found) {
      return $false
    }
  }
  return $true
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

function Get-DutCoreCount([string]$TopFile, [int]$Fallback = 64) {
  if (-not (Test-Path $TopFile)) {
    return $Fallback
  }

  $maxCore = -1
  $corePattern = 'io_inputs_\d+_(\d+)_HS_Req'
  Get-Content $TopFile | ForEach-Object {
    if ($_ -match $corePattern) {
      $coreIdx = [int]$matches[1]
      if ($coreIdx -gt $maxCore) {
        $maxCore = $coreIdx
      }
    }
  }

  if ($maxCore -lt 0) {
    return $Fallback
  }
  return ($maxCore + 1)
}

function Get-DutEdgeCount([string]$TopFile, [int]$Fallback = 2) {
  if (-not (Test-Path $TopFile)) {
    return $Fallback
  }

  $maxEdge = -1
  $edgePattern = 'io_East_fromPEs_(\d+)_\d+_HS_Req'
  Get-Content $TopFile | ForEach-Object {
    if ($_ -match $edgePattern) {
      $edgeIdx = [int]$matches[1]
      if ($edgeIdx -gt $maxEdge) {
        $maxEdge = $edgeIdx
      }
    }
  }

  if ($maxEdge -lt 0) {
    return $Fallback
  }
  return ($maxEdge + 1)
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$resolvedRunRoot = if ([string]::IsNullOrWhiteSpace($RunRoot)) { Join-Path $root ".xsim_qam_rand" } else { $RunRoot }
$runDir = if ([string]::IsNullOrWhiteSpace($ReuseRunDir)) { Join-Path $resolvedRunRoot $runStamp } else { $ReuseRunDir }
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_rand_tb.sv"
$cfgFile = Join-Path $tbDir "quadtree_and_mesh_rand_cfg.vh"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\quadtree_and_mesh\run_rand.tcl"

$generatedDir = Join-Path $root $GeneratedDirName
$generatedNoC = Resolve-DutTopFile -GeneratedDir $generatedDir
$dutSources = @()
$stubIncludeDir = Join-Path $runDir "verification_stubs"
$nCore = 64
$topLane = 4
$useEmbeddedBlackboxes = $false

if ([string]::IsNullOrWhiteSpace($ReuseRunDir)) {
  New-Item -ItemType Directory -Force -Path $runDir | Out-Null

  Push-Location $root
  try {
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
    }

    $generatedNoC = Resolve-DutTopFile -GeneratedDir $generatedDir
    $dutSources = @(Get-DutSourceFiles -GeneratedDir $generatedDir -TopFile $generatedNoC)
    $EdgeN = Get-DutEdgeCount -TopFile $generatedNoC -Fallback $EdgeN
    $nCore = Get-DutCoreCount -TopFile $generatedNoC -Fallback 64
    $topLane = Get-DutTopLaneCount -TopFile $generatedNoC -Fallback 4

    @(
      ('`define RAND_SEED {0}' -f $Seed),
      ('`define RAND_NUM_CASES {0}' -f $Cases),
      ('`define RAND_MAX_PKTS {0}' -f $MaxPkts),
      ('`define RAND_EDGE_N {0}' -f $EdgeN),
      ('`define RAND_N_CORE {0}' -f $nCore),
      ('`define RAND_TOP_LANE {0}' -f $topLane),
      ('`define RAND_HANDSHAKE_TIMEOUT_NS {0}' -f 500000),
      ('`define RAND_GLOBAL_TIMEOUT_NS {0}' -f 8000000)
    ) | Set-Content -Path $cfgFile -Encoding Ascii

    & powershell -NoProfile -ExecutionPolicy Bypass -File $instGen -OutFile $instVh -EdgeN $EdgeN -NCore $nCore -TopLane $topLane
    Assert-LastExitCode "gen_dut_inst_vh.ps1"

    New-VerificationIncludeStubs -SourceFiles $dutSources -StubDir $stubIncludeDir
    $useEmbeddedBlackboxes = Test-ProvidesAllModules `
      -SourceFiles $dutSources `
      -ModuleNames @("DelayElement", "Mutex2", "MrGo")
  } finally {
    Pop-Location
  }
} else {
  $dutSources = @(Get-DutSourceFiles -GeneratedDir $generatedDir -TopFile $generatedNoC)
  $useEmbeddedBlackboxes = Test-ProvidesAllModules `
    -SourceFiles $dutSources `
    -ModuleNames @("DelayElement", "Mutex2", "MrGo")
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
  if ([string]::IsNullOrWhiteSpace($ReuseRunDir)) {
    Remove-Item -LiteralPath "xsim.dir" -Recurse -Force -ErrorAction SilentlyContinue

    $xvlogSources = @($dutSources)
    if (-not $useEmbeddedBlackboxes) {
      $xvlogSources += @($delayFile, $mrgoFile, $mutexFile)
    }
    $xvlogSources += $tbFile

    & xvlog --sv --work work `
      -i $generatedDir `
      -i $stubIncludeDir `
      -i $tbDir `
      @xvlogSources
    Assert-LastExitCode "xvlog"

    xelab --timescale 1ns/1ps --debug off --mt off --nosignalhandlers -s quadtree_and_mesh_rand_tb_sim work.quadtree_and_mesh_rand_tb
    Assert-XelabSucceededOrSnapshotReady "quadtree_and_mesh_rand_tb_sim"

    Write-Host "[QAM-RAND-PATH] run_dir=$runDir"
    if ($BuildOnly) {
      Write-Host "[QAM-RAND] build-only completed"
      return
    }
  }

  $xsimArgs = @("quadtree_and_mesh_rand_tb_sim")

  if ($Mode -eq "batch") {
    & xsim @xsimArgs --runall
    Assert-LastExitCode "xsim batch"
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In xsim Tcl console:"
    Write-Host "  source $(To-XsimPath $batchTcl)"
    Write-Host "Compiled random configuration:"
    Write-Host "  RAND_SEED=$Seed RAND_NUM_CASES=$Cases RAND_MAX_PKTS=$MaxPkts EDGE_N=$EdgeN N_CORE=$nCore TOP_LANE=$topLane"
    & xsim @xsimArgs --gui
    Assert-LastExitCode "xsim gui"
  }
} finally {
  $env:TEMP = $oldTemp
  $env:TMP = $oldTmp
  Pop-Location
}
