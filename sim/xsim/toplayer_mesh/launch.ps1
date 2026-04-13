param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\toplayer_mesh"
$tbDir = Join-Path $root "sim\testbenches\toplayer_mesh"
$tbFile = Join-Path $tbDir "toplayer_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "toplayer_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\toplayer_mesh\run_all.tcl"

$generatedTopLayer = Join-Path $root "generated\TopLayer.v"
$generatedDelay = Join-Path $root "generated\DelayElement.v"
$generatedMutex = Join-Path $root "generated\Mutex2.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedTopLayer)) {
    sbt "runMain NoC.TopLayer"
  }
  & $instGen -OutFile $instVh
} finally {
  Pop-Location
}

Push-Location $runDir
try {
  xvlog --sv --work work `
    -i $tbDir `
    $generatedTopLayer `
    $generatedDelay `
    $generatedMutex `
    $tbFile

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
