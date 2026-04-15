param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
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

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\quadtree_and_mesh"
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\quadtree_and_mesh\run_all.tcl"

$generatedTop = Join-Path $root "generated\quadtree_and_mesh.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedTop)) {
    sbt "runMain NoC.quadtree_and_mesh"
  }
  & $instGen -OutFile $instVh
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
  xvlog --sv --work work `
    -i $tbDir `
    $generatedTop `
    $delayFile `
    $mrgoFile `
    $mutexFile `
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
