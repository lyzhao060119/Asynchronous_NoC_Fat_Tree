`timescale 1ns/1ps

// Canonical boundary-only UltraRouter smoke.  It is compiled unchanged by the
// local structural xsim flow and remote strict-SDF GLS.  Output agents are
// intentionally independent: no testbench join controls a multicast branch.
module tb_ultra_router_boundary_smoke;
  reg clock = 0, reset = 1;
  reg [4:0] in_req = 0; wire [4:0] in_ack;
  reg [27:0] in_data [0:4]; wire [4:0] out_req; reg [4:0] out_ack = 0;
  wire [27:0] out_data [0:4];
  integer i, enforce_rtm;
  string smoke_case, dump_path;
  // Continuous-time bundled-data evidence.  It is intentionally derived from
  // boundary events only: it never participates in the handshake decisions.
  real last_in_req_time [0:4];
  real last_in_data_time [0:4];
  real last_out_data_time [0:4];
  real rtm_data, rtm_control, rtm_shortfall;

  localparam [27:0] U_A_H = 28'h8820820, U_A_B = 28'h0020820, U_A_T = 28'h4420820;
  localparam [27:0] U_B_H = 28'h8820821, U_B_B = 28'h0000821, U_B_T = 28'h4400821;
  localparam [27:0] MC_A_H = 28'h8104004, MC_A_B = 28'h0000A10, MC_A_T = 28'h4000A10;
  localparam [27:0] MC_B_H = 28'h8100000, MC_B_B = 28'h0000B20, MC_B_T = 28'h4000B20;
  localparam [27:0] MC_C_B = 28'h0000C30, MC_C_T = 28'h4000C30;
  localparam [27:0] MC_D_B = 28'h0000D40, MC_D_T = 28'h4000D40;

  // Fixed-size simulation FIFOs avoid a simulator-specific mailbox dependency.
  reg [27:0] expected_data [0:4][0:31];
  integer expected_delay [0:4][0:31];
  integer expected_packet [0:4][0:31];
  integer expected_flit [0:4][0:31];
  integer expected_head [0:4], expected_tail [0:4];

  // Packet completion is a scoreboard aggregation over independently
  // acknowledged output branches; it never requires simultaneous visibility.
  reg [4:0] packet_targets [0:7];
  reg [4:0] packet_seen_h [0:7], packet_seen_b [0:7], packet_seen_t [0:7];
  reg packet_active [0:7], packet_complete [0:7];
  real packet_complete_time [0:7];

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

  always #5 clock = ~clock;

`ifdef ULTRA_TRACE_V2
  // Simulation-only V2 admission trace.  These probes never influence source
  // or receiver handshake decisions.  They intentionally use the preserved
  // DC hierarchy so the first missing transition can be identified in the
  // strict-SDF netlist.
  task automatic trace_v2(input [8*24-1:0] tag); begin
    $display("TB_V2_TRACE t=%0t tag=%0s rs0=%b p0=%b m0=%b areq=%b agrant=%b tok=%b%b%b%b txv=%b start=%b fire=%b active=%b owner4=%0d",
      $time, tag,
      {dut.inputModules_0_io_RS_3, dut.inputModules_0_io_RS_2,
       dut.inputModules_0_io_RS_1, dut.inputModules_0_io_RS_0},
      dut.admission.capture.packet_present,
      dut.admission.capture.packet_mask,
      dut.admission.tx.anchor_mutex.req,
      dut.admission.tx.anchor_mutex.grant,
      dut.admission.tx.member4.close_ready,
      dut.admission.tx.member3.close_ready,
      dut.admission.tx.member2.close_ready,
      dut.admission.tx.member1.close_ready,
      dut.admission.tx.valid_latch.q,
      dut.admission.commitController.Start,
      dut.admission.commitController_fire_o,
      {dut.admission.io_packetActive_4, dut.admission.io_packetActive_3,
       dut.admission.io_packetActive_2, dut.admission.io_packetActive_1,
       dut.admission.io_packetActive_0},
      dut.admission.io_outputOwner_4);
  end endtask

  always @(dut.inputModules_0_io_RS_0 or dut.inputModules_0_io_RS_1 or
           dut.inputModules_0_io_RS_2 or dut.inputModules_0_io_RS_3 or
           dut.admission.capture.packet_present or dut.admission.capture.packet_mask or
           dut.admission.tx.anchor_mutex.req or dut.admission.tx.anchor_mutex.grant or
           dut.admission.tx.member1.close_ready or dut.admission.tx.member2.close_ready or
           dut.admission.tx.member3.close_ready or dut.admission.tx.member4.close_ready or
           dut.admission.tx.valid_latch.q or dut.admission.commitController.Start or
           dut.admission.commitController_fire_o or
           dut.admission.io_packetActive_0 or dut.admission.io_outputOwner_4)
    if (!reset) trace_v2("edge");

  initial begin
    #20.001;
    trace_v2("reset_release");
  end
