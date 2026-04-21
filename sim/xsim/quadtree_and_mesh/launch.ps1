param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [string]$RunRoot = "",
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

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runStamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
$resolvedRunRoot = if ([string]::IsNullOrWhiteSpace($RunRoot)) { Join-Path $root ".xsim_qam" } else { $RunRoot }
$runDir = Join-Path $resolvedRunRoot $runStamp
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\quadtree_and_mesh\run_all.tcl"

$generatedDir = Join-Path $root "generated"
$generatedNoC = Resolve-DutTopFile -GeneratedDir $generatedDir

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedNoC)) {
    sbt "runMain NoC.quadtree_and_mesh"
    Assert-LastExitCode "sbt runMain NoC.quadtree_and_mesh"
  }
  $generatedNoC = Resolve-DutTopFile -GeneratedDir $generatedDir
  & $instGen -OutFile $instVh
} finally {
  Pop-Location
}

$useEmbeddedBlackboxes = Test-IsMonolithicTopFile -TopFile $generatedNoC

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
  $oldTemp = $env:TEMP
  $oldTmp = $env:TMP
  $env:TEMP = $runDir
  $env:TMP = $runDir
  Remove-Item -LiteralPath "xsim.dir" -Recurse -Force -ErrorAction SilentlyContinue

  $xvlogSources = @($generatedNoC)
  if (-not $useEmbeddedBlackboxes) {
    $xvlogSources += @($delayFile, $mrgoFile, $mutexFile)
  }
  $xvlogSources += $tbFile

  & xvlog --sv --work work `
    -i $generatedDir `
    -i $tbDir `
    @xvlogSources
  Assert-LastExitCode "xvlog"

  xelab --timescale 1ns/1ps --debug off --mt off --nosignalhandlers -s quadtree_and_mesh_tb_sim work.quadtree_and_mesh_tb
  Assert-LastExitCode "xelab"

  if ($Mode -eq "batch") {
    xsim quadtree_and_mesh_tb_sim -tclbatch (To-XsimPath $batchTcl)
    Assert-LastExitCode "xsim batch"
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In xsim Tcl console:"
    Write-Host "  source $(To-XsimPath $batchTcl)"
    xsim quadtree_and_mesh_tb_sim -gui
    Assert-LastExitCode "xsim gui"
  }
  } finally {
    $env:TEMP = $oldTemp
    $env:TMP = $oldTmp
    Pop-Location
  }
