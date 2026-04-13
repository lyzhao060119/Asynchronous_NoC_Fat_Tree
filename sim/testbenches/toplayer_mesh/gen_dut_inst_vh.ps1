param(
  [string]$OutFile = "sim/testbenches/toplayer_mesh/toplayer_mesh_dut_inst.vh"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$nTree = 16
$treeLane = 8
$edgeN = 4
$edgeLane = 4

$connections = New-Object System.Collections.Generic.List[string]
$connections.Add("    .clock(clock)")
$connections.Add("    .reset(reset)")

for ($t = 0; $t -lt $nTree; $t++) {
  for ($l = 0; $l -lt $treeLane; $l++) {
    $connections.Add("    .io_inputs_${t}_${l}_HS_Req(in_req[$t][$l])")
    $connections.Add("    .io_inputs_${t}_${l}_HS_Ack(in_ack[$t][$l])")
    $connections.Add("    .io_inputs_${t}_${l}_Data_flit(in_flit[$t][$l])")
  }
}

for ($t = 0; $t -lt $nTree; $t++) {
  for ($l = 0; $l -lt $treeLane; $l++) {
    $connections.Add("    .io_outputs_${t}_${l}_HS_Req(out_req[$t][$l])")
    $connections.Add("    .io_outputs_${t}_${l}_HS_Ack(out_ack[$t][$l])")
    $connections.Add("    .io_outputs_${t}_${l}_Data_flit(out_flit[$t][$l])")
  }
}

for ($e = 0; $e -lt $edgeN; $e++) {
  for ($l = 0; $l -lt $edgeLane; $l++) {
    $connections.Add("    .io_East_fromPEs_${e}_${l}_HS_Req(east_from_req[$e][$l])")
    $connections.Add("    .io_East_fromPEs_${e}_${l}_HS_Ack(east_from_ack[$e][$l])")
    $connections.Add("    .io_East_fromPEs_${e}_${l}_Data_flit(east_from_flit[$e][$l])")
    $connections.Add("    .io_North_fromPEs_${e}_${l}_HS_Req(north_from_req[$e][$l])")
    $connections.Add("    .io_North_fromPEs_${e}_${l}_HS_Ack(north_from_ack[$e][$l])")
    $connections.Add("    .io_North_fromPEs_${e}_${l}_Data_flit(north_from_flit[$e][$l])")
    $connections.Add("    .io_West_fromPEs_${e}_${l}_HS_Req(west_from_req[$e][$l])")
    $connections.Add("    .io_West_fromPEs_${e}_${l}_HS_Ack(west_from_ack[$e][$l])")
    $connections.Add("    .io_West_fromPEs_${e}_${l}_Data_flit(west_from_flit[$e][$l])")
    $connections.Add("    .io_South_fromPEs_${e}_${l}_HS_Req(south_from_req[$e][$l])")
    $connections.Add("    .io_South_fromPEs_${e}_${l}_HS_Ack(south_from_ack[$e][$l])")
    $connections.Add("    .io_South_fromPEs_${e}_${l}_Data_flit(south_from_flit[$e][$l])")

    $connections.Add("    .io_East_toPEs_${e}_${l}_HS_Req(east_to_req[$e][$l])")
    $connections.Add("    .io_East_toPEs_${e}_${l}_HS_Ack(east_to_ack[$e][$l])")
    $connections.Add("    .io_East_toPEs_${e}_${l}_Data_flit(east_to_flit[$e][$l])")
    $connections.Add("    .io_North_toPEs_${e}_${l}_HS_Req(north_to_req[$e][$l])")
    $connections.Add("    .io_North_toPEs_${e}_${l}_HS_Ack(north_to_ack[$e][$l])")
    $connections.Add("    .io_North_toPEs_${e}_${l}_Data_flit(north_to_flit[$e][$l])")
    $connections.Add("    .io_West_toPEs_${e}_${l}_HS_Req(west_to_req[$e][$l])")
    $connections.Add("    .io_West_toPEs_${e}_${l}_HS_Ack(west_to_ack[$e][$l])")
    $connections.Add("    .io_West_toPEs_${e}_${l}_Data_flit(west_to_flit[$e][$l])")
    $connections.Add("    .io_South_toPEs_${e}_${l}_HS_Req(south_to_req[$e][$l])")
    $connections.Add("    .io_South_toPEs_${e}_${l}_HS_Ack(south_to_ack[$e][$l])")
    $connections.Add("    .io_South_toPEs_${e}_${l}_Data_flit(south_to_flit[$e][$l])")
  }
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('`ifndef TOPLAYER_MESH_DUT_INST_VH')
$lines.Add('`define TOPLAYER_MESH_DUT_INST_VH')
$lines.Add('')
$lines.Add('`define TLM_INSTANTIATE_DUT(DUT_NAME) \')
$lines.Add('  TopLayer DUT_NAME ( \')

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
