param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "gui",
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")).Path
$runDir = Join-Path $root "sim\work\xsim\three_level_quadtree"
$tbDir = Join-Path $root "sim\testbenches\three_level_quadtree"
$generatedVerilog = Join-Path $root "generated\three_level_quadtree.v"
$delayElement = Join-Path $root "src\main\resources\ASYNC\DelayElement.v"
$mrGo = Join-Path $root "src\main\resources\ASYNC\MrGo.v"
$mutex2 = Join-Path $root "src\main\resources\ASYNC\Mutex2.v"
$tbSource = Join-Path $tbDir "three_level_quadtree_tb.sv"

New-Item -ItemType Directory -Force -Path $runDir | Out-Null

Push-Location $root
try {
  if ($Regenerate -or -not (Test-Path $generatedVerilog)) {
    sbt "runMain NoC.three_level_quadtree"
  }
} finally {
  Pop-Location
}

Push-Location $runDir
try {
  xvlog --sv --work work `
    -i $tbDir `
    -i (Join-Path $root "generated") `
    $generatedVerilog `
    $delayElement `
    $mrGo `
    $mutex2 `
    $tbSource

  xelab --timescale 1ns/1ps --debug typical -s three_level_quadtree_tb_xsim work.three_level_quadtree_tb

  if ($Mode -eq "batch") {
    xsim three_level_quadtree_tb_xsim -runall
  } else {
    Write-Host "GUI mode ready."
    Write-Host "Work directory:"
    Write-Host "  $runDir"
    Write-Host "Top module:"
    Write-Host "  work.three_level_quadtree_tb"
    xsim three_level_quadtree_tb_xsim -gui
  }
} finally {
  Pop-Location
}
