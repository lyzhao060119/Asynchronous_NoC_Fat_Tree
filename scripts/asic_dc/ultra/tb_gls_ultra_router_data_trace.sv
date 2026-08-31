`timescale 1ns/1ps

// Simulation-only data-path trace for the Child0 -> Parent Head.  It never
// feeds a hierarchical observation back into handshake control.
module tb_gls_ultra_router_data_trace;
  reg clock = 0, reset = 1;
  reg [4:0] in_req = 0;
  wire [4:0] in_ack;
  reg [27:0] in_data [0:4];
  wire [4:0] out_req;
  reg [4:0] out_ack = 0;
  wire [27:0] out_data [0:4];
  integer i, timeout;
  string dump_path;

  UltraRouter dut (
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

`ifdef GATE_LEVEL
  // DC preserves the V1 D bus as 28 escaped scalar nets rather than one
  // vector identifier.  Reassemble it only for trace display.
  wire [27:0] tr_v1_d = {
    dut.\inputModules_0/mousetrap/_1_net_[27] , dut.\inputModules_0/mousetrap/_1_net_[26] , dut.\inputModules_0/mousetrap/_1_net_[25] , dut.\inputModules_0/mousetrap/_1_net_[24] ,
    dut.\inputModules_0/mousetrap/_1_net_[23] , dut.\inputModules_0/mousetrap/_1_net_[22] , dut.\inputModules_0/mousetrap/_1_net_[21] , dut.\inputModules_0/mousetrap/_1_net_[20] ,
    dut.\inputModules_0/mousetrap/_1_net_[19] , dut.\inputModules_0/mousetrap/_1_net_[18] , dut.\inputModules_0/mousetrap/_1_net_[17] , dut.\inputModules_0/mousetrap/_1_net_[16] ,
    dut.\inputModules_0/mousetrap/_1_net_[15] , dut.\inputModules_0/mousetrap/_1_net_[14] , dut.\inputModules_0/mousetrap/_1_net_[13] , dut.\inputModules_0/mousetrap/_1_net_[12] ,
    dut.\inputModules_0/mousetrap/_1_net_[11] , dut.\inputModules_0/mousetrap/_1_net_[10] , dut.\inputModules_0/mousetrap/_1_net_[9] , dut.\inputModules_0/mousetrap/_1_net_[8] ,
    dut.\inputModules_0/mousetrap/_1_net_[7] , dut.\inputModules_0/mousetrap/_1_net_[6] , dut.\inputModules_0/mousetrap/_1_net_[5] , dut.\inputModules_0/mousetrap/_1_net_[4] ,
    dut.\inputModules_0/mousetrap/_1_net_[3] , dut.\inputModules_0/mousetrap/_1_net_[2] , dut.\inputModules_0/mousetrap/_1_net_[1] , dut.\inputModules_0/mousetrap/_1_net_[0] };
  wire [27:0] tr_v1_q     = dut.\inputModules_0/mousetrap/latch_q ;
  wire        tr_v1_en    = dut.\inputModules_0/mousetrap/latch_en ;
  wire        tr_reqx     = dut.\inputModules_0/mousetrap/request_latch_q ;
  // These named Chisel boundary wires are folded by DC in this netlist.
  // They are direct aliases respectively of the V1 Q and the V2 D cone.
  wire [27:0] tr_datax    = tr_v1_q;
  wire [27:0] tr_opm_xbar = tr_v1_q;
  wire [27:0] tr_v2_d     = dut.\outputModules_4/dataOutLatch_d ;
  wire        tr_v2_en    = dut.\outputModules_4/requestOutLatch_en ;
  wire        tr_grant    = dut.outputModules_4_io_Grant_0;
  wire        tr_mg       = dut.\outputModules_4/requestLatches_0_en ;
`else
  wire [27:0] tr_v1_d     = dut.inputModules_0.mousetrap.DataIn;
  wire [27:0] tr_v1_q     = dut.inputModules_0.mousetrap.latch_q;
  wire        tr_v1_en    = dut.inputModules_0.mousetrap.latch_en;
  wire        tr_reqx     = dut.inputModules_0.mousetrap.request_latch_q;
  wire [27:0] tr_datax    = dut.inputModules_0_io_DataX_flit;
  wire [27:0] tr_opm_xbar = dut.outputModules_4_io_DataX_0_flit;
  wire [27:0] tr_v2_d     = dut.outputModules_4.dataOutLatch_d;
  wire        tr_v2_en    = dut.outputModules_4.requestOutLatch_en;
  wire        tr_grant    = dut.outputModules_4.io_Grant_0;
  wire        tr_mg       = dut.outputModules_4.io_MG_0;
`endif

  always #5 clock = ~clock;

  task automatic snapshot(input [8*28-1:0] tag); begin
    $display("DATA_TRACE t_ns=%0.3f tag=%0s in=%h v1d=%h v1q=%h datax=%h xbar=%h v2d=%h v2q=%h bits5_23_26=%b%b%b/%b%b%b/%b%b%b/%b%b%b ctrl=reqx:%b en1:%b grant:%b mg:%b en2:%b reqout:%b ackout:%b",
      $realtime, tag, in_data[0], tr_v1_d, tr_v1_q, tr_datax, tr_opm_xbar,
      tr_v2_d, out_data[4], in_data[0][5], in_data[0][23], in_data[0][26],
      tr_v1_q[5], tr_v1_q[23], tr_v1_q[26], tr_v2_d[5], tr_v2_d[23], tr_v2_d[26],
      out_data[4][5], out_data[4][23], out_data[4][26], tr_reqx, tr_v1_en,
      tr_grant, tr_mg, tr_v2_en, out_req[4], out_ack[4]);
  end endtask

  always @(tr_v1_q) snapshot("v1_q_change");
  always @(tr_datax) snapshot("datax_change");
  always @(tr_v2_d) snapshot("v2_d_change");
  always @(out_data[4]) snapshot("v2_q_change");
  always @(tr_v2_en) snapshot("v2_en_change");
  always @(out_req[4]) snapshot("reqout_change");

  task automatic fail(input [8*64-1:0] reason); begin
    snapshot(reason); $display("TB_RESULT FAIL %0s", reason); $finish(1);
  end endtask

  task automatic send_head; begin
    timeout = 0;
    while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 20000) fail("input_slot_timeout");
    in_data[0] = 28'h8820820; snapshot("data_written");
    #0.2; in_req[0] = ~in_req[0]; snapshot("reqin_toggle");
    timeout = 0;
    while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 20000) fail("input_ack_timeout");
    snapshot("input_ack_match");
  end endtask

  initial begin
    for (i = 0; i < 5; i = i + 1) in_data[i] = 0;
    if ($value$plusargs("DUMP_VCD=%s", dump_path)) begin
      $dumpfile(dump_path); $dumpvars(0, tb_gls_ultra_router_data_trace);
    end
    #20 reset = 0; #10; snapshot("reset_settled");
    send_head;
    timeout = 0;
    while (out_req[4] === out_ack[4] && timeout < 40000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 40000) fail("parent_req_timeout");
    snapshot("reqout_observed");
    #1; snapshot("one_ns_before_ack");
    if (out_data[4] !== 28'h8820820) fail("parent_data_mismatch");
    #0.2; out_ack[4] = out_req[4]; snapshot("ackout_follow");
    $display("TB_RESULT PASS data trace");
    $finish;
  end
  initial begin #50000; fail("global_timeout"); end
endmodule
