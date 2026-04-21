param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

function Resolve-DutTopFile([string]$GeneratedDir) {
  $candidates = @(
    (Join-Path $GeneratedDir "TopLayer.sv"),
    (Join-Path $GeneratedDir "TopLayer.v")
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
$runDir = Join-Path $root "sim\work\xsim\toplayer_mesh"
$tbDir = Join-Path $root "sim\testbenches\toplayer_mesh"
$tbFile = Join-Path $tbDir "toplayer_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "toplayer_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\toplayer_mesh\run_all.tcl"

$generatedDir = Join-Path $root "generated"
$generatedTopLayer = Resolve-DutTopFile -GeneratedDir $generatedDir
$generatedDelay = Join-Path $root "generated\DelayElement.v"
$generatedMutex = Join-Path $root "generated\Mutex2.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedTopLayer)) {
    sbt "runMain NoC.TopLayer"
  }
  $generatedTopLayer = Resolve-DutTopFile -GeneratedDir $generatedDir
  & $instGen -OutFile $instVh
} finally {
  Pop-Location
}

$useEmbeddedBlackboxes = Test-IsMonolithicTopFile -TopFile $generatedTopLayer

Push-Location $runDir
try {
  $xvlogSources = @($generatedTopLayer)
  if (-not $useEmbeddedBlackboxes) {
    $xvlogSources += @($generatedDelay, $generatedMutex)
  }
  $xvlogSources += $tbFile

  & xvlog --sv --work work `
    -i $generatedDir `
    -i $tbDir `
    @xvlogSources

  xelab --timescale 1ns/1ps --debug typical -s toplayer_mesh_tb_sim work.toplayer_mesh_tb

  if ($Mode -eq "batch") {
    xsim toplayer_mesh_tb_sim -tclbatch (To-XsimPath $batchTcl)
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In xsim Tcl console:"
    Write-Host "  source $(To-XsimPath $batchTcl)"
    xsim toplayer_mesh_tb_sim -gui
  }
} finally {
  Pop-Location
}
