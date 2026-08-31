`timescale 1ns/1ps

// Gate-level boundary smoke.  The trace aliases below are simulation-only
// hierarchy reads; they neither add DUT ports nor participate in flow control.
module tb_gls_ultra_router;
  reg clock = 0, reset = 1;
  reg [4:0] in_req = 0; wire [4:0] in_ack;
  reg [27:0] in_data [0:4]; wire [4:0] out_req; reg [4:0] out_ack = 0;
  wire [27:0] out_data [0:4]; integer i, timeout, body_gap_ns, out_ack_delay_tenths_ns;
  string dump_path;
  realtime in_req_time [0:2], in_ack_time [0:2], out_req_time [0:2], out_ack_time [0:2];
  integer sending_flit = -1, receiving_flit = -1;

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

  // These escaped net names are preserved by the DC post-netlist.  Keep the
  // aliases local to this TB so UltraRouter remains a boundary-only DUT.
  wire tr_reqx       = dut.\inputModules_0/mousetrap/request_latch_q ;
  // AckGenerator D is ReqX, therefore the external AckIn port is the
  // retained gate-level observation of D without relying on an optimized pin.
  wire tr_ack_d      = in_ack[0];
  wire tr_ackx       = dut.\inputModules_0/ackGenerator_io_AckX ;
  wire tr_complete   = dut.\inputModules_0/ackGenerator/N3 ;
  wire tr_latch_en   = dut.\inputModules_0/mousetrap/latch_en ;
  wire tr_matched_z  = dut.\inputModules_0/prs/matchedDelay_Z ;
  wire tr_prs_ready  = tr_matched_z ^ tr_ackx;
  wire tr_ack3       = dut.outputModules_4_io_Ack_0;
  // DC retains the OPM L1 output rather than the upstream ReqGen temporary
  // net.  L1 is transparent while MG is high, so it is the branch request
  // seen by the OPM; Done is consequently L1.Q xor branch Ack.
  wire tr_req3       = dut.\outputModules_4/_mergedReq_T [0];
  wire tr_done3      = tr_req3 ^ tr_ack3;
  // OPM Ack DFF: D is local request-latch Q; CP is !regEnable.  Both names
  // are retained in the DC netlist and are trace-only evidence.
  wire tr_opm_regenable = dut.\outputModules_4/requestOutLatch_en ;
  wire tr_opm_ack_cp    = dut.\outputModules_4/N15 ;
  wire tr_grant3     = dut.outputModules_4_io_Grant_0;
  wire tr_ppe3       = tr_grant3;
  wire tr_mg3        = dut.\outputModules_4/requestLatches_0_en ;

  always #5 clock = ~clock;
  task trace(input [8*24-1:0] tag); begin
    $display("ULTRA_TRACE t=%0t %-24s reset=%b in=%b/%b reqx/ack_d/ackx=%b/%b/%b complete_cp=%b prs/en=%b/%b req/ack/done=%b/%b/%b opm_en/ackcp=%b/%b ppe/grant/mg=%b/%b/%b parent=%b/%b data=%h",
      $time, tag, reset, in_req[0], in_ack[0], tr_reqx, tr_ack_d, tr_ackx, tr_complete,
      tr_prs_ready, tr_latch_en, tr_req3, tr_ack3, tr_done3, tr_opm_regenable, tr_opm_ack_cp,
      tr_ppe3, tr_grant3, tr_mg3, out_req[4], out_ack[4], out_data[4]);
  end endtask
  always @(in_req[0]) trace("ReqIn edge");
  always @(in_ack[0]) trace("AckIn/ReqX edge");
  always @(reset) trace("reset edge");
  always @(tr_ackx) trace("AckX edge");
  always @(tr_complete) trace("complete edge");
  always @(tr_prs_ready) trace("PRSReady edge");
  always @(tr_latch_en) trace("V1 latch_en edge");
  always @(tr_done3) trace("branch3 Done edge");
  always @(tr_ack3) trace("branch3 Ack edge");
  always @(tr_opm_regenable) trace("OPM regEnable edge");
  always @(tr_opm_ack_cp) trace("OPM AckDFF CP edge");
  always @(out_req[4]) trace("parent ReqOut edge");
  always @(out_ack[4]) trace("parent AckOut edge");
  // Exact boundary edge timestamps.  The send/receive tasks still use their
  // existing polling only for protocol waiting and data checks.
  always @(in_ack[0]) begin
    if (!reset && sending_flit >= 0 && in_ack[0] === in_req[0]) begin
      in_ack_time[sending_flit] = $realtime;
      $display("TB_FLIT_TIME flit=%0d event=AckIn_edge t_ns=%0.3f", sending_flit, $realtime);
    end
  end
  always @(out_req[4]) begin
    if (!reset && receiving_flit >= 0 && out_req[4] !== out_ack[4]) begin
      out_req_time[receiving_flit] = $realtime;
      $display("TB_FLIT_TIME flit=%0d event=ReqOut_edge t_ns=%0.3f", receiving_flit, $realtime);
    end
  end
  task fail(input [8*80-1:0] reason); begin
    trace(reason);
    $display("TB_RESULT FAIL %0s t=%0t in=%b/%b out=%b/%b", reason, $time, in_req, in_ack, out_req, out_ack);
    $finish(1);
  end endtask
  task send(input integer flit_id, input [27:0] flit); begin
    // Source-side bundled-data setup.  AckIn/ReqIn alone still determine
    // ownership of the two-phase slot; this only establishes Data before Req.
    timeout = 0;
    while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 20000) fail("input_slot");
    in_data[0] = flit;
    #0.2;
    sending_flit = flit_id;
    in_req[0] = ~in_req[0];
    in_req_time[flit_id] = $realtime;
    $display("TB_FLIT_TIME flit=%0d event=ReqIn t_ns=%0.3f", flit_id, $realtime);
    timeout = 0;
    while (in_ack[0] !== in_req[0] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 20000) fail("input_ack");
    if (in_ack_time[flit_id] < in_req_time[flit_id]) begin
      in_ack_time[flit_id] = $realtime;
      $display("TB_FLIT_TIME flit=%0d event=AckIn_match t_ns=%0.3f", flit_id, $realtime);
    end
  end endtask
  task receive_parent(input integer flit_id, input [27:0] expected); begin
    receiving_flit = flit_id;
    timeout = 0;
    while (out_req[4] === out_ack[4] && timeout < 40000) begin #0.1; timeout = timeout + 1; end
    if (^out_req[4] === 1'bx) fail("parent_req_x");
    if (timeout == 40000) fail("parent_req");
    if (out_req_time[flit_id] < in_req_time[flit_id]) begin
      out_req_time[flit_id] = $realtime;
      $display("TB_FLIT_TIME flit=%0d event=ReqOut_seen t_ns=%0.3f", flit_id, $realtime);
    end
    if (out_data[4] !== expected) begin
      $display("TB_DATA_MISMATCH expected=%h actual=%h", expected, out_data[4]);
      fail("parent_data");
    end
    // A physical receiver cannot return Ack in the same simulation delta as
    // ReqOut.  This boundary-only dwell preserves the V2 phase-mismatch window
    // that clocks the OPM Ack DFF; it does not inspect internal state.
    if (out_ack_delay_tenths_ns > 0) #(out_ack_delay_tenths_ns * 0.1);
    out_ack[4] = out_req[4];
    out_ack_time[flit_id] = $realtime;
    $display("TB_FLIT_TIME flit=%0d event=AckOut_sent t_ns=%0.3f forward_ns=%0.3f end_to_end_ns=%0.3f",
      flit_id, $realtime, out_req_time[flit_id] - in_req_time[flit_id],
      out_ack_time[flit_id] - in_req_time[flit_id]);
    #1;
  end endtask
  initial begin
    for(i=0;i<5;i=i+1) in_data[i]=0;
    body_gap_ns = 0;
    if (!$value$plusargs("BODY_GAP_NS=%d", body_gap_ns)) body_gap_ns = 0;
    out_ack_delay_tenths_ns = 2;
    if (!$value$plusargs("OUT_ACK_DELAY_TENTHS_NS=%d", out_ack_delay_tenths_ns)) out_ack_delay_tenths_ns = 2;
    if ($value$plusargs("DUMP_VCD=%s", dump_path)) begin
      $dumpfile(dump_path);
      $dumpvars(0, reset, in_req, in_ack, out_req, out_ack, tr_reqx, tr_ack_d, tr_ackx,
                tr_complete, tr_prs_ready, tr_latch_en, tr_req3, tr_ack3,
                tr_done3, tr_opm_regenable, tr_opm_ack_cp, tr_ppe3, tr_grant3, tr_mg3);
    end
    #10;
    #10 reset=0;
    #10;
    if (in_ack !== 5'b0 || out_req !== 5'b0) fail("reset_boundary");
    send(0, 28'h8820820); receive_parent(0, 28'h8820820);
    if (body_gap_ns > 0) #(body_gap_ns);
    trace("before Body injection");
    send(1, 28'h0020820); receive_parent(1, 28'h0020820);
    send(2, 28'h4420820); receive_parent(2, 28'h4420820);
    if (in_ack[0] !== in_req[0]) fail("tail_input_ack");
    for (i = 0; i < 3; i = i + 1)
      $display("TB_FLIT_SUMMARY flit=%0d input_ack_ns=%0.3f forward_ns=%0.3f output_handshake_ns=%0.3f",
        i, in_ack_time[i] - in_req_time[i], out_req_time[i] - in_req_time[i],
        out_ack_time[i] - in_req_time[i]);
    $display("TB_RESULT PASS UltraRouter unicast3");
    $finish;
  end
  initial begin #50000; fail("global_timeout"); end
endmodule
