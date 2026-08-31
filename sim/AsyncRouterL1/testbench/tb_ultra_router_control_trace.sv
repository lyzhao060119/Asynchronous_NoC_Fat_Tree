`timescale 1ns/1ps

// Simulation-only child0 -> parent control trace.  It reads hierarchical
// signals only; no Router port, state, or handshake decision is modified.
module tb_ultra_router_control_trace;
  reg clock = 1'b0, reset = 1'b1;
  reg [4:0] in_req = 5'b0;
  wire [4:0] in_ack;
  reg [27:0] in_data [0:4];
  wire [4:0] out_req;
  reg [4:0] out_ack = 5'b0;
  wire [27:0] out_data [0:4];
  integer i, timeout, body_gap_ns;
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

  wire tr_reqx       = dut.inputModules_0.mousetrap.request_latch_q;
  wire tr_ackx       = dut.inputModules_0.ackGenerator.io_AckX;
  wire tr_complete   = dut.inputModules_0.ackGenerator._ackReg_T;
  wire tr_prs_ready  = dut.inputModules_0.prs.io_PRSReady;
  wire tr_latch_en   = dut.inputModules_0.mousetrap.latch_en;
  wire tr_rs3        = dut.requestBanks_0.generators_3.io_RS;
  wire tr_req3       = dut.requestBanks_0.generators_3.io_Req;
  wire tr_ack3       = dut.requestBanks_0.generators_3.io_Ack;
  wire tr_done3      = dut.requestBanks_0.generators_3.io_Done;
  wire tr_ppe3       = dut.requestBanks_0.generators_3.io_PPE;
  wire tr_grant3     = dut.requestBanks_0.generators_3.io_Grant;
  wire tr_mg3        = dut.requestBanks_0.generators_3.io_MG;
  wire tr_opm_ack0   = dut.outputModules_4.io_Ack_0;

  always #5 clock = ~clock;

  task automatic trace(input [8*24-1:0] tag);
    $display("ULTRA_TRACE t=%0t %-24s in=%b/%b reqx/ackx=%b/%b complete=%b prs/en=%b/%b rs3=%b req/ack/done=%b/%b/%b ppe/grant/mg=%b/%b/%b opmAck=%b parent=%b/%b data=%h",
      $time, tag, in_req[0], in_ack[0], tr_reqx, tr_ackx, tr_complete,
      tr_prs_ready, tr_latch_en, tr_rs3, tr_req3, tr_ack3, tr_done3,
      tr_ppe3, tr_grant3, tr_mg3, tr_opm_ack0, out_req[4], out_ack[4], out_data[4]);
  endtask

  always @(in_req[0]) trace("ReqIn edge");
  always @(in_ack[0]) trace("AckIn/ReqX edge");
  always @(tr_ackx) trace("AckX edge");
  always @(tr_complete) trace("complete edge");
  always @(tr_prs_ready) trace("PRSReady edge");
  always @(tr_latch_en) trace("V1 latch_en edge");
  always @(tr_done3) trace("branch3 Done edge");
  always @(tr_ack3) trace("branch3 Ack edge");
  always @(out_req[4]) trace("parent ReqOut edge");
  always @(out_ack[4]) trace("parent AckOut edge");

  task automatic fail(input [8*80-1:0] why);
    begin trace(why); $display("TB_RESULT FAIL %0s", why); $finish(1); end
  endtask

  task automatic send_flit(input [27:0] flit);
    begin
      timeout = 0;
      while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
      if (timeout == 20000) fail("input slot timeout");
      in_data[0] = flit;
      #0.2 in_req[0] = ~in_req[0];
      timeout = 0;
      while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
      if (timeout == 20000) fail("input ack timeout");
    end
  endtask

  task automatic receive_parent(input [27:0] expected);
    begin
      timeout = 0;
      while (out_req[4] === out_ack[4] && timeout < 40000) begin #0.1; timeout = timeout + 1; end
      if (timeout == 40000) fail("parent req timeout");
      if (out_data[4] !== expected) fail("parent data mismatch");
      out_ack[4] = out_req[4];
      #1;
    end
  endtask

  initial begin
    for (i = 0; i < 5; i = i + 1) in_data[i] = 0;
    body_gap_ns = 0;
    if (!$value$plusargs("BODY_GAP_NS=%d", body_gap_ns)) body_gap_ns = 0;
    if ($value$plusargs("DUMP_VCD=%s", dump_path)) begin
      $dumpfile(dump_path);
      $dumpvars(0, in_req, in_ack, out_req, out_ack, tr_reqx, tr_ackx,
                tr_complete, tr_prs_ready, tr_latch_en, tr_rs3, tr_req3,
                tr_ack3, tr_done3, tr_ppe3, tr_grant3, tr_mg3, tr_opm_ack0);
    end
    #20 reset = 0; #2; trace("reset released");
    send_flit(28'h8820820); receive_parent(28'h8820820);
    if (body_gap_ns > 0) #(body_gap_ns);
    trace("before Body injection");
    send_flit(28'h0020820); receive_parent(28'h0020820);
    send_flit(28'h4420820); receive_parent(28'h4420820);
    $display("TB_RESULT PASS UltraRouter control trace gap=%0d", body_gap_ns);
    $finish;
  end
  initial begin #50000; fail("global timeout"); end
endmodule
