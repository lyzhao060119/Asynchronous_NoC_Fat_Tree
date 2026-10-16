`timescale 1ns/1ps

// Read-only SDF probe for the current RouterL1 latch-restored candidate.
// It isolates the first failing route: child input 0 -> parent output 4.
module tb_cmr_router_latch_restore_r4_probe;
  reg clock = 0;
  reg reset = 1;
  reg [4:0] in_req = 0;
  wire [4:0] in_ack;
  reg [27:0] in_data [0:4];
  wire [4:0] out_req;
  reg [4:0] out_ack = 0;
  wire [27:0] out_data [0:4];
  integer i;

  localparam [27:0] HEAD = 28'h8820820;

  CMRRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(in_req[0]), .io_inputs_child_0_0_HS_Ack(in_ack[0]), .io_inputs_child_0_0_Data_flit(in_data[0]),
    .io_inputs_child_1_0_HS_Req(in_req[1]), .io_inputs_child_1_0_HS_Ack(in_ack[1]), .io_inputs_child_1_0_Data_flit(in_data[1]),
    .io_inputs_child_2_0_HS_Req(in_req[2]), .io_inputs_child_2_0_HS_Ack(in_ack[2]), .io_inputs_child_2_0_Data_flit(in_data[2]),
    .io_inputs_child_3_0_HS_Req(in_req[3]), .io_inputs_child_3_0_HS_Ack(in_ack[3]), .io_inputs_child_3_0_Data_flit(in_data[3]),
    .io_inputs_parent_0_HS_Req(in_req[4]), .io_inputs_parent_0_HS_Ack(in_ack[4]), .io_inputs_parent_0_Data_flit(in_data[4]),
    .io_outputs_child_0_0_HS_Req(out_req[0]), .io_outputs_child_0_0_HS_Ack(out_ack[0]), .io_outputs_child_0_0_Data_flit(out_data[0]),
    .io_outputs_child_1_0_HS_Req(out_req[1]), .io_outputs_child_1_0_HS_Ack(out_ack[1]), .io_outputs_child_1_0_Data_flit(out_data[1]),
    .io_outputs_child_2_0_HS_Req(out_req[2]), .io_outputs_child_2_0_HS_Ack(out_ack[2]), .io_outputs_child_2_0_Data_flit(out_data[2]),
    .io_outputs_child_3_0_HS_Req(out_req[3]), .io_outputs_child_3_0_HS_Ack(out_ack[3]), .io_outputs_child_3_0_Data_flit(out_data[3]),
    .io_outputs_parent_0_HS_Req(out_req[4]), .io_outputs_parent_0_HS_Ack(out_ack[4]), .io_outputs_parent_0_Data_flit(out_data[4])
  );

  always #5 clock = ~clock;

  always @(dut.InputPortModules_0_io_Reqout_3 or
           dut.InputPortModules_0_io_Dataout_3_flit or
           dut.OutputPortModules_4.io_Reqin_0 or
           dut.OutputPortModules_4.io_PktPathEnable_0 or
           dut.OutputPortModules_4.io_Datain_0_flit or
           dut.OutputPortModules_4.DataSelected or
           dut.OutputPortModules_4.RegEnable or
           dut.OutputPortModules_4.io_Reqout or
           dut.OutputPortModules_4.io_Dataout_flit or
           out_req[4] or out_data[4] or in_ack[0]) begin
    if (!reset)
      $display("TB_R4_TRACE t_ns=%0.3f ipm_req=%b ipm_data=%h opm_reqin=%b path=%b datain=%h selected=%h regenable=%b opm_req=%b opm_data=%h out_req=%b out_data=%h in_ack=%b",
        $realtime,
        dut.InputPortModules_0_io_Reqout_3,
        dut.InputPortModules_0_io_Dataout_3_flit,
        dut.OutputPortModules_4.io_Reqin_0,
        dut.OutputPortModules_4.io_PktPathEnable_0,
        dut.OutputPortModules_4.io_Datain_0_flit,
        dut.OutputPortModules_4.DataSelected,
        dut.OutputPortModules_4.RegEnable,
        dut.OutputPortModules_4.io_Reqout,
        dut.OutputPortModules_4.io_Dataout_flit,
        out_req[4], out_data[4], in_ack[0]);
  end

  initial begin
    for (i = 0; i < 5; i = i + 1) in_data[i] = 0;
    #20 reset = 0;
    #10 in_data[0] = HEAD;
    $display("TB_R4_EVENT event=input_data t_ns=%0.3f value=%h", $realtime, in_data[0]);
    #0.2 in_req[0] = 1;
    $display("TB_R4_EVENT event=input_req t_ns=%0.3f value=%b", $realtime, in_req[0]);
    #4.0;
    $display("TB_R4_RESULT t_ns=%0.3f input_req_ack=%b/%b output_req_ack=%b/%b expected=%h actual=%h",
      $realtime, in_req[0], in_ack[0], out_req[4], out_ack[4], HEAD, out_data[4]);
    $finish;
  end

  initial begin
    #100;
    $display("TB_R4_RESULT timeout");
    $finish;
  end
endmodule
