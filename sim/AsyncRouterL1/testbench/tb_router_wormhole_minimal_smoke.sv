`timescale 1ns/1ps

module tb_router_wormhole_minimal_smoke;
  localparam FLIT_W = 28;

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

  wire [4:0] probe_request_4;
  wire [4:0] probe_route_4;
  wire [4:0] probe_context_mask_4;
  wire probe_commit_raw;
  wire [4:0] probe_commit_vec;
  wire [4:0] probe_winner_vec;
  wire [4:0] probe_commit_conflict;
  wire probe_commit_4;
  wire probe_winner_4;
  wire probe_commit_ready_4;
  wire probe_global_commit_event;
  wire probe_input_valid_4;
  wire probe_context_active_4;
  wire probe_output_valid_0;
  reg hold_child0_ack = 1'b0;
  integer got0, got1, got2, got3, got4;
  integer multi_hot_commit_seen;
  integer conflict_seen;
  reg [FLIT_W-1:0] seen0 [0:31];
  reg [FLIT_W-1:0] seen1 [0:31];
  reg [FLIT_W-1:0] seen2 [0:31];
  reg [FLIT_W-1:0] seen3 [0:31];
  reg [FLIT_W-1:0] seen4 [0:31];

  assign probe_commit_4 = probe_commit_vec[4];
  assign probe_winner_4 = probe_winner_vec[4];

  always #5 clock = ~clock;

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
    .io_probe_inputValid_0(),
    .io_probe_inputValid_1(),
    .io_probe_inputValid_2(),
    .io_probe_inputValid_3(),
    .io_probe_inputValid_4(probe_input_valid_4),
    .io_probe_outputValid_0(probe_output_valid_0),
    .io_probe_outputValid_1(),
    .io_probe_outputValid_2(),
    .io_probe_outputValid_3(),
    .io_probe_outputValid_4(),
    .io_probe_inputData_0_flit(),
    .io_probe_inputData_1_flit(),
    .io_probe_inputData_2_flit(),
    .io_probe_inputData_3_flit(),
    .io_probe_inputData_4_flit(),
    .io_probe_outputData_0_flit(),
    .io_probe_outputData_1_flit(),
    .io_probe_outputData_2_flit(),
    .io_probe_outputData_3_flit(),
    .io_probe_outputData_4_flit(),
    .io_probe_routeMask_0(),
    .io_probe_routeMask_1(),
    .io_probe_routeMask_2(),
    .io_probe_routeMask_3(),
    .io_probe_routeMask_4(probe_route_4),
    .io_probe_requestMask_0(),
    .io_probe_requestMask_1(),
    .io_probe_requestMask_2(),
    .io_probe_requestMask_3(),
    .io_probe_requestMask_4(probe_request_4),
    .io_probe_outputWinner_0(),
    .io_probe_outputWinner_1(),
    .io_probe_outputWinner_2(),
    .io_probe_outputWinner_3(),
    .io_probe_outputWinner_4(),
    .io_probe_grantedAll_0(),
    .io_probe_grantedAll_1(),
    .io_probe_grantedAll_2(),
    .io_probe_grantedAll_3(),
    .io_probe_grantedAll_4(),
    .io_probe_canCommit_0(),
    .io_probe_canCommit_1(),
    .io_probe_canCommit_2(),
    .io_probe_canCommit_3(),
    .io_probe_canCommit_4(),
    .io_probe_winner_0(probe_winner_vec[0]),
    .io_probe_winner_1(probe_winner_vec[1]),
    .io_probe_winner_2(probe_winner_vec[2]),
    .io_probe_winner_3(probe_winner_vec[3]),
    .io_probe_winner_4(probe_winner_vec[4]),
    .io_probe_commitConflict_0(probe_commit_conflict[0]),
    .io_probe_commitConflict_1(probe_commit_conflict[1]),
    .io_probe_commitConflict_2(probe_commit_conflict[2]),
    .io_probe_commitConflict_3(probe_commit_conflict[3]),
    .io_probe_commitConflict_4(probe_commit_conflict[4]),
    .io_probe_commitRaw(probe_commit_raw),
    .io_probe_commit_0(probe_commit_vec[0]),
    .io_probe_commit_1(probe_commit_vec[1]),
    .io_probe_commit_2(probe_commit_vec[2]),
    .io_probe_commit_3(probe_commit_vec[3]),
    .io_probe_commit_4(probe_commit_vec[4]),
    .io_probe_inputCaptureFire_0(),
    .io_probe_inputCaptureFire_1(),
    .io_probe_inputCaptureFire_2(),
    .io_probe_inputCaptureFire_3(),
    .io_probe_inputCaptureFire_4(),
    .io_probe_commitReady_0(),
    .io_probe_commitReady_1(),
    .io_probe_commitReady_2(),
    .io_probe_commitReady_3(),
    .io_probe_commitReady_4(probe_commit_ready_4),
    .io_probe_globalCommitEvent(probe_global_commit_event),
    .io_probe_outputReqPending_0(),
    .io_probe_outputReqPending_1(),
    .io_probe_outputReqPending_2(),
    .io_probe_outputReqPending_3(),
    .io_probe_outputReqPending_4(),
    .io_probe_outputReqLaunchEvent_0(),
    .io_probe_outputReqLaunchEvent_1(),
    .io_probe_outputReqLaunchEvent_2(),
    .io_probe_outputReqLaunchEvent_3(),
    .io_probe_outputReqLaunchEvent_4(),
    .io_probe_inputSlotReq_0(),
    .io_probe_inputSlotReq_1(),
    .io_probe_inputSlotReq_2(),
    .io_probe_inputSlotReq_3(),
    .io_probe_inputSlotReq_4(),
    .io_probe_inputSlotAck_0(),
    .io_probe_inputSlotAck_1(),
    .io_probe_inputSlotAck_2(),
    .io_probe_inputSlotAck_3(),
    .io_probe_inputSlotAck_4(),
    .io_probe_outputSlotReq_0(),
    .io_probe_outputSlotReq_1(),
    .io_probe_outputSlotReq_2(),
    .io_probe_outputSlotReq_3(),
    .io_probe_outputSlotReq_4(),
    .io_probe_outputSlotAck_0(),
    .io_probe_outputSlotAck_1(),
    .io_probe_outputSlotAck_2(),
    .io_probe_outputSlotAck_3(),
    .io_probe_outputSlotAck_4(),
    .io_probe_outputHolder_0(),
    .io_probe_outputHolder_1(),
    .io_probe_outputHolder_2(),
    .io_probe_outputHolder_3(),
    .io_probe_outputHolder_4(),
    .io_probe_contextActive_0(),
    .io_probe_contextActive_1(),
    .io_probe_contextActive_2(),
    .io_probe_contextActive_3(),
    .io_probe_contextActive_4(probe_context_active_4),
    .io_probe_contextMask_0(),
    .io_probe_contextMask_1(),
    .io_probe_contextMask_2(),
    .io_probe_contextMask_3(),
    .io_probe_contextMask_4(probe_context_mask_4)
  );

  function automatic [FLIT_W-1:0] flit;
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

  function automatic integer pop5;
    input [4:0] v;
    begin
      pop5 = v[0] + v[1] + v[2] + v[3] + v[4];
    end
  endfunction

  task automatic send_parent;
    input [FLIT_W-1:0] f;
    integer guard;
    begin
      io_inputs_parent_0_Data_flit = f;
      #0.1;
      io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
      guard = 0;
      while (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req && guard < 1000) begin
        #1;
        guard = guard + 1;
      end
      if (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req) begin
        $display("TB_RESULT FAIL send_parent timeout t=%0t flit=%h reqMask4=%b route4=%b ctxAct4=%b ctxMask4=%b winner4=%b ready4=%b inValid4=%b outValid0=%b got0=%0d got1=%0d got2=%0d got3=%0d got4=%0d",
                 $time, f, probe_request_4, probe_route_4, probe_context_active_4,
                 probe_context_mask_4, probe_winner_4, probe_commit_ready_4,
                 probe_input_valid_4, probe_output_valid_0, got0, got1, got2, got3, got4);
        $finish(1);
      end
      #0.1;
    end
  endtask

  task automatic start_parent;
    input [FLIT_W-1:0] f;
    begin
      io_inputs_parent_0_Data_flit = f;
      #1 io_inputs_parent_0_HS_Req = ~io_inputs_parent_0_HS_Req;
    end
  endtask

  task automatic start_child0;
    input [FLIT_W-1:0] f;
    begin
      io_inputs_child_0_0_Data_flit = f;
      #1 io_inputs_child_0_0_HS_Req = ~io_inputs_child_0_0_HS_Req;
    end
  endtask

  task automatic start_child1;
    input [FLIT_W-1:0] f;
    begin
      io_inputs_child_1_0_Data_flit = f;
      #1 io_inputs_child_1_0_HS_Req = ~io_inputs_child_1_0_HS_Req;
    end
  endtask

  task automatic wait_parent_ack;
    integer guard;
    begin
      guard = 0;
      while (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req && guard < 1000) begin
        #1 guard = guard + 1;
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
      while (io_inputs_child_0_0_HS_Ack != io_inputs_child_0_0_HS_Req && guard < 1000) begin
        #1 guard = guard + 1;
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
      while (io_inputs_child_1_0_HS_Ack != io_inputs_child_1_0_HS_Req && guard < 1000) begin
        #1 guard = guard + 1;
      end
      if (io_inputs_child_1_0_HS_Ack != io_inputs_child_1_0_HS_Req) begin
        $display("TB_RESULT FAIL wait_child1_ack timeout t=%0t", $time);
        $finish(1);
      end
    end
  endtask

  always @(io_outputs_child_0_0_HS_Req) begin
    if (!reset && io_outputs_child_0_0_HS_Req != io_outputs_child_0_0_HS_Ack) begin
      #0.1;
      seen0[got0] = io_outputs_child_0_0_Data_flit;
      got0 = got0 + 1;
      $display("TB_OUT child0 t=%0t data=%h", $time, io_outputs_child_0_0_Data_flit);
      if (!hold_child0_ack) begin
        io_outputs_child_0_0_HS_Ack = io_outputs_child_0_0_HS_Req;
      end
    end
  end

  always @(io_outputs_child_1_0_HS_Req) begin
    if (!reset && io_outputs_child_1_0_HS_Req != io_outputs_child_1_0_HS_Ack) begin
      #0.1;
      seen1[got1] = io_outputs_child_1_0_Data_flit;
      got1 = got1 + 1;
      $display("TB_OUT child1 t=%0t data=%h", $time, io_outputs_child_1_0_Data_flit);
      io_outputs_child_1_0_HS_Ack = io_outputs_child_1_0_HS_Req;
    end
  end

  always @(io_outputs_child_2_0_HS_Req) begin
    if (!reset && io_outputs_child_2_0_HS_Req != io_outputs_child_2_0_HS_Ack) begin
      #0.1;
      seen2[got2] = io_outputs_child_2_0_Data_flit;
      got2 = got2 + 1;
      $display("TB_OUT child2 t=%0t data=%h", $time, io_outputs_child_2_0_Data_flit);
      io_outputs_child_2_0_HS_Ack = io_outputs_child_2_0_HS_Req;
    end
  end

  always @(io_outputs_child_3_0_HS_Req) begin
    if (!reset && io_outputs_child_3_0_HS_Req != io_outputs_child_3_0_HS_Ack) begin
      #0.1;
      seen3[got3] = io_outputs_child_3_0_Data_flit;
      got3 = got3 + 1;
      $display("TB_OUT child3 t=%0t data=%h", $time, io_outputs_child_3_0_Data_flit);
      io_outputs_child_3_0_HS_Ack = io_outputs_child_3_0_HS_Req;
    end
  end

  always @(io_outputs_parent_0_HS_Req) begin
    if (!reset && io_outputs_parent_0_HS_Req != io_outputs_parent_0_HS_Ack) begin
      #0.1;
      got4 = got4 + 1;
      seen4[got4 - 1] = io_outputs_parent_0_Data_flit;
      $display("TB_OUT parent t=%0t data=%h", $time, io_outputs_parent_0_Data_flit);
      io_outputs_parent_0_HS_Ack = io_outputs_parent_0_HS_Req;
    end
  end

  always @(probe_commit_vec) begin
    if (!reset && pop5(probe_commit_vec) > 1) begin
      multi_hot_commit_seen = 1;
      $display("TB_PROBE multi_commit t=%0t commit=%b conflict=%b", $time, probe_commit_vec, probe_commit_conflict);
    end
  end

  always @(posedge probe_global_commit_event) begin
    if (!reset && pop5(probe_commit_vec) > 1) begin
      multi_hot_commit_seen = 1;
      $display("TB_PROBE multi_global_commit t=%0t commit=%b conflict=%b", $time, probe_commit_vec, probe_commit_conflict);
    end
  end

  always @(probe_commit_conflict) begin
    if (!reset && probe_commit_conflict != 5'b00000) begin
      conflict_seen = 1;
      $display("TB_RESULT FAIL commit_conflict t=%0t commit=%b conflict=%b", $time, probe_commit_vec, probe_commit_conflict);
      $finish(1);
    end
  end

  always @(posedge probe_commit_4) begin
    $display("TB_PROBE commit4 t=%0t reqMask4=%b route4=%b ctxAct4=%b ctxMask4=%b winner4=%b ready4=%b raw=%b global=%b data=%h",
             $time, probe_request_4, probe_route_4, probe_context_active_4,
             probe_context_mask_4, probe_winner_4, probe_commit_ready_4,
             probe_commit_raw, probe_global_commit_event,
             io_inputs_parent_0_Data_flit);
  end

  initial begin
    got0 = 0;
    got1 = 0;
    got2 = 0;
    got3 = 0;
    got4 = 0;
    multi_hot_commit_seen = 0;
    conflict_seen = 0;
    #20 reset = 1'b0;
    #5;

    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b0, 1'b1));
    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b0, 1'b0));
    send_parent(flit(2'd0, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b0));

    send_parent(28'h8104000);
    send_parent(28'h0104000);
    send_parent(28'h4104000);

    hold_child0_ack = 1'b1;
    send_parent(flit(2'd1, 6'd1, 6'd1, 6'd1, 6'd1, 1'b1, 1'b1));
    #10;
    if (io_inputs_parent_0_HS_Ack != io_inputs_parent_0_HS_Req ||
        io_outputs_child_0_0_HS_Req == io_outputs_child_0_0_HS_Ack) begin
      $display("TB_RESULT FAIL downstream_busy_commit t=%0t inAck=%b inReq=%b outReq=%b outAck=%b got0=%0d globalCommit=%b",
               $time, io_inputs_parent_0_HS_Ack, io_inputs_parent_0_HS_Req,
               io_outputs_child_0_0_HS_Req, io_outputs_child_0_0_HS_Ack,
               got0, probe_global_commit_event);
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

    #200;
    if (got0 == 11 && got1 == 5 && got2 == 5 && got3 == 5 && got4 == 4 &&
        multi_hot_commit_seen && !conflict_seen &&
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
      $display("TB_RESULT PASS got0=%0d got1=%0d got2=%0d got3=%0d got4=%0d multi=%0d reqMask4=%b commit=%b conflict=%b inValid4=%b outValid0=%b",
               got0, got1, got2, got3, got4, multi_hot_commit_seen, probe_request_4, probe_commit_vec,
               probe_commit_conflict, probe_input_valid_4, probe_output_valid_0);
    end else begin
      $display("TB_RESULT FAIL got0=%0d got1=%0d got2=%0d got3=%0d got4=%0d multi=%0d conflictSeen=%0d reqMask4=%b commit=%b conflict=%b inValid4=%b outValid0=%b",
               got0, got1, got2, got3, got4, multi_hot_commit_seen, conflict_seen, probe_request_4,
               probe_commit_vec, probe_commit_conflict, probe_input_valid_4, probe_output_valid_0);
      $finish(1);
    end
    $finish;
  end
endmodule