`endif

`ifdef ULTRA_TRACE_HEAD_TIMING
  // Head-only timing marks for the Child0 -> Parent path.  This trace is
  // observational: it neither gates the source nor returns output Ack.
  real head_req_time;
  integer mark_reqx, mark_rs, mark_p, mark_anchor, mark_start, mark_busy, mark_close, mark_mem1, mark_mem2, mark_mem3, mark_mem4;
  integer mark_join01, mark_join23, mark_joinall, mark_final;
  integer mark_txv, mark_fire, mark_active, mark_admit, mark_rg_req;
  integer mark_ppe, mark_grant, mark_mg, mark_opm_req, mark_data, mark_out;
  integer mark_winner, mark_dfire_i, mark_dfire_z, dfire_emitted;
  integer mark_prs_i, mark_prs_z, mark_prs_ready, mark_v1_data, mark_prs_decode, prs_emitted;
  real dfire_start_ns, dfire_i_ns, dfire_z_ns, dfire_fire_ns;
  real dfire_last_winner_ns, dfire_last_mask0_ns, dfire_last_release_ns;
  real prs_reqx_ns, prs_i_ns, prs_z_ns, prs_ready_ns, prs_rs_ns;
  real prs_last_v1_ns, prs_last_env_ns, prs_last_decode_ns, prs_last_projected_ns;

  task automatic head_mark(input [8*20-1:0] name); begin
    $display("TB_HEAD_TIME stage=%0s t_ns=%0.3f delta_ns=%0.3f", name,
             $realtime, $realtime-head_req_time);
  end endtask

  // Observation-only Commit RTC.  Start/tx_valid is the common reference:
  // Tdata is the last frozen tx Q change, Tctrl is Start → fire.  These
  // probes never participate in handshake decisions.
  task automatic emit_dfire_rtc; begin
    real last_q, tdata_vis, tctrl, tdfire;
    last_q = dfire_last_winner_ns;
    if (dfire_last_mask0_ns > last_q) last_q = dfire_last_mask0_ns;
    if (dfire_last_release_ns > last_q) last_q = dfire_last_release_ns;
    tdata_vis = last_q - dfire_start_ns;
    tctrl = dfire_fire_ns - dfire_start_ns;
    tdfire = (mark_dfire_i && mark_dfire_z) ? (dfire_z_ns - dfire_i_ns) : 0.0;
    $display("TB_RTC_SAMPLE rtc=ACG_DFIRE_COMMIT phase=rise flit=0 datain_ns=%0.3f reqin_ns=%0.3f data_ns=%0.3f reqout_ns=%0.3f data_path_ns=%0.3f tdata_visible_ns=%0.3f tctrl_ns=%0.3f",
      last_q, dfire_start_ns, last_q, dfire_fire_ns, last_q-dfire_start_ns,
      tdata_vis, tctrl);
    $display("TB_DFIRE_WINDOW start_ns=%0.3f last_winner_q_ns=%0.3f last_mask0_q_ns=%0.3f last_release_q_ns=%0.3f last_tx_q_ns=%0.3f dfire_i_ns=%0.3f dfire_z_ns=%0.3f fire_ns=%0.3f tdata_q_to_start_ns=%0.3f tctrl_start_to_fire_ns=%0.3f tdfire_ns=%0.3f tctrl_minus_dfire_ns=%0.3f",
      dfire_start_ns, dfire_last_winner_ns, dfire_last_mask0_ns,
      dfire_last_release_ns, last_q, dfire_i_ns, dfire_z_ns, dfire_fire_ns,
      tdata_vis, tctrl, tdfire, tctrl-tdfire);
  end endtask

  // Observation-only PRS matched-delay RTC.  ReqX / matchedDelay.I is the
  // common reference.  Tdata is the last stability of ungated RoutingLogic
  // route_valid (_GEN_8 / decision_projectedDir).  V1 DataOut is only the
  // RoutingInfo input and is logged as a diagnostic.  Do not use gated
  // decision_dir, decision.output_valid, or RS as Tdata: those already
  // include requestActive / matchedDelay.  Tctrl is ReqX → RS.  Tprs is
  // matchedDelay.I → Z.  These probes never participate in handshake
  // decisions.
  task automatic emit_prs_rtc; begin
    real last_decode, tdata_vis, tctrl, tprs;
    last_decode = prs_last_decode_ns;
    if (prs_last_projected_ns > last_decode) last_decode = prs_last_projected_ns;
    tdata_vis = last_decode - prs_reqx_ns;
    tctrl = prs_rs_ns - prs_reqx_ns;
    tprs = (mark_prs_i && mark_prs_z) ? (prs_z_ns - prs_i_ns) : 0.0;
    $display("TB_RTC_SAMPLE rtc=PRS_MATCHED phase=rise flit=0 datain_ns=%0.3f reqin_ns=%0.3f data_ns=%0.3f reqout_ns=%0.3f data_path_ns=%0.3f tdata_visible_ns=%0.3f tctrl_ns=%0.3f",
      last_decode, prs_reqx_ns, last_decode, prs_rs_ns, last_decode-prs_reqx_ns,
      tdata_vis, tctrl);
    $display("TB_PRS_WINDOW reqx_ns=%0.3f last_decode_ns=%0.3f last_projected_ns=%0.3f last_v1_ns=%0.3f last_env_ns=%0.3f last_data_ns=%0.3f prs_i_ns=%0.3f prs_z_ns=%0.3f prs_ready_ns=%0.3f rs_ns=%0.3f tdata_q_to_reqx_ns=%0.3f tctrl_reqx_to_rs_ns=%0.3f tprs_ns=%0.3f tctrl_minus_tprs_ns=%0.3f",
      prs_reqx_ns, prs_last_decode_ns, prs_last_projected_ns, prs_last_v1_ns,
      prs_last_env_ns, last_decode, prs_i_ns, prs_z_ns, prs_ready_ns, prs_rs_ns,
      tdata_vis, tctrl, tprs, tctrl-tprs);
  end endtask

  always @(in_req[0]) if (!reset) begin
    head_req_time = $realtime;
    $display("TB_HEAD_TIME stage=ReqIn t_ns=%0.3f delta_ns=0.000", $realtime);
  end
  always @(dut.inputModules_0_io_ReqX)
    if (!reset && dut.inputModules_0_io_ReqX && !mark_reqx) begin
      mark_reqx=1; prs_reqx_ns=$realtime; head_mark("V1_ReqX");
    end
  always @(in_data[0])
    if (!reset) prs_last_env_ns = $realtime;
  always @(dut.inputModules_0.mousetrap.DataOut)
    if (!reset) begin
      prs_last_v1_ns = $realtime;
      if (prs_reqx_ns > 0.0 && !mark_v1_data) begin mark_v1_data=1; head_mark("V1_DataOut"); end
    end
  always @(dut.inputModules_0.prs.matchedDelay.I)
    if (!reset && dut.inputModules_0.prs.matchedDelay.I && !mark_prs_i) begin
      mark_prs_i=1; prs_i_ns=$realtime; head_mark("Prs_I");
    end
  always @(dut.inputModules_0.prs.matchedDelay.Z)
    if (!reset && dut.inputModules_0.prs.matchedDelay.Z && !mark_prs_z) begin
      mark_prs_z=1; prs_z_ns=$realtime; head_mark("Prs_Z");
    end
  always @(dut.inputModules_0.prs.io_PRSReady)
    if (!reset && dut.inputModules_0.prs.io_PRSReady && !mark_prs_ready) begin
      mark_prs_ready=1; prs_ready_ns=$realtime; head_mark("PRSReady");
    end
