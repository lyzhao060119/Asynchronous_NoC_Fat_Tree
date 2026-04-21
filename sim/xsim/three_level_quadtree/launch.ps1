param(
  [ValidateSet("gui", "batch")]
  [string]$Mode = "gui",
  [switch]$Regenerate
)

$ErrorActionPreference = "Stop"

function To-XsimPath([string]$Path) {
  return $Path.Replace('\', '/')
}

function Resolve-DutTopFile([string]$GeneratedDir) {
  $candidates = @(
    (Join-Path $GeneratedDir "three_level_quadtree.sv"),
    (Join-Path $GeneratedDir "three_level_quadtree.v")
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
$runDir = Join-Path $root "sim\work\xsim\three_level_quadtree"
$tbDir = Join-Path $root "sim\testbenches\three_level_quadtree"
$generatedDir = Join-Path $root "generated"
$generatedVerilog = Resolve-DutTopFile -GeneratedDir $generatedDir
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
  $generatedVerilog = Resolve-DutTopFile -GeneratedDir $generatedDir
} finally {
  Pop-Location
}

$useEmbeddedBlackboxes = Test-IsMonolithicTopFile -TopFile $generatedVerilog

Push-Location $runDir
try {
  $xvlogSources = @($generatedVerilog)
  if (-not $useEmbeddedBlackboxes) {
    $xvlogSources += @($delayElement, $mrGo, $mutex2)
  }
  $xvlogSources += $tbSource

  & xvlog --sv --work work `
    -i $tbDir `
    -i $generatedDir `
    @xvlogSources

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
