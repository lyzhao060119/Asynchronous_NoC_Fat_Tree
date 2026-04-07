param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "gui"
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\three_level_quadtree"
$throughputTcl = Join-Path $root "sim\xsim\three_level_quadtree\throughput_3flit.tcl"
$waveTcl = Join-Path $root "sim\xsim\three_level_quadtree\throughput_wave.tcl"
$generatedVerilog = Join-Path $root "generated\three_level_quadtree.v"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if (-not (Test-Path $generatedVerilog)) {
    sbt "runMain NoC.three_level_quadtree"
  }
} finally {
  Pop-Location
}

Push-Location $runDir
try {
  xvlog --sv --work work `
    $generatedVerilog `
    (Join-Path $root "src\main\resources\ASYNC\DelayElement.v") `
    (Join-Path $root "src\main\resources\ASYNC\MrGo.v") `
    (Join-Path $root "src\main\resources\ASYNC\Mutex2.v")

  xelab --timescale 1ns/1ps --debug typical -s three_level_quadtree_xsim work.three_level_quadtree

  if ($Mode -eq "batch") {
    xsim three_level_quadtree_xsim -tclbatch (To-XsimPath $throughputTcl)
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In the xsim Tcl console, use:"
    Write-Host "  source $(To-XsimPath $waveTcl)"
    Write-Host "  source $(To-XsimPath $throughputTcl)"
    xsim three_level_quadtree_xsim -gui
  }
} finally {
  Pop-Location
}