`ifdef ULTRA_TRACE_SDF
  // Post-synth names: _GEN_8 is the ungated decode feeding the headActive
  // mux into decision_dir.  decision_projectedDir is the raw projection
  // before that mux.  Neither includes matchedDelay.
  always @(dut.inputModules_0.prs._GEN_8)
    if (!reset) begin
      prs_last_decode_ns = $realtime;
      if (prs_reqx_ns > 0.0 && |dut.inputModules_0.prs._GEN_8 && !mark_prs_decode) begin
        mark_prs_decode=1; head_mark("Prs_ungated");
      end
      if (prs_emitted)
        $display("TB_PRS_DECODE_AFTER_RS t_ns=%0.3f decode=%b",
                 $realtime, dut.inputModules_0.prs._GEN_8);
    end
  always @(dut.inputModules_0.prs.decision_projectedDir)
    if (!reset) prs_last_projected_ns = $realtime;
`endif
  always @(dut.inputModules_0_io_RS_3)
    if (!reset && dut.inputModules_0_io_RS_3 && !mark_rs) begin
      mark_rs=1; prs_rs_ns=$realtime; head_mark("PRS_RS");
      if (!prs_emitted) begin prs_emitted=1; emit_prs_rtc(); end
    end
  always @(dut.admission.capture.packet_present)
    if (!reset && dut.admission.capture.packet_present && !mark_p) begin mark_p=1; head_mark("HeadCapture_P"); end
  always @(dut.admission.tx.anchor_mutex.grant)
    if (!reset && dut.admission.tx.anchor_mutex.grant[0] && !mark_anchor) begin mark_anchor=1; head_mark("Mutex5_anchor"); end
  always @(dut.admission.tx.anchor_margin.Z)
    if (!reset && dut.admission.tx.anchor_margin.Z && !mark_start) begin mark_start=1; head_mark("anchorStart"); end
  always @(dut.admission.tx.busy_latch.q)
    if (!reset && dut.admission.tx.busy_latch.q && !mark_busy) begin mark_busy=1; head_mark("roundBusy"); end
  always @(dut.admission.tx.round_close_margin.Z)
    if (!reset && dut.admission.tx.round_close_margin.Z && !mark_close) begin mark_close=1; head_mark("roundClose"); end
  always @(dut.admission.tx.member1.close_ready)
    if (!reset && dut.admission.tx.member1.close_ready && !mark_mem1) begin mark_mem1=1; head_mark("membership1_closed"); end
  always @(dut.admission.tx.member2.close_ready)
    if (!reset && dut.admission.tx.member2.close_ready && !mark_mem2) begin mark_mem2=1; head_mark("membership2_closed"); end
  always @(dut.admission.tx.member3.close_ready)
    if (!reset && dut.admission.tx.member3.close_ready && !mark_mem3) begin mark_mem3=1; head_mark("membership3_closed"); end
  always @(dut.admission.tx.member4.close_ready)
    if (!reset && dut.admission.tx.member4.close_ready && !mark_mem4) begin mark_mem4=1; head_mark("membership4_closed"); end
  always @(dut.admission.tx.membership_join01.Z)
    if (!reset && dut.admission.tx.membership_join01.Z && !mark_join01) begin mark_join01=1; head_mark("membershipJoin01"); end
  always @(dut.admission.tx.membership_join23.Z)
    if (!reset && dut.admission.tx.membership_join23.Z && !mark_join23) begin mark_join23=1; head_mark("membershipJoin23"); end
  always @(dut.admission.tx.membership_join_all.Z)
    if (!reset && dut.admission.tx.membership_join_all.Z && !mark_joinall) begin mark_joinall=1; head_mark("allMembershipClosed"); end
  always @(dut.admission.tx.final_builder_margin.Z)
    if (!reset && dut.admission.tx.final_builder_margin.Z && !mark_final) begin mark_final=1; head_mark("finalBuilderReady"); end
  always @(dut.admission.tx.valid_latch.q)
    if (!reset && dut.admission.tx.valid_latch.q && !mark_txv) begin
      mark_txv=1; dfire_start_ns=$realtime; head_mark("Transaction_valid");
    end
  always @(dut.admission.tx.tx_winner)
    if (!reset && head_req_time > 0.0) begin
      dfire_last_winner_ns = $realtime;
      if (|dut.admission.tx.tx_winner && !mark_winner) begin
        mark_winner=1; head_mark("txWinner_Q");
      end
    end
  always @(dut.admission.tx.tx_mask0)
    if (!reset && head_req_time > 0.0) dfire_last_mask0_ns = $realtime;
  always @(dut.admission.tx.tx_release)
    if (!reset && head_req_time > 0.0) dfire_last_release_ns = $realtime;
  always @(dut.admission.commitController.fire_o_Dfire.I)
    if (!reset && dut.admission.commitController.fire_o_Dfire.I && !mark_dfire_i) begin
      mark_dfire_i=1; dfire_i_ns=$realtime; head_mark("Dfire_I");
    end
  always @(dut.admission.commitController.fire_o_Dfire.Z)
    if (!reset && dut.admission.commitController.fire_o_Dfire.Z && !mark_dfire_z) begin
      mark_dfire_z=1; dfire_z_ns=$realtime; head_mark("Dfire_Z");
    end
  always @(dut.admission.commitController_fire_o)
    if (!reset && dut.admission.commitController_fire_o && !mark_fire) begin
      mark_fire=1; dfire_fire_ns=$realtime; head_mark("ACG_fire");
      if (!dfire_emitted) begin dfire_emitted=1; emit_dfire_rtc(); end
    end
  always @(dut.admission.io_packetActive_0)
    if (!reset && dut.admission.io_packetActive_0 && !mark_active) begin mark_active=1; head_mark("Active_commit"); end
  always @(dut.admission_io_admittedRS_0_3)
    if (!reset && dut.admission_io_admittedRS_0_3 && !mark_admit) begin mark_admit=1; head_mark("admittedRS"); end
  always @(dut.requestBanks_0_io_Req_3)
    if (!reset && dut.requestBanks_0_io_Req_3 && !mark_rg_req) begin mark_rg_req=1; head_mark("ReqGen_Req"); end
  always @(dut.requestBanks_0_io_PPE_3)
    if (!reset && dut.requestBanks_0_io_PPE_3 && !mark_ppe) begin mark_ppe=1; head_mark("ReqGen_PPE"); end
  always @(dut.outputModules_4_io_Grant_0)
    if (!reset && dut.outputModules_4_io_Grant_0 && !mark_grant) begin mark_grant=1; head_mark("OPM_Grant"); end
  always @(dut.outputModules_4_io_MG_0)
    if (!reset && dut.outputModules_4_io_MG_0 && !mark_mg) begin mark_mg=1; head_mark("OPM_MG"); end
  // DC may remove the top-level Chisel temporary nets, but the retained OPM
  // instance ports are stable in both entry RTL and the post-DC hierarchy.
  always @(dut.outputModules_4.io_Req_0)
    if (!reset && dut.outputModules_4.io_Req_0 && !mark_opm_req) begin mark_opm_req=1; head_mark("OPM_L1Req"); end
  always @(dut.outputModules_4.io_DataOut_flit)
    // Ignore reset-release activity: only the Head-caused stable data value
    // belongs to the ReqIn-to-DataOut measurement.
    if (!reset && head_req_time > 0.0 && !mark_data) begin mark_data=1; head_mark("OPM_DataOut"); end
  always @(out_req[4])
    if (!reset && out_req[4] && !mark_out) begin mark_out=1; head_mark("ReqOut"); end

  initial begin
    head_req_time=0.0;
    mark_reqx=0; mark_rs=0; mark_p=0; mark_anchor=0; mark_start=0; mark_busy=0; mark_close=0; mark_mem1=0; mark_mem2=0; mark_mem3=0; mark_mem4=0;
    mark_join01=0; mark_join23=0; mark_joinall=0; mark_final=0;
    mark_txv=0; mark_fire=0; mark_active=0; mark_admit=0; mark_rg_req=0;
    mark_ppe=0; mark_grant=0; mark_mg=0; mark_opm_req=0; mark_data=0; mark_out=0;
    mark_winner=0; mark_dfire_i=0; mark_dfire_z=0; dfire_emitted=0;
    mark_prs_i=0; mark_prs_z=0; mark_prs_ready=0; mark_v1_data=0; mark_prs_decode=0; prs_emitted=0;
    dfire_start_ns=0.0; dfire_i_ns=0.0; dfire_z_ns=0.0; dfire_fire_ns=0.0;
    dfire_last_winner_ns=0.0; dfire_last_mask0_ns=0.0; dfire_last_release_ns=0.0;
    prs_reqx_ns=0.0; prs_i_ns=0.0; prs_z_ns=0.0; prs_ready_ns=0.0; prs_rs_ns=0.0;
    prs_last_v1_ns=0.0; prs_last_env_ns=0.0; prs_last_decode_ns=0.0; prs_last_projected_ns=0.0;
  end
