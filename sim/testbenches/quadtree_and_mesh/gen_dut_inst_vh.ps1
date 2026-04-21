param(
  [string]$OutFile = "sim/testbenches/quadtree_and_mesh/quadtree_and_mesh_dut_inst.vh",
  [ValidateRange(1, 8)]
  [int]$EdgeN = 2,
  [ValidateRange(1, 64)]
  [int]$NCore = 64,
  [ValidateRange(1, 16)]
  [int]$TopLane = 4,
  [string]$ModuleName = "quadtree_and_mesh"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$nQuad = $EdgeN * $EdgeN
$nCore = $NCore
$edgeN = $EdgeN
$topLane = $TopLane

$connections = New-Object System.Collections.Generic.List[string]
$connections.Add("    .clock(clock)")
$connections.Add("    .reset(reset)")

for ($q = 0; $q -lt $nQuad; $q++) {
  for ($c = 0; $c -lt $nCore; $c++) {
    $connections.Add("    .io_inputs_${q}_${c}_HS_Req(core_in_req[$q][$c])")
    $connections.Add("    .io_inputs_${q}_${c}_HS_Ack(core_in_ack[$q][$c])")
    $connections.Add("    .io_inputs_${q}_${c}_Data_flit(core_in_flit[$q][$c])")
  }
}

for ($q = 0; $q -lt $nQuad; $q++) {
  for ($c = 0; $c -lt $nCore; $c++) {
    $connections.Add("    .io_outputs_${q}_${c}_HS_Req(core_out_req[$q][$c])")
    $connections.Add("    .io_outputs_${q}_${c}_HS_Ack(core_out_ack[$q][$c])")
    $connections.Add("    .io_outputs_${q}_${c}_Data_flit(core_out_flit[$q][$c])")
  }
}

for ($y = 0; $y -lt $edgeN; $y++) {
  for ($l = 0; $l -lt $topLane; $l++) {
    $connections.Add("    .io_East_fromPEs_${y}_${l}_HS_Req(east_from_req[$y][$l])")
    $connections.Add("    .io_East_fromPEs_${y}_${l}_HS_Ack(east_from_ack[$y][$l])")
    $connections.Add("    .io_East_fromPEs_${y}_${l}_Data_flit(east_from_flit[$y][$l])")
    $connections.Add("    .io_North_fromPEs_${y}_${l}_HS_Req(north_from_req[$y][$l])")
    $connections.Add("    .io_North_fromPEs_${y}_${l}_HS_Ack(north_from_ack[$y][$l])")
    $connections.Add("    .io_North_fromPEs_${y}_${l}_Data_flit(north_from_flit[$y][$l])")
    $connections.Add("    .io_West_fromPEs_${y}_${l}_HS_Req(west_from_req[$y][$l])")
    $connections.Add("    .io_West_fromPEs_${y}_${l}_HS_Ack(west_from_ack[$y][$l])")
    $connections.Add("    .io_West_fromPEs_${y}_${l}_Data_flit(west_from_flit[$y][$l])")
    $connections.Add("    .io_South_fromPEs_${y}_${l}_HS_Req(south_from_req[$y][$l])")
    $connections.Add("    .io_South_fromPEs_${y}_${l}_HS_Ack(south_from_ack[$y][$l])")
    $connections.Add("    .io_South_fromPEs_${y}_${l}_Data_flit(south_from_flit[$y][$l])")

    $connections.Add("    .io_East_toPEs_${y}_${l}_HS_Req(east_to_req[$y][$l])")
    $connections.Add("    .io_East_toPEs_${y}_${l}_HS_Ack(east_to_ack[$y][$l])")
    $connections.Add("    .io_East_toPEs_${y}_${l}_Data_flit(east_to_flit[$y][$l])")
    $connections.Add("    .io_North_toPEs_${y}_${l}_HS_Req(north_to_req[$y][$l])")
    $connections.Add("    .io_North_toPEs_${y}_${l}_HS_Ack(north_to_ack[$y][$l])")
    $connections.Add("    .io_North_toPEs_${y}_${l}_Data_flit(north_to_flit[$y][$l])")
    $connections.Add("    .io_West_toPEs_${y}_${l}_HS_Req(west_to_req[$y][$l])")
    $connections.Add("    .io_West_toPEs_${y}_${l}_HS_Ack(west_to_ack[$y][$l])")
    $connections.Add("    .io_West_toPEs_${y}_${l}_Data_flit(west_to_flit[$y][$l])")
    $connections.Add("    .io_South_toPEs_${y}_${l}_HS_Req(south_to_req[$y][$l])")
    $connections.Add("    .io_South_toPEs_${y}_${l}_HS_Ack(south_to_ack[$y][$l])")
    $connections.Add("    .io_South_toPEs_${y}_${l}_Data_flit(south_to_flit[$y][$l])")
  }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('`ifndef QUADTREE_AND_MESH_DUT_INST_VH')
$lines.Add('`define QUADTREE_AND_MESH_DUT_INST_VH')
$lines.Add('')
$lines.Add('`define QAM_INSTANTIATE_DUT(DUT_NAME) \')
$lines.Add("  $ModuleName DUT_NAME ( \")

for ($i = 0; $i -lt $connections.Count; $i++) {
  $suffix = " \"
  if ($i -lt ($connections.Count - 1)) {
    $suffix = ", \"
  }
  $lines.Add($connections[$i] + $suffix)
}

$lines.Add('  );')
$lines.Add('')
$lines.Add('`endif')

$outDir = Split-Path -Parent $OutFile
if (!(Test-Path $outDir)) {
  New-Item -ItemType Directory -Path $outDir | Out-Null
}

[System.IO.File]::WriteAllLines($OutFile, $lines, [System.Text.UTF8Encoding]::new($false))
Write-Host "Generated: $OutFile"
