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
$runDir = Join-Path $root "sim\work\xsim\quadtree_and_mesh"
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\quadtree_and_mesh\run_all.tcl"

$generatedNoC = Join-Path $root "generated\quadtree_and_mesh.v"
$generatedDelay = Join-Path $root "generated\DelayElement.v"
$generatedMutex = Join-Path $root "generated\Mutex2.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedNoC)) {
    sbt "runMain NoC.quadtree_and_mesh"
  }
  & $instGen -OutFile $instVh
} finally {
  Pop-Location
}

Push-Location $runDir
try {
  xvlog --sv --work work `
    -i $tbDir `
    $generatedNoC `
    $generatedDelay `
    $generatedMutex `
    $tbFile

  xelab --timescale 1ns/1ps --debug typical -s quadtree_and_mesh_tb_sim work.quadtree_and_mesh_tb

  if ($Mode -eq "batch") {
    xsim quadtree_and_mesh_tb_sim -tclbatch (To-XsimPath $batchTcl)
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In xsim Tcl console:"
    Write-Host "  source $(To-XsimPath $batchTcl)"
    xsim quadtree_and_mesh_tb_sim -gui
  }
} finally {
  Pop-Location
}
