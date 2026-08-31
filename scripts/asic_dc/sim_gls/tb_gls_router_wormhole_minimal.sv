`timescale 1ns/1ps

module tb_gls_router_wormhole_minimal;
  localparam FLIT_W = 28;
  localparam NUM_PORTS = 5;

  reg clock = 1'b0;
  reg reset = 1'b1;

  reg io_inputs_child_0_0_HS_Req = 1'b0;
  wire io_inputs_child_0_0_HS_Ack;
  reg [FLIT_W-1:0] io_inputs_child_0_0_Data_flit = '0;
  reg io_inputs_child_1_0_HS_Req = 1'b0;
  wire io_inputs_child_1_0_HS_Ack;
  reg [FLIT_W-1:0] io_inputs_child_1_0_Data_flit = '0;
  reg io_inputs_child_2_0_HS_Req = 1'b0;
  wire io_inputs_child_2_0_HS_Ack;
  reg [FLIT_W-1:0] io_inputs_child_2_0_Data_flit = '0;
  reg io_inputs_child_3_0_HS_Req = 1'b0;
  wire io_inputs_child_3_0_HS_Ack;
  reg [FLIT_W-1:0] io_inputs_child_3_0_Data_flit = '0;
  reg io_inputs_parent_0_HS_Req = 1'b0;
  wire io_inputs_parent_0_HS_Ack;
  reg [FLIT_W-1:0] io_inputs_parent_0_Data_flit = '0;

  wire io_outputs_child_0_0_HS_Req;
  reg io_outputs_child_0_0_HS_Ack = 1'b0;
  wire [FLIT_W-1:0] io_outputs_child_0_0_Data_flit;
  wire io_outputs_child_1_0_HS_Req;
  reg io_outputs_child_1_0_HS_Ack = 1'b0;
  wire [FLIT_W-1:0] io_outputs_child_1_0_Data_flit;
  wire io_outputs_child_2_0_HS_Req;
  reg io_outputs_child_2_0_HS_Ack = 1'b0;
  wire [FLIT_W-1:0] io_outputs_child_2_0_Data_flit;
  wire io_outputs_child_3_0_HS_Req;
  reg io_outputs_child_3_0_HS_Ack = 1'b0;
  wire [FLIT_W-1:0] io_outputs_child_3_0_Data_flit;
  wire io_outputs_parent_0_HS_Req;
  reg io_outputs_parent_0_HS_Ack = 1'b0;
  wire [FLIT_W-1:0] io_outputs_parent_0_Data_flit;

  wire [4:0] probe_input_valid;
  wire [4:0] probe_output_valid;
  wire [FLIT_W-1:0] probe_input_data [0:NUM_PORTS-1];
  wire [FLIT_W-1:0] probe_output_data [0:NUM_PORTS-1];
  wire [4:0] probe_route_mask [0:NUM_PORTS-1];
  wire [4:0] probe_request_mask [0:NUM_PORTS-1];
  wire [4:0] probe_output_winner [0:NUM_PORTS-1];
  wire [4:0] probe_granted_all;
  wire [4:0] probe_can_commit;
  wire [4:0] probe_winner;
  wire [4:0] probe_commit_conflict;
  wire probe_commit_raw;
  wire [4:0] probe_commit;
  wire [4:0] probe_input_capture_fire;
  wire [4:0] probe_commit_ready;
  wire probe_global_commit_event;
  wire [4:0] probe_output_req_pending;
  wire [4:0] probe_output_req_launch_event;
  wire [4:0] probe_input_slot_req;
  wire [4:0] probe_input_slot_ack;
  wire [4:0] probe_output_slot_req;
  wire [4:0] probe_output_slot_ack;
  wire [2:0] probe_output_holder [0:NUM_PORTS-1];
  wire [4:0] probe_context_active;
  wire [4:0] probe_context_mask [0:NUM_PORTS-1];

  reg hold_child0_ack = 1'b0;
  integer got0, got1, got2, got3, got4;
  integer fail_seen;
  integer gls_probe_enable;
  integer multi_hot_commit_seen;
  integer conflict_seen;
  integer output_data_hold_violation;
  reg [FLIT_W-1:0] seen0 [0:31];
  reg [FLIT_W-1:0] seen1 [0:31];
  reg [FLIT_W-1:0] seen2 [0:31];
  reg [FLIT_W-1:0] seen3 [0:31];
  reg [FLIT_W-1:0] seen4 [0:31];

  real t_parent_req_last;
  real t_parent_data_last;
  real t_input_valid4_rise;
  real t_input_capture_fire4_rise;
  real t_commit_raw_rise;
  real t_global_commit_rise;
  real t_global_commit_prev_rise;
  real t_output_slot_req0_change;
  real t_output_data0_change;
  real t_output_req_launch0_high_start;
  real t_out_req0_change;
  real t_send_head_req;
  real t_send_body_req;
  real t_send_tail_req;
  real t_send_busy_req;
  real t_input_data4_change;
  real t_request_mask4_change;
  real t_commit4_rise;
  real t_commit_high_start0;
  real t_commit_high_start1;
  real t_commit_high_start2;
  real t_commit_high_start3;
  real t_commit_high_start4;
  real t_fire_a_high_start [0:NUM_PORTS-1];
  real t_global_high_start;
  integer commit_high_count;

  always #5 clock = ~clock;

  task metric;
    input [127:0] domain;
    input [255:0] name;
    input integer idx;
    input real value_ns;
    begin
      if (gls_probe_enable) begin
        $display("SDF_METRIC domain=%0s name=%0s idx=%0d value_ns=%0.3f",
                 domain, name, idx, value_ns);
      end
    end
  endtask

  function [FLIT_W-1:0] flit;
    input [1:0] id;
    input [5:0] x0;
    input [5:0] y0;
    input [5:0] x1;
    input [5:0] y1;
    input is_tail;
    input is_head;
    begin
      flit = {is_head, is_tail, y1, x1, y0, x0, id};
    end
  endfunction

  function integer pop5;
    input [4:0] v;
    integer k;
    begin
      pop5 = 0;
      for (k = 0; k < 5; k = k + 1)
        pop5 = pop5 + v[k];
    end
  endfunction

  RouterL1WormholeMinimal dut (
    .clock(clock),
    .reset(reset),
    .io_inputs_child_0_0_HS_Req(io_inputs_child_0_0_HS_Req),
    .io_inputs_child_0_0_HS_Ack(io_inputs_child_0_0_HS_Ack),
    .io_inputs_child_0_0_Data_flit(io_inputs_child_0_0_Data_flit),
    .io_inputs_child_1_0_HS_Req(io_inputs_child_1_0_HS_Req),
    .io_inputs_child_1_0_HS_Ack(io_inputs_child_1_0_HS_Ack),
    .io_inputs_child_1_0_Data_flit(io_inputs_child_1_0_Data_flit),
    .io_inputs_child_2_0_HS_Req(io_inputs_child_2_0_HS_Req),
    .io_inputs_child_2_0_HS_Ack(io_inputs_child_2_0_HS_Ack),
    .io_inputs_child_2_0_Data_flit(io_inputs_child_2_0_Data_flit),
    .io_inputs_child_3_0_HS_Req(io_inputs_child_3_0_HS_Req),
    .io_inputs_child_3_0_HS_Ack(io_inputs_child_3_0_HS_Ack),
    .io_inputs_child_3_0_Data_flit(io_inputs_child_3_0_Data_flit),
    .io_inputs_parent_0_HS_Req(io_inputs_parent_0_HS_Req),
    .io_inputs_parent_0_HS_Ack(io_inputs_parent_0_HS_Ack),
    .io_inputs_parent_0_Data_flit(io_inputs_parent_0_Data_flit),
    .io_outputs_child_0_0_HS_Req(io_outputs_child_0_0_HS_Req),
    .io_outputs_child_0_0_HS_Ack(io_outputs_child_0_0_HS_Ack),
    .io_outputs_child_0_0_Data_flit(io_outputs_child_0_0_Data_flit),
    .io_outputs_child_1_0_HS_Req(io_outputs_child_1_0_HS_Req),
    .io_outputs_child_1_0_HS_Ack(io_outputs_child_1_0_HS_Ack),
    .io_outputs_child_1_0_Data_flit(io_outputs_child_1_0_Data_flit),
    .io_outputs_child_2_0_HS_Req(io_outputs_child_2_0_HS_Req),
    .io_outputs_child_2_0_HS_Ack(io_outputs_child_2_0_HS_Ack),
    .io_outputs_child_2_0_Data_flit(io_outputs_child_2_0_Data_flit),
    .io_outputs_child_3_0_HS_Req(io_outputs_child_3_0_HS_Req),
    .io_outputs_child_3_0_HS_Ack(io_outputs_child_3_0_HS_Ack),
    .io_outputs_child_3_0_Data_flit(io_outputs_child_3_0_Data_flit),
    .io_outputs_parent_0_HS_Req(io_outputs_parent_0_HS_Req),
    .io_outputs_parent_0_HS_Ack(io_outputs_parent_0_HS_Ack),
    .io_outputs_parent_0_Data_flit(io_outputs_parent_0_Data_flit),
    .io_probe_inputValid_0(probe_input_valid[0]),
    .io_probe_inputValid_1(probe_input_valid[1]),
    .io_probe_inputValid_2(probe_input_valid[2]),
    .io_probe_inputValid_3(probe_input_valid[3]),
    .io_probe_inputValid_4(probe_input_valid[4]),
    .io_probe_outputValid_0(probe_output_valid[0]),
    .io_probe_outputValid_1(probe_output_valid[1]),
    .io_probe_outputValid_2(probe_output_valid[2]),
    .io_probe_outputValid_3(probe_output_valid[3]),
    .io_probe_outputValid_4(probe_output_valid[4]),
    .io_probe_inputData_0_flit(probe_input_data[0]),
    .io_probe_inputData_1_flit(probe_input_data[1]),
    .io_probe_inputData_2_flit(probe_input_data[2]),
    .io_probe_inputData_3_flit(probe_input_data[3]),
    .io_probe_inputData_4_flit(probe_input_data[4]),
    .io_probe_outputData_0_flit(probe_output_data[0]),
    .io_probe_outputData_1_flit(probe_output_data[1]),
    .io_probe_outputData_2_flit(probe_output_data[2]),
    .io_probe_outputData_3_flit(probe_output_data[3]),
    .io_probe_outputData_4_flit(probe_output_data[4]),
    .io_probe_routeMask_0(probe_route_mask[0]),
    .io_probe_routeMask_1(probe_route_mask[1]),
    .io_probe_routeMask_2(probe_route_mask[2]),
    .io_probe_routeMask_3(probe_route_mask[3]),
    .io_probe_routeMask_4(probe_route_mask[4]),
    .io_probe_requestMask_0(probe_request_mask[0]),
    .io_probe_requestMask_1(probe_request_mask[1]),
    .io_probe_requestMask_2(probe_request_mask[2]),
    .io_probe_requestMask_3(probe_request_mask[3]),
    .io_probe_requestMask_4(probe_request_mask[4]),
    .io_probe_outputWinner_0(probe_output_winner[0]),
    .io_probe_outputWinner_1(probe_output_winner[1]),
    .io_probe_outputWinner_2(probe_output_winner[2]),
    .io_probe_outputWinner_3(probe_output_winner[3]),
    .io_probe_outputWinner_4(probe_output_winner[4]),
    .io_probe_grantedAll_0(probe_granted_all[0]),
    .io_probe_grantedAll_1(probe_granted_all[1]),
    .io_probe_grantedAll_2(probe_granted_all[2]),
    .io_probe_grantedAll_3(probe_granted_all[3]),
    .io_probe_grantedAll_4(probe_granted_all[4]),
    .io_probe_canCommit_0(probe_can_commit[0]),
    .io_probe_canCommit_1(probe_can_commit[1]),
    .io_probe_canCommit_2(probe_can_commit[2]),
    .io_probe_canCommit_3(probe_can_commit[3]),
    .io_probe_canCommit_4(probe_can_commit[4]),
    .io_probe_winner_0(probe_winner[0]),
    .io_probe_winner_1(probe_winner[1]),
    .io_probe_winner_2(probe_winner[2]),
    .io_probe_winner_3(probe_winner[3]),
    .io_probe_winner_4(probe_winner[4]),
    .io_probe_commitConflict_0(probe_commit_conflict[0]),
    .io_probe_commitConflict_1(probe_commit_conflict[1]),
    .io_probe_commitConflict_2(probe_commit_conflict[2]),
    .io_probe_commitConflict_3(probe_commit_conflict[3]),
    .io_probe_commitConflict_4(probe_commit_conflict[4]),
    .io_probe_commitRaw(probe_commit_raw),
    .io_probe_commit_0(probe_commit[0]),
    .io_probe_commit_1(probe_commit[1]),
    .io_probe_commit_2(probe_commit[2]),
    .io_probe_commit_3(probe_commit[3]),
    .io_probe_commit_4(probe_commit[4]),
    .io_probe_inputCaptureFire_0(probe_input_capture_fire[0]),
    .io_probe_inputCaptureFire_1(probe_input_capture_fire[1]),
    .io_probe_inputCaptureFire_2(probe_input_capture_fire[2]),
    .io_probe_inputCaptureFire_3(probe_input_capture_fire[3]),
    .io_probe_inputCaptureFire_4(probe_input_capture_fire[4]),
    .io_probe_commitReady_0(probe_commit_ready[0]),
    .io_probe_commitReady_1(probe_commit_ready[1]),
    .io_probe_commitReady_2(probe_commit_ready[2]),
    .io_probe_commitReady_3(probe_commit_ready[3]),
    .io_probe_commitReady_4(probe_commit_ready[4]),
    .io_probe_globalCommitEvent(probe_global_commit_event),
    .io_probe_outputReqPending_0(probe_output_req_pending[0]),
    .io_probe_outputReqPending_1(probe_output_req_pending[1]),
    .io_probe_outputReqPending_2(probe_output_req_pending[2]),
    .io_probe_outputReqPending_3(probe_output_req_pending[3]),
    .io_probe_outputReqPending_4(probe_output_req_pending[4]),
    .io_probe_outputReqLaunchEvent_0(probe_output_req_launch_event[0]),
    .io_probe_outputReqLaunchEvent_1(probe_output_req_launch_event[1]),
    .io_probe_outputReqLaunchEvent_2(probe_output_req_launch_event[2]),
    .io_probe_outputReqLaunchEvent_3(probe_output_req_launch_event[3]),
    .io_probe_outputReqLaunchEvent_4(probe_output_req_launch_event[4]),
    .io_probe_inputSlotReq_0(probe_input_slot_req[0]),
    .io_probe_inputSlotReq_1(probe_input_slot_req[1]),
    .io_probe_inputSlotReq_2(probe_input_slot_req[2]),
    .io_probe_inputSlotReq_3(probe_input_slot_req[3]),
    .io_probe_inputSlotReq_4(probe_input_slot_req[4]),
    .io_probe_inputSlotAck_0(probe_input_slot_ack[0]),
    .io_probe_inputSlotAck_1(probe_input_slot_ack[1]),
    .io_probe_inputSlotAck_2(probe_input_slot_ack[2]),
    .io_probe_inputSlotAck_3(probe_input_slot_ack[3]),
    .io_probe_inputSlotAck_4(probe_input_slot_ack[4]),
    .io_probe_outputSlotReq_0(probe_output_slot_req[0]),
    .io_probe_outputSlotReq_1(probe_output_slot_req[1]),
    .io_probe_outputSlotReq_2(probe_output_slot_req[2]),
    .io_probe_outputSlotReq_3(probe_output_slot_req[3]),
    .io_probe_outputSlotReq_4(probe_output_slot_req[4]),
    .io_probe_outputSlotAck_0(probe_output_slot_ack[0]),
    .io_probe_outputSlotAck_1(probe_output_slot_ack[1]),
    .io_probe_outputSlotAck_2(probe_output_slot_ack[2]),
    .io_probe_outputSlotAck_3(probe_output_slot_ack[3]),
    .io_probe_outputSlotAck_4(probe_output_slot_ack[4]),
    .io_probe_outputHolder_0(probe_output_holder[0]),
    .io_probe_outputHolder_1(probe_output_holder[1]),
    .io_probe_outputHolder_2(probe_output_holder[2]),
    .io_probe_outputHolder_3(probe_output_holder[3]),
    .io_probe_outputHolder_4(probe_output_holder[4]),
    .io_probe_contextActive_0(probe_context_active[0]),
    .io_probe_contextActive_1(probe_context_active[1]),
    .io_probe_contextActive_2(probe_context_active[2]),
    .io_probe_contextActive_3(probe_context_active[3]),
    .io_probe_contextActive_4(probe_context_active[4]),
    .io_probe_contextMask_0(probe_context_mask[0]),
    .io_probe_contextMask_1(probe_context_mask[1]),
    .io_probe_contextMask_2(probe_context_mask[2]),
    .io_probe_contextMask_3(probe_context_mask[3]),
    .io_probe_contextMask_4(probe_context_mask[4])
  );

  task send_parent;
    input [FLIT_W-1:0] f;
    input integer kind;
    integer guard;
    begin
      io_inputs_parent_0_Data_flit = f;
      t_parent_data_last = $realtime;
      #1;
      io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
      t_parent_req_last = $realtime;
      if (kind == 0) t_send_head_req = $realtime;
      if (kind == 1) t_send_body_req = $realtime;
      if (kind == 2) t_send_tail_req = $realtime;
      if (kind == 3) t_send_busy_req = $realtime;
      guard = 0;
      while (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req && guard < 10000) begin
        #1;
        guard = guard + 1;
      end
      if (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req) begin
        $display("TB_RESULT FAIL send_parent timeout t=%0t flit=%h", $time, f);
        $display("TB_DEBUG parent req=%b ack=%b inV=%b slotReq=%b slotAck=%b capFire=%b commitReady=%b winner=%b canCommit=%b commit=%b raw=%b global=%b",
                 io_inputs_parent_0_HS_Req, io_inputs_parent_0_HS_Ack,
                 probe_input_valid[4], probe_input_slot_req[4], probe_input_slot_ack[4],
                 probe_input_capture_fire[4], probe_commit_ready[4], probe_winner[4],
                 probe_can_commit[4], probe_commit[4], probe_commit_raw,
                 probe_global_commit_event);
        $display("TB_DEBUG parent data inData=%h reqMask=%b routeMask=%b ctxAct=%b ctxMask=%b outV=%b outHold0=%0d outSlotReq=%b outSlotAck=%b outData0=%h",
                 probe_input_data[4], probe_request_mask[4], probe_route_mask[4],
                 probe_context_active[4], probe_context_mask[4],
                 probe_output_valid, probe_output_holder[0],
                 probe_output_slot_req, probe_output_slot_ack, probe_output_data[0]);
        $finish(1);
      end
      #1;
    end
  endtask

  task automatic wait_parent_ack;
    integer guard;
    begin
      guard = 0;
      while (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req && guard < 10000) begin
        #1;
        guard = guard + 1;
      end
      if (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req) begin
        $display("TB_RESULT FAIL wait_parent_ack timeout t=%0t", $time);
        $finish(1);
      end
    end
  endtask

  task automatic wait_child0_ack;
    integer guard;
    begin
      guard = 0;
      while (io_inputs_child_0_0_HS_Ack != io_inputs_child_0_0_HS_Req && guard < 10000) begin
        #1;
        guard = guard + 1;
      end
      if (io_inputs_child_0_0_HS_Ack != io_inputs_child_0_0_HS_Req) begin
        $display("TB_RESULT FAIL wait_child0_ack timeout t=%0t", $time);
        $finish(1);
      end
    end
  endtask

  task automatic wait_child1_ack;
    integer guard;
    begin
      guard = 0;
      while (io_inputs_child_1_0_HS_Ack != io_inputs_child_1_0_HS_Req && guard < 10000) begin
        #1;
        guard = guard + 1;
      end
      if (io_inputs_child_1_0_HS_Ack != io_inputs_child_1_0_HS_Req) begin
        $display("TB_RESULT FAIL wait_child1_ack timeout t=%0t", $time);
        $finish(1);
      end
    end
  endtask

  always @(probe_input_data[4]) t_input_data4_change = $realtime;
  always @(probe_request_mask[4]) t_request_mask4_change = $realtime;
  always @(probe_output_slot_req[0]) t_output_slot_req0_change = $realtime;
  always @(probe_output_data[0]) begin
    t_output_data0_change = $realtime;
    if (!reset) begin
      metric("OUT", "T_output_data_after_commit_raw", 0, $realtime - t_commit_raw_rise);
      metric("OUT", "T_output_data_after_global", 0, $realtime - t_global_commit_rise);
    end
  end
  always @(posedge probe_output_req_launch_event[0]) begin
    t_output_req_launch0_high_start = $realtime;
    metric("OM", "T_output_data_to_req_setup", 0, $realtime - t_output_data0_change);
  end
  always @(negedge probe_output_req_launch_event[0]) begin
    metric("OM", "T_outputReqLaunch_pw", 0, $realtime - t_output_req_launch0_high_start);
  end

  always @(posedge probe_input_capture_fire[4]) begin
    t_input_capture_fire4_rise = $realtime;
    t_fire_a_high_start[4] = $realtime;
    metric("A", "T_del_A", 4, $realtime - t_parent_req_last);
    metric("A", "T_data_to_fire_setup", 4, $realtime - t_parent_data_last);
  end
  always @(negedge probe_input_capture_fire[4]) begin
    metric("A", "T_fire_A_pw", 4, $realtime - t_fire_a_high_start[4]);
  end
  always @(io_inputs_parent_0_HS_Ack) begin
    if (!reset) metric("A", "T_fire_A_to_ext_ack", 4, $realtime - t_input_capture_fire4_rise);
  end

  always @(posedge probe_input_valid[4]) begin
    t_input_valid4_rise = $realtime;
  end
  always @(negedge probe_input_valid[4]) begin
    metric("B", "T_ack_fall", 4, $realtime - t_global_commit_rise);
  end
  always @(posedge probe_commit_ready[4]) begin
    metric("B", "T_del_input_i", 4, $realtime - t_input_valid4_rise);
  end
  always @(posedge probe_winner[4]) begin
    metric("B", "T_combo_winner", 4, $realtime - t_input_valid4_rise);
  end

  always @(posedge probe_commit[0]) begin
    t_commit_high_start0 = $realtime;
    commit_high_count = commit_high_count + 1;
    if (commit_high_count > 1) metric("B", "T_commit_overlap_allowed", 0, commit_high_count);
  end
  always @(negedge probe_commit[0]) begin
    metric("B", "T_commit_i_pw", 0, $realtime - t_commit_high_start0);
    commit_high_count = commit_high_count - 1;
  end
  always @(posedge probe_commit[1]) begin
    t_commit_high_start1 = $realtime;
    commit_high_count = commit_high_count + 1;
    if (commit_high_count > 1) metric("B", "T_commit_overlap_allowed", 1, commit_high_count);
  end
  always @(negedge probe_commit[1]) begin
    metric("B", "T_commit_i_pw", 1, $realtime - t_commit_high_start1);
    commit_high_count = commit_high_count - 1;
  end
  always @(posedge probe_commit[2]) begin
    t_commit_high_start2 = $realtime;
    commit_high_count = commit_high_count + 1;
    if (commit_high_count > 1) metric("B", "T_commit_overlap_allowed", 2, commit_high_count);
  end
  always @(negedge probe_commit[2]) begin
    metric("B", "T_commit_i_pw", 2, $realtime - t_commit_high_start2);
    commit_high_count = commit_high_count - 1;
  end
  always @(posedge probe_commit[3]) begin
    t_commit_high_start3 = $realtime;
    commit_high_count = commit_high_count + 1;
    if (commit_high_count > 1) metric("B", "T_commit_overlap_allowed", 3, commit_high_count);
  end
  always @(negedge probe_commit[3]) begin
    metric("B", "T_commit_i_pw", 3, $realtime - t_commit_high_start3);
    commit_high_count = commit_high_count - 1;
  end
  always @(posedge probe_commit[4]) begin
    t_commit_high_start4 = $realtime;
    t_commit4_rise = $realtime;
    commit_high_count = commit_high_count + 1;
    if (commit_high_count > 1) metric("B", "T_commit_overlap_allowed", 4, commit_high_count);
  end
  always @(negedge probe_commit[4]) begin
    metric("B", "T_commit_i_pw", 4, $realtime - t_commit_high_start4);
    commit_high_count = commit_high_count - 1;
  end

  always @(posedge probe_commit_raw) begin
    t_commit_raw_rise = $realtime;
    metric("B", "T_commitLevel_to_commitRaw", 4, $realtime - t_commit4_rise);
  end
  always @(posedge probe_global_commit_event) begin
    t_global_commit_prev_rise = t_global_commit_rise;
    t_global_commit_rise = $realtime;
    t_global_high_start = $realtime;
    metric("B", "T_del_global", 0, $realtime - t_commit_raw_rise);
    metric("B", "T_data_setup_B", 4, $realtime - t_input_data4_change);
    metric("B", "T_mask_setup_B", 4, $realtime - t_request_mask4_change);
    if (t_global_commit_prev_rise > 0.0)
      metric("B", "T_inter_commit", 0, $realtime - t_global_commit_prev_rise);
  end
  always @(negedge probe_global_commit_event) begin
    metric("B", "T_globalCommitEvent_pw", 0, $realtime - t_global_high_start);
  end

  always @(io_outputs_child_0_0_HS_Req) begin
    if (!reset && io_outputs_child_0_0_HS_Req != io_outputs_child_0_0_HS_Ack) begin
      t_out_req0_change = $realtime;
      metric("OUT", "T_out_req_after_global", 0, $realtime - t_global_commit_rise);
      metric("OUT", "T_output_data_to_req_setup", 0, $realtime - t_output_data0_change);
      if (got0 == 0) metric("E2E", "E2E_head_REQ_EDGE_NS", 0, $realtime - t_send_head_req);
      if (got0 == 1) metric("E2E", "E2E_body_REQ_EDGE_NS", 0, $realtime - t_send_body_req);
      if (got0 == 2) metric("E2E", "E2E_tail_REQ_EDGE_NS", 0, $realtime - t_send_tail_req);
      #1.0;
      metric("E2E", "RECEIVER_SAMPLE_OVERHEAD_NS", 0, $realtime - t_out_req0_change);
      if (got0 == 0) begin
        metric("E2E", "E2E_head_SAMPLED_NS", 0, $realtime - t_send_head_req);
        metric("E2E", "E2E_head", 0, $realtime - t_send_head_req);
      end
      if (got0 == 1) begin
        metric("E2E", "E2E_body_SAMPLED_NS", 0, $realtime - t_send_body_req);
        metric("E2E", "E2E_body", 0, $realtime - t_send_body_req);
      end
      if (got0 == 2) begin
        metric("E2E", "E2E_tail_SAMPLED_NS", 0, $realtime - t_send_tail_req);
        metric("E2E", "E2E_tail", 0, $realtime - t_send_tail_req);
      end
      if (got0 == 6) metric("E2E", "E2E_downstream_busy_headtail", 0, $realtime - t_send_busy_req);
      seen0[got0] = io_outputs_child_0_0_Data_flit;
      got0 = got0 + 1;
      $display("TB_OUT child0 t=%0t data=%h", $time, io_outputs_child_0_0_Data_flit);
      if (!hold_child0_ack) io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Req;
    end
  end

  always @(io_outputs_child_1_0_HS_Req) begin
    if (!reset && io_outputs_child_1_0_HS_Req != io_outputs_child_1_0_HS_Ack) begin
      #1.0; seen1[got1] = io_outputs_child_1_0_Data_flit; got1 = got1 + 1;
      io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Req;
    end
  end
  always @(io_outputs_child_2_0_HS_Req) begin
    if (!reset && io_outputs_child_2_0_HS_Req != io_outputs_child_2_0_HS_Ack) begin
      #1.0; seen2[got2] = io_outputs_child_2_0_Data_flit; got2 = got2 + 1;
      io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Req;
    end
  end
  always @(io_outputs_child_3_0_HS_Req) begin
    if (!reset && io_outputs_child_3_0_HS_Req != io_outputs_child_3_0_HS_Ack) begin
      #1.0; seen3[got3] = io_outputs_child_3_0_Data_flit; got3 = got3 + 1;
      io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Req;
    end
  end
  always @(io_outputs_parent_0_HS_Req) begin
    if (!reset && io_outputs_parent_0_HS_Req != io_outputs_parent_0_HS_Ack) begin
      #1.0;
      seen4[got4] = io_outputs_parent_0_Data_flit;
      got4 = got4 + 1;
      $display("TB_OUT parent t=%0t data=%h", $time, io_outputs_parent_0_Data_flit);
      io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Req;
    end
  end

  always @(io_outputs_child_0_0_Data_flit) begin
    if (!reset && io_outputs_child_0_0_HS_Req != io_outputs_child_0_0_HS_Ack) begin
      output_data_hold_violation = 1;
      $display("TB_RESULT FAIL output_data_hold port=0 t=%0t req=%b ack=%b data=%h",
               $time, io_outputs_child_0_0_HS_Req, io_outputs_child_0_0_HS_Ack,
               io_outputs_child_0_0_Data_flit);
      $finish(1);
    end
  end

  always @(io_outputs_child_1_0_Data_flit) begin
    if (!reset && io_outputs_child_1_0_HS_Req != io_outputs_child_1_0_HS_Ack) begin
      output_data_hold_violation = 1;
      $display("TB_RESULT FAIL output_data_hold port=1 t=%0t req=%b ack=%b data=%h",
               $time, io_outputs_child_1_0_HS_Req, io_outputs_child_1_0_HS_Ack,
               io_outputs_child_1_0_Data_flit);
      $finish(1);
    end
  end

  always @(io_outputs_child_2_0_Data_flit) begin
    if (!reset && io_outputs_child_2_0_HS_Req != io_outputs_child_2_0_HS_Ack) begin
      output_data_hold_violation = 1;
      $display("TB_RESULT FAIL output_data_hold port=2 t=%0t req=%b ack=%b data=%h",
               $time, io_outputs_child_2_0_HS_Req, io_outputs_child_2_0_HS_Ack,
               io_outputs_child_2_0_Data_flit);
      $finish(1);
    end
  end

  always @(io_outputs_child_3_0_Data_flit) begin
    if (!reset && io_outputs_child_3_0_HS_Req != io_outputs_child_3_0_HS_Ack) begin
      output_data_hold_violation = 1;
      $display("TB_RESULT FAIL output_data_hold port=3 t=%0t req=%b ack=%b data=%h",
               $time, io_outputs_child_3_0_HS_Req, io_outputs_child_3_0_HS_Ack,
               io_outputs_child_3_0_Data_flit);
      $finish(1);
    end
  end

  always @(io_outputs_parent_0_Data_flit) begin
    if (!reset && io_outputs_parent_0_HS_Req != io_outputs_parent_0_HS_Ack) begin
      output_data_hold_violation = 1;
      $display("TB_RESULT FAIL output_data_hold port=4 t=%0t req=%b ack=%b data=%h",
               $time, io_outputs_parent_0_HS_Req, io_outputs_parent_0_HS_Ack,
               io_outputs_parent_0_Data_flit);
      $finish(1);
    end
  end

  always @(probe_commit) begin
    if (!reset && pop5(probe_commit) > 1) begin
      multi_hot_commit_seen = 1;
      if (gls_probe_enable)
        $display("TB_PROBE multi_commit t=%0t commit=%b conflict=%b",
                 $time, probe_commit, probe_commit_conflict);
    end
  end

  always @(posedge probe_global_commit_event) begin
    if (!reset && pop5(probe_commit) > 1) begin
      multi_hot_commit_seen = 1;
      metric("B", "multi_hot_global_commit_seen", 0, 1.0);
      if (gls_probe_enable)
        $display("TB_PROBE multi_global_commit t=%0t commit=%b conflict=%b",
                 $time, probe_commit, probe_commit_conflict);
    end
  end

  always @(probe_commit_conflict) begin
    if (!reset && probe_commit_conflict != 5'b00000) begin
      conflict_seen = 1;
      $display("TB_RESULT FAIL commit_conflict t=%0t commit=%b conflict=%b outputWinner0=%b outputWinner4=%b",
               $time, probe_commit, probe_commit_conflict,
               probe_output_winner[0], probe_output_winner[4]);
      $finish(1);
    end
  end

  always @(probe_output_holder[0]) begin
    if (!reset && probe_output_holder[0] == 3'd5)
      metric("E2E", "E2E_tail_release", 0, $realtime - t_global_commit_rise);
  end

  initial begin
    integer dbg_i;
    gls_probe_enable = 1;
    if (!$value$plusargs("GLS_PROBE=%d", gls_probe_enable)) gls_probe_enable = 1;
    got0 = 0; got1 = 0; got2 = 0; got3 = 0; got4 = 0;
    fail_seen = 0;
    multi_hot_commit_seen = 0;
    conflict_seen = 0;
    output_data_hold_violation = 0;
    commit_high_count = 0;
    t_global_commit_rise = 0.0;
    t_global_commit_prev_rise = 0.0;
    #20 reset = 1'b0;
    #5;

    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b0, 1'b1), 0);
    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b0, 1'b0), 1);
    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b0), 2);

    send_parent(28'h8104000, 0);
    send_parent(28'h0104000, 1);
    send_parent(28'h4104000, 2);

    hold_child0_ack = 1'b1;
    send_parent(flit(2'd1, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1), 3);
    #10;
    if (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req ||
        io_outputs_child_0_0_HS_Req == io_outputs_child_0_0_HS_Ack) begin
      $display("TB_RESULT FAIL downstream_busy_commit t=%0t", $time);
      $finish(1);
    end
    hold_child0_ack = 1'b0;
    io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Req;

    // parallel_disjoint_unicast: parent -> child0 and child0 -> parent.
    io_inputs_parent_0_Data_flit = flit(2'd2, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1);
    io_inputs_child_0_0_Data_flit = flit(2'd2, 6'd9, 6'd8, 6'd9, 6'd8, 1'b1, 1'b1);
    #5;
    io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
    io_inputs_child_0_0_HS_Req = ~io_inputs_child_0_0_HS_Req;
    wait_parent_ack();
    wait_child0_ack();
    #10;

    // parallel_conflict_unicast: child0 and child1 both request parent; fixed
    // priority commits child0 first, then child1 retries.
    io_inputs_child_0_0_Data_flit = flit(2'd3, 6'd9, 6'd8, 6'd9, 6'd8, 1'b1, 1'b1);
    io_inputs_child_1_0_Data_flit = flit(2'd0, 6'd8, 6'd8, 6'd8, 6'd8, 1'b1, 1'b1);
    #5;
    io_inputs_child_0_0_HS_Req = ~io_inputs_child_0_0_HS_Req;
    io_inputs_child_1_0_HS_Req = ~io_inputs_child_1_0_HS_Req;
    wait_child0_ack();
    wait_child1_ack();
    #10;

    // parallel_multicast_all_or_nothing: child1 takes child0 first, parent
    // multicast must wait and then commit to all four child outputs.
    io_inputs_parent_0_Data_flit = flit(2'd1, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1);
    io_inputs_child_1_0_Data_flit = flit(2'd3, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1);
    #5;
    io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
    io_inputs_child_1_0_HS_Req = ~io_inputs_child_1_0_HS_Req;
    wait_child1_ack();
    wait_parent_ack();
    #10;

    // parallel_multicast_disjoint: parent multicast to children and child0 to
    // parent commit in the same event.
    io_inputs_parent_0_Data_flit = flit(2'd2, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1);
    io_inputs_child_0_0_Data_flit = flit(2'd1, 6'd8, 6'd8, 6'd8, 6'd8, 1'b1, 1'b1);
    #5;
    io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
    io_inputs_child_0_0_HS_Req = ~io_inputs_child_0_0_HS_Req;
    wait_parent_ack();
    wait_child0_ack();
    #10;

    #400;
    if (got0 == 11 && got1 == 5 && got2 == 5 && got3 == 5 && got4 == 4 &&
        multi_hot_commit_seen && !conflict_seen &&
        !output_data_hold_violation &&
        seen0[0] == 28'h8104104 && seen0[1] == 28'h0104104 &&
        seen0[2] == 28'h4104104 && seen0[3] == 28'h8104000 &&
        seen0[4] == 28'h0104000 && seen0[5] == 28'h4104000 &&
        seen0[6] == flit(2'd1, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen0[7] == flit(2'd2, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen0[8] == flit(2'd3, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen0[9] == flit(2'd1, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen0[10] == flit(2'd2, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen1[0] == 28'h8104000 && seen1[1] == 28'h0104000 &&
        seen1[2] == 28'h4104000 &&
        seen1[3] == flit(2'd1, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen1[4] == flit(2'd2, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen2[0] == 28'h8104000 && seen2[1] == 28'h0104000 &&
        seen2[2] == 28'h4104000 &&
        seen2[3] == flit(2'd1, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen2[4] == flit(2'd2, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen3[0] == 28'h8104000 && seen3[1] == 28'h0104000 &&
        seen3[2] == 28'h4104000 &&
        seen3[3] == flit(2'd1, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen3[4] == flit(2'd2, 6'd0, 6'd0, 6'd1, 6'd1, 1'b1, 1'b1) &&
        seen4[0] == flit(2'd2, 6'd9, 6'd8, 6'd9, 6'd8, 1'b1, 1'b1) &&
        seen4[1] == flit(2'd3, 6'd9, 6'd8, 6'd9, 6'd8, 1'b1, 1'b1) &&
        seen4[2] == flit(2'd0, 6'd8, 6'd8, 6'd8, 6'd8, 1'b1, 1'b1) &&
        seen4[3] == flit(2'd1, 6'd8, 6'd8, 6'd8, 6'd8, 1'b1, 1'b1)) begin
      $display("TB_RESULT PASS got0=%0d got1=%0d got2=%0d got3=%0d got4=%0d multi=%0d conflictSeen=%0d",
               got0, got1, got2, got3, got4, multi_hot_commit_seen, conflict_seen);
    end else begin
      $display("TB_RESULT FAIL got0=%0d got1=%0d got2=%0d got3=%0d got4=%0d multi=%0d conflictSeen=%0d commit=%b conflict=%b",
               got0, got1, got2, got3, got4, multi_hot_commit_seen,
               conflict_seen, probe_commit, probe_commit_conflict);
      for (dbg_i = 0; dbg_i < got0; dbg_i = dbg_i + 1)
        $display("TB_SEEN port=0 idx=%0d data=%h", dbg_i, seen0[dbg_i]);
      for (dbg_i = 0; dbg_i < got1; dbg_i = dbg_i + 1)
        $display("TB_SEEN port=1 idx=%0d data=%h", dbg_i, seen1[dbg_i]);
      for (dbg_i = 0; dbg_i < got2; dbg_i = dbg_i + 1)
        $display("TB_SEEN port=2 idx=%0d data=%h", dbg_i, seen2[dbg_i]);
      for (dbg_i = 0; dbg_i < got3; dbg_i = dbg_i + 1)
        $display("TB_SEEN port=3 idx=%0d data=%h", dbg_i, seen3[dbg_i]);
      for (dbg_i = 0; dbg_i < got4; dbg_i = dbg_i + 1)
        $display("TB_SEEN port=4 idx=%0d data=%h", dbg_i, seen4[dbg_i]);
      $finish(1);
    end
    $finish;
  end
endmodule
