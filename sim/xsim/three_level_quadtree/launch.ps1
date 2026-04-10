param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "gui",
  [ValidateSet("throughput", "multicast")]
  [string]$Test = "throughput"
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\three_level_quadtree"
$throughputTcl = Join-Path $root "sim\xsim\three_level_quadtree\throughput_3flit.tcl"
$multicastTcl = Join-Path $root "sim\xsim\three_level_quadtree\multicast_rect_smoke.tcl"
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

  $batchScript = $throughputTcl
  if ($Test -eq "multicast") {
    $batchScript = $multicastTcl
  }

  if ($Mode -eq "batch") {
    xsim three_level_quadtree_xsim -tclbatch (To-XsimPath $batchScript)
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "In the xsim Tcl console, use:"
    Write-Host "  source $(To-XsimPath $waveTcl)"
    Write-Host "  source $(To-XsimPath $throughputTcl)"
    Write-Host "or:"
    Write-Host "  source $(To-XsimPath $multicastTcl)"
    xsim three_level_quadtree_xsim -gui
  }
} finally {
  Pop-Location
}
