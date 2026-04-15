param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "batch",
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

<<<<<<< HEAD
function Resolve-FirstExisting([string[]]$Candidates, [string]$Label) {
  foreach ($path in $Candidates) {
    if (Test-Path $path) {
      return $path
    }
  }
  throw "Cannot find $Label. Checked: $($Candidates -join ', ')"
}

=======
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd
$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\quadtree_and_mesh"
$tbDir = Join-Path $root "sim\testbenches\quadtree_and_mesh"
$tbFile = Join-Path $tbDir "quadtree_and_mesh_tb.sv"
$instGen = Join-Path $tbDir "gen_dut_inst_vh.ps1"
$instVh = Join-Path $tbDir "quadtree_and_mesh_dut_inst.vh"
$batchTcl = Join-Path $root "sim\xsim\quadtree_and_mesh\run_all.tcl"

<<<<<<< HEAD
$generatedTop = Join-Path $root "generated\quadtree_and_mesh.v"
=======
$generatedNoC = Join-Path $root "generated\quadtree_and_mesh.v"
$generatedDelay = Join-Path $root "generated\DelayElement.v"
$generatedMutex = Join-Path $root "generated\Mutex2.v"
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
<<<<<<< HEAD
  if ($Regenerate -or -not (Test-Path $generatedTop)) {
=======
  if ($Regenerate -or -not (Test-Path $generatedNoC)) {
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd
    sbt "runMain NoC.quadtree_and_mesh"
  }
  & $instGen -OutFile $instVh
} finally {
  Pop-Location
}

<<<<<<< HEAD
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

=======
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd
Push-Location $runDir
try {
  xvlog --sv --work work `
    -i $tbDir `
<<<<<<< HEAD
    $generatedTop `
    $delayFile `
    $mrgoFile `
    $mutexFile `
=======
    $generatedNoC `
    $generatedDelay `
    $generatedMutex `
>>>>>>> 0a21c73d44514b7b8ba24e7fd5ffe1f9dc29f3bd
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