`endif

`ifdef ULTRA_TRACE_DATAPATH
  // Phase-3 datapath-first measurement.  It observes a single Head transfer
  // with no handshake control feedback into the DUT.  The timestamps share
  // the input Data write as their reference, so each row is a real data cone
  // rather than a synchronous STA max/max subtraction.
  real dp_data_start, dp_v1_q, dp_prs_rs, dp_head_mask, dp_tx_mask;
  real dp_opm_d, dp_opm_q;
  integer dp_mark_v1, dp_mark_prs, dp_mark_head, dp_mark_tx, dp_mark_opm_d, dp_mark_opm_q;

  task automatic dp_mark(input [8*28-1:0] rtc_id, input real t_end); begin
    $display("TB_DATAPATH_SAMPLE rtc=%0s start_ns=%0.3f end_ns=%0.3f tdata_ps=%0.3f",
      rtc_id, dp_data_start, t_end, (t_end-dp_data_start)*1000.0);
  end endtask

  always @(in_data[0]) if (!reset && !dp_mark_v1) begin
    dp_data_start = $realtime;
    $display("TB_DATAPATH_START t_ns=%0.3f data=%h", dp_data_start, in_data[0]);
  end
  always @(dut.inputModules_0.mousetrap.DataOut)
    if (!reset && dp_data_start > 0.0 && !dp_mark_v1) begin
      dp_mark_v1=1; dp_v1_q=$realtime; dp_mark("V1_CAPTURE", dp_v1_q);
    end
  always @(dut.inputModules_0_io_RS_3)
    if (!reset && dut.inputModules_0_io_RS_3 && dp_data_start > 0.0 && !dp_mark_prs) begin
      dp_mark_prs=1; dp_prs_rs=$realtime; dp_mark("PRS_DESCRIPTOR", dp_prs_rs);
    end
  always @(dut.admission.capture.packet_mask)
    if (!reset && (|dut.admission.capture.packet_mask) && dp_data_start > 0.0 && !dp_mark_head) begin
      dp_mark_head=1; dp_head_mask=$realtime; dp_mark("HEADCAP_DESCRIPTOR", dp_head_mask);
    end
  always @(dut.admission.tx.tx_mask0)
    if (!reset && (|dut.admission.tx.tx_mask0) && dp_data_start > 0.0 && !dp_mark_tx) begin
      dp_mark_tx=1; dp_tx_mask=$realtime; dp_mark("ATOMIC_DESCRIPTOR", dp_tx_mask);
    end
  always @(dut.outputModules_4.dataOutLatch.d)
    if (!reset && dp_data_start > 0.0 && !dp_mark_opm_d) begin
      dp_mark_opm_d=1; dp_opm_d=$realtime; dp_mark("OPM_V2_D", dp_opm_d);
    end
  always @(dut.outputModules_4.dataOutLatch.q)
    if (!reset && dp_data_start > 0.0 && !dp_mark_opm_q) begin
      dp_mark_opm_q=1; dp_opm_q=$realtime; dp_mark("OPM_V2_Q", dp_opm_q);
    end
  initial begin
    dp_data_start=0.0; dp_v1_q=0.0; dp_prs_rs=0.0; dp_head_mask=0.0; dp_tx_mask=0.0; dp_opm_d=0.0; dp_opm_q=0.0;
    dp_mark_v1=0; dp_mark_prs=0; dp_mark_head=0; dp_mark_tx=0; dp_mark_opm_d=0; dp_mark_opm_q=0;
  end
`endif

  genvar observed_port;
  generate for (observed_port = 0; observed_port < 5; observed_port = observed_port + 1) begin : g_rtm_data_observe
    always @(out_data[observed_port]) begin
      if (!reset) begin
        // V2 must be opaque after ReqOut becomes externally visible.  A later
        // data transition is a real bundled-data failure, never masked by the
        // receiver's delayed Ack.
        // The 5% assertion is currently signed off on the unicast target.
        // Other smoke cases remain functional regressions; their intentionally
        // skewed multicast branches are not yet an RTM measurement fixture.
        if (smoke_case == "unicast3" && out_req[observed_port] !== out_ack[observed_port])
          fail("data_changed_while_output_pending");
        last_out_data_time[observed_port] = $realtime;
      end
    end
  end endgenerate

  task automatic fail(input [8*120-1:0] reason); begin
    $display("TB_RESULT FAIL case=%0s reason=%0s t=%0t in=%b/%b out=%b/%b", smoke_case, reason, $time, in_req, in_ack, out_req, out_ack);
    $finish(1);
  end endtask

  task automatic enqueue_expect(input integer port, input [27:0] flit, input integer ack_delay_tenths,
                                input integer packet_id, input integer flit_index); begin
    if (expected_head[port] >= 32) fail("expected_fifo_overflow");
    expected_data[port][expected_head[port]] = flit;
    expected_delay[port][expected_head[port]] = ack_delay_tenths;
    expected_packet[port][expected_head[port]] = packet_id;
    expected_flit[port][expected_head[port]] = flit_index;
    expected_head[port] = expected_head[port] + 1;
  end endtask

  task automatic register_packet(input integer packet_id, input [4:0] targets); begin
    packet_targets[packet_id] = targets;
    packet_seen_h[packet_id] = 0; packet_seen_b[packet_id] = 0; packet_seen_t[packet_id] = 0;
    packet_active[packet_id] = 1; packet_complete[packet_id] = 0; packet_complete_time[packet_id] = 0.0;
  end endtask

  // Register the intended per-output order before injection. This keeps A->B
  // ordering correct when B reaches its input boundary while A is still active.
  task automatic enqueue_packet3(input integer packet_id, input [4:0] targets,
                                 input [27:0] h, input [27:0] b, input [27:0] t,
                                 input integer dh, input integer db, input integer dt);
    integer port;
  begin
    register_packet(packet_id, targets);
    for (port = 0; port < 5; port = port + 1)
      if (targets[port]) begin
        enqueue_expect(port, h, dh, packet_id, 0);
        enqueue_expect(port, b, db, packet_id, 1);
        enqueue_expect(port, t, dt, packet_id, 2);
      end
  end endtask

  task automatic mark_packet_delivery(input integer packet_id, input integer port, input integer flit_index); begin
    case (flit_index)
      0: packet_seen_h[packet_id][port] = 1'b1;
      1: packet_seen_b[packet_id][port] = 1'b1;
      2: packet_seen_t[packet_id][port] = 1'b1;
      default: fail("invalid_packet_flit_index");
    endcase
    if (!packet_complete[packet_id] &&
        packet_seen_h[packet_id] == packet_targets[packet_id] &&
        packet_seen_b[packet_id] == packet_targets[packet_id] &&
        packet_seen_t[packet_id] == packet_targets[packet_id]) begin
      packet_complete[packet_id] = 1'b1;
      packet_complete_time[packet_id] = $realtime;
      $display("TB_PACKET_COMPLETE case=%0s packet=%0d targets=%b t_ns=%0.3f",
               smoke_case, packet_id, packet_targets[packet_id], $realtime);
    end
  end endtask

  // This task is launched once per output.  It never waits for another output.
  task automatic output_agent(input integer port); integer slot; begin
    wait (reset === 1'b0);
    forever begin
      if (out_req[port] !== out_ack[port]) begin
        if (^out_req[port] === 1'bx) fail("output_req_x");
        if (expected_tail[port] >= expected_head[port]) fail("unexpected_output");
        slot = expected_tail[port];
        if (out_data[port] !== expected_data[port][slot]) begin
          $display("TB_DATA_MISMATCH case=%0s out%0d expected=%h actual=%h", smoke_case, port, expected_data[port][slot], out_data[port]);
          fail("output_data");
        end
        // Simulation-only RTC observation.  Both legs use the same external
        // ReqIn transition as reference: latest DataOut change before ReqOut
        // is the data leg, and ReqOut visibility is the control leg.  This
        // produces one physical SDF sample; multi-corner aggregation later
        // defines Tdata_max/Tctrl_min.  No TB action depends on this record.
        if (smoke_case == "unicast3" && port == 4 && slot < 3) begin
          // `rtm_data` is the physical data-path propagation.  The source
          // deliberately provides Data before Req, so visibility relative to
          // Req can be negative and is reported separately; it is not a
          // negative path delay.
          rtm_data = last_out_data_time[4] - last_in_data_time[0];
          rtm_control = $realtime - last_in_req_time[0];
          rtm_shortfall = ((last_out_data_time[4] - last_in_req_time[0]) * 1.05 > rtm_control) ?
                          ((last_out_data_time[4] - last_in_req_time[0]) * 1.05 - rtm_control) : 0.0;
          $display("TB_RTC_SAMPLE rtc=OPM_V2_CHILD0_PARENT phase=%0s flit=%0d datain_ns=%0.3f reqin_ns=%0.3f data_ns=%0.3f reqout_ns=%0.3f data_path_ns=%0.3f tdata_visible_ns=%0.3f tctrl_ns=%0.3f",
                   in_req[0] ? "rise" : "fall", slot, last_in_data_time[0], last_in_req_time[0],
                   last_out_data_time[4], $realtime, rtm_data,
                   last_out_data_time[4]-last_in_req_time[0], rtm_control);
          $display("TB_RTM flit=%h DataPath_ns=%0.3f TdataVisible_ns=%0.3f Tcontrol_ns=%0.3f shortfall_ns=%0.3f",
                   expected_data[port][slot], rtm_data,
                   last_out_data_time[4]-last_in_req_time[0], rtm_control, rtm_shortfall);
          if (enforce_rtm && rtm_shortfall > 0.0005) fail("rtm_5pct_shortfall");
        end
        $display("TB_EDGE case=%0s out%0d_req t_ns=%0.3f flit=%h", smoke_case, port, $realtime, expected_data[port][slot]);
        #(expected_delay[port][slot] * 0.1);
        out_ack[port] = out_req[port];
        expected_tail[port] = expected_tail[port] + 1;
        mark_packet_delivery(expected_packet[port][slot], port, expected_flit[port][slot]);
        $display("TB_EDGE case=%0s out%0d_ack t_ns=%0.3f", smoke_case, port, $realtime);
      end else #0.05;
    end
  end endtask

  initial output_agent(0); initial output_agent(1); initial output_agent(2);
  initial output_agent(3); initial output_agent(4);

  task automatic wait_input_slot(input integer port); integer timeout; begin
    timeout = 0;
    while (in_ack[port] !== in_req[port] && timeout < 20000) begin #0.1; timeout = timeout + 1; end
    if (timeout == 20000) fail("input_ack_timeout");
  end endtask

  task automatic send_flit(input integer port, input [27:0] flit); begin
    wait_input_slot(port);
    in_data[port] = flit;
    last_in_data_time[port] = $realtime;
    #0.2;
    in_req[port] = ~in_req[port];
    last_in_req_time[port] = $realtime;
    $display("TB_EDGE case=%0s in%0d_req t_ns=%0.3f flit=%h", smoke_case, port, $realtime, flit);
    wait_input_slot(port);
  end endtask

  // Every source waits for the current flit at every target output to be
  // acknowledged before replacing DataIn with the next flit.  The condition is
  // observed entirely at the external output boundary through the scoreboard.
  task automatic send_flit_and_drain_targets(input integer input_port, input [27:0] flit,
                                              input integer packet_id, input integer flit_index);
    integer timeout, flit_drained;
  begin
    send_flit(input_port, flit);
    timeout = 0; flit_drained = 0;
    while (timeout < 20000 && !flit_drained) begin
      if ((flit_index == 0 && packet_seen_h[packet_id] == packet_targets[packet_id]) ||
          (flit_index == 1 && packet_seen_b[packet_id] == packet_targets[packet_id]) ||
          (flit_index == 2 && packet_seen_t[packet_id] == packet_targets[packet_id])) begin
        #1.0;
        flit_drained = 1;
      end else begin
        #0.1; timeout = timeout + 1;
      end
    end
    if (!flit_drained) fail("target_output_timeout");
  end endtask

  task automatic send_packet3_boundary(input integer input_port, input integer packet_id,
                                        input [27:0] h, input [27:0] b, input [27:0] t); begin
    send_flit_and_drain_targets(input_port, h, packet_id, 0);
    send_flit_and_drain_targets(input_port, b, packet_id, 1);
    send_flit_and_drain_targets(input_port, t, packet_id, 2);
  end endtask

  // Simulation-only head helper for admission diagnosis.  It intentionally
  // registers no logical packet, because the experiment stops after a Head;
  // its purpose is to isolate Head admission from Tail/release behavior.
  task automatic send_head_and_drain_targets(input integer input_port,
                                              input [27:0] flit,
                                              input [4:0] targets);
    integer port, timeout;
  begin
    for (port = 0; port < 5; port = port + 1)
      if (targets[port]) enqueue_expect(port, flit, 2, 0, 0);
    send_flit(input_port, flit);
    timeout = 0;
    while (timeout < 20000 &&
           ((targets[0] && expected_tail[0] != expected_head[0]) ||
            (targets[1] && expected_tail[1] != expected_head[1]) ||
            (targets[2] && expected_tail[2] != expected_head[2]) ||
            (targets[3] && expected_tail[3] != expected_head[3]) ||
            (targets[4] && expected_tail[4] != expected_head[4]))) begin
      #0.1; timeout = timeout + 1;
    end
    if (timeout == 20000) fail("head_target_timeout");
    #1.0;
  end endtask

  // Historical single-Router signoff pacing: complete the externally visible
  // output handshake before changing DataIn for the following flit.  The
  // #1ns is boundary recovery time only; no internal signal is observed.
  task automatic send_unicast_flit_and_drain_parent(input [27:0] flit); integer timeout; begin
    enqueue_expect(4, flit, 2, 0, expected_head[4]);
    send_flit(0, flit);
    timeout = 0;
    while (expected_tail[4] != expected_head[4] && timeout < 20000) begin
      #0.1; timeout = timeout + 1;
    end
    if (timeout == 20000) fail("parent_output_timeout");
    #1.0;
  end endtask

  task automatic wait_drained; integer timeout, port; begin
    timeout = 0;
    while (timeout < 40000) begin
      for (port = 0; port < 5; port = port + 1)
        if (expected_tail[port] != expected_head[port] || out_req[port] !== out_ack[port]) break;
      if (port == 5) begin #1.0; // prove the boundary remains quiet after drain
        for (port = 0; port < 5; port = port + 1)
          if (expected_tail[port] != expected_head[port] || out_req[port] !== out_ack[port]) fail("post_drain_activity");
        disable wait_drained;
      end
      #0.1; timeout = timeout + 1;
    end
    fail("drain_timeout");
  end endtask

  task automatic check_packet_completeness; integer packet_id; begin
    for (packet_id = 0; packet_id < 8; packet_id = packet_id + 1) begin
      if (packet_active[packet_id]) begin
        if (!packet_complete[packet_id] ||
            packet_seen_h[packet_id] != packet_targets[packet_id] ||
            packet_seen_b[packet_id] != packet_targets[packet_id] ||
            packet_seen_t[packet_id] != packet_targets[packet_id])
          fail("packet_incomplete");
        $display("TB_PACKET_CHECK case=%0s packet=%0d targets=%b complete_t_ns=%0.3f",
                 smoke_case, packet_id, packet_targets[packet_id], packet_complete_time[packet_id]);
      end
    end
  end endtask

  task automatic run_unicast; begin
    register_packet(0, 5'b10000);
    send_unicast_flit_and_drain_parent(U_A_H);
    send_unicast_flit_and_drain_parent(U_A_B);
    send_unicast_flit_and_drain_parent(U_A_T);
  end endtask

  task automatic run_mc_single; begin
    enqueue_packet3(1, 5'b00011, MC_A_H, MC_A_B, MC_A_T, 2, 2, 2);
    expected_delay[1][0] = 6; expected_delay[1][1] = 6; expected_delay[1][2] = 6;
    send_packet3_boundary(4, 1, MC_A_H, MC_A_B, MC_A_T);
  end endtask

  task automatic run_mc_disjoint; begin
    enqueue_packet3(2, 5'b00011, MC_A_H, MC_A_B, MC_A_T, 2, 2, 2);
    enqueue_packet3(3, 5'b01100, MC_B_H, MC_B_B, MC_B_T, 2, 2, 2);
    expected_delay[1][0] = 6; expected_delay[1][1] = 6; expected_delay[1][2] = 6;
    expected_delay[3][0] = 6; expected_delay[3][1] = 6; expected_delay[3][2] = 6;
    fork
      send_packet3_boundary(4, 2, MC_A_H, MC_A_B, MC_A_T);
      begin #0.5; send_packet3_boundary(0, 3, MC_B_H, MC_B_B, MC_B_T); end
    join
  end endtask

  task automatic run_b_alone_head; begin
    send_head_and_drain_targets(0, MC_B_H, 5'b01100);
  end endtask

  task automatic run_a_then_b_head_parallel; begin
    fork
      send_head_and_drain_targets(4, MC_A_H, 5'b00011);
      begin #0.5; send_head_and_drain_targets(0, MC_B_H, 5'b01100); end
    join
  end endtask

  task automatic run_uc_overlap; begin
    enqueue_packet3(4, 5'b10000, U_A_H, U_A_B, U_A_T, 2, 2, 2);
    enqueue_packet3(5, 5'b10000, U_B_H, U_B_B, U_B_T, 2, 2, 2);
    fork
      send_packet3_boundary(0, 4, U_A_H, U_A_B, U_A_T);
      begin #0.5; send_packet3_boundary(1, 5, U_B_H, U_B_B, U_B_T); end
    join
  end endtask

  task automatic run_mc_overlap; begin
    // Each port's FIFO encodes A then B.  O0 may consume B before O1, but O1
    // cannot acknowledge or expose B until it has consumed A Tail itself.
    enqueue_packet3(6, 5'b00011, MC_A_H, MC_C_B, MC_C_T, 2, 2, 2);
    enqueue_packet3(7, 5'b00011, MC_A_H, MC_D_B, MC_D_T, 2, 2, 2);
    expected_delay[1][0] = 6; expected_delay[1][1] = 6; expected_delay[1][2] = 10;
    expected_delay[1][3] = 6; expected_delay[1][4] = 6; expected_delay[1][5] = 6;
    fork
      send_packet3_boundary(4, 6, MC_A_H, MC_C_B, MC_C_T);
      begin #0.5; send_packet3_boundary(2, 7, MC_A_H, MC_D_B, MC_D_T); end
    join
  end endtask

  initial begin
    enforce_rtm = 0;
    void'($value$plusargs("ENFORCE_RTM=%d", enforce_rtm));
    for (i = 0; i < 5; i = i + 1) begin
      in_data[i] = 0; expected_head[i] = 0; expected_tail[i] = 0;
      last_in_req_time[i] = 0.0; last_in_data_time[i] = 0.0; last_out_data_time[i] = 0.0;
    end
    for (i = 0; i < 8; i = i + 1) begin
      packet_targets[i] = 0; packet_seen_h[i] = 0; packet_seen_b[i] = 0; packet_seen_t[i] = 0;
      packet_active[i] = 0; packet_complete[i] = 0; packet_complete_time[i] = 0.0;
    end
    smoke_case = "unicast3";
    if (!$value$plusargs("SMOKE_CASE=%s", smoke_case)) smoke_case = "unicast3";
    // xsim requires a constant filename for $dumpfile; VCS accepts the same
    // form.  The runner moves the case-specific file into its result folder.
    if ($value$plusargs("DUMP_VCD=%s", dump_path)) begin
      if (smoke_case == "unicast3") $dumpfile("ultra_router_unicast3.vcd");
      else if (smoke_case == "mc_single3") $dumpfile("ultra_router_mc_single3.vcd");
      else if (smoke_case == "mc_disjoint_parallel3") $dumpfile("ultra_router_mc_disjoint_parallel3.vcd");
      else if (smoke_case == "uc_overlap_release3") $dumpfile("ultra_router_uc_overlap_release3.vcd");
      else if (smoke_case == "mc_overlap_tailjoin3") $dumpfile("ultra_router_mc_overlap_tailjoin3.vcd");
      else if (smoke_case == "b_alone_head") $dumpfile("ultra_router_b_alone_head.vcd");
      else if (smoke_case == "a_then_b_head_parallel") $dumpfile("ultra_router_a_then_b_head_parallel.vcd");
      else $dumpfile("ultra_router_unknown.vcd");
      $dumpvars(0, tb_ultra_router_boundary_smoke);
    end
    #20 reset = 0; #10;
    if (in_ack !== 0 || out_req !== 0) fail("reset_boundary");
    if (smoke_case == "unicast3") run_unicast();
    else if (smoke_case == "mc_single3") run_mc_single();
    else if (smoke_case == "mc_disjoint_parallel3") run_mc_disjoint();
    else if (smoke_case == "uc_overlap_release3") run_uc_overlap();
    else if (smoke_case == "mc_overlap_tailjoin3") run_mc_overlap();
    else if (smoke_case == "b_alone_head") run_b_alone_head();
    else if (smoke_case == "a_then_b_head_parallel") run_a_then_b_head_parallel();
    else fail("unknown_smoke_case");
    wait_drained();
    check_packet_completeness();
    $display("TB_RESULT PASS %0s", smoke_case);
    $finish;
  end
  initial begin #100000; fail("global_timeout"); end
endmodule
