`timescale 1ns/1ps

// Strict-SDF smoke for the L2 2-child-lane -> 4-parent-lane Router.
// Phase A fills all four parent lanes (Flat8 OPMs).  Phase B makes all four
// parent inputs contend for the two child0 lanes (Flat10 OPMs), and checks
// that each packet remains on one lane through Head/Body/Tail.
module tb_cmr_router_l2_multilane_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [11:0] Reqin = 12'b0;
  reg [27:0] Datain [0:11];
  wire [11:0] Ackout;
  wire [11:0] Reqout;
  reg [11:0] Ackin = 12'b0;
  wire [27:0] Dataout [0:11];
  integer failures = 0;
  integer index;
  integer lane_for_id [0:3];
  integer down_count [0:3];
  integer total_down = 0;
  reg auto_child_ack = 1'b0;

  CMRRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(Reqin[0]), .io_inputs_child_0_0_HS_Ack(Ackout[0]), .io_inputs_child_0_0_Data_flit(Datain[0]),
    .io_inputs_child_0_1_HS_Req(Reqin[1]), .io_inputs_child_0_1_HS_Ack(Ackout[1]), .io_inputs_child_0_1_Data_flit(Datain[1]),
    .io_inputs_child_1_0_HS_Req(Reqin[2]), .io_inputs_child_1_0_HS_Ack(Ackout[2]), .io_inputs_child_1_0_Data_flit(Datain[2]),
    .io_inputs_child_1_1_HS_Req(Reqin[3]), .io_inputs_child_1_1_HS_Ack(Ackout[3]), .io_inputs_child_1_1_Data_flit(Datain[3]),
    .io_inputs_child_2_0_HS_Req(Reqin[4]), .io_inputs_child_2_0_HS_Ack(Ackout[4]), .io_inputs_child_2_0_Data_flit(Datain[4]),
    .io_inputs_child_2_1_HS_Req(Reqin[5]), .io_inputs_child_2_1_HS_Ack(Ackout[5]), .io_inputs_child_2_1_Data_flit(Datain[5]),
    .io_inputs_child_3_0_HS_Req(Reqin[6]), .io_inputs_child_3_0_HS_Ack(Ackout[6]), .io_inputs_child_3_0_Data_flit(Datain[6]),
    .io_inputs_child_3_1_HS_Req(Reqin[7]), .io_inputs_child_3_1_HS_Ack(Ackout[7]), .io_inputs_child_3_1_Data_flit(Datain[7]),
    .io_inputs_parent_0_HS_Req(Reqin[8]), .io_inputs_parent_0_HS_Ack(Ackout[8]), .io_inputs_parent_0_Data_flit(Datain[8]),
    .io_inputs_parent_1_HS_Req(Reqin[9]), .io_inputs_parent_1_HS_Ack(Ackout[9]), .io_inputs_parent_1_Data_flit(Datain[9]),
    .io_inputs_parent_2_HS_Req(Reqin[10]), .io_inputs_parent_2_HS_Ack(Ackout[10]), .io_inputs_parent_2_Data_flit(Datain[10]),
    .io_inputs_parent_3_HS_Req(Reqin[11]), .io_inputs_parent_3_HS_Ack(Ackout[11]), .io_inputs_parent_3_Data_flit(Datain[11]),
    .io_outputs_child_0_0_HS_Req(Reqout[0]), .io_outputs_child_0_0_HS_Ack(Ackin[0]), .io_outputs_child_0_0_Data_flit(Dataout[0]),
    .io_outputs_child_0_1_HS_Req(Reqout[1]), .io_outputs_child_0_1_HS_Ack(Ackin[1]), .io_outputs_child_0_1_Data_flit(Dataout[1]),
    .io_outputs_child_1_0_HS_Req(Reqout[2]), .io_outputs_child_1_0_HS_Ack(Ackin[2]), .io_outputs_child_1_0_Data_flit(Dataout[2]),
    .io_outputs_child_1_1_HS_Req(Reqout[3]), .io_outputs_child_1_1_HS_Ack(Ackin[3]), .io_outputs_child_1_1_Data_flit(Dataout[3]),
    .io_outputs_child_2_0_HS_Req(Reqout[4]), .io_outputs_child_2_0_HS_Ack(Ackin[4]), .io_outputs_child_2_0_Data_flit(Dataout[4]),
    .io_outputs_child_2_1_HS_Req(Reqout[5]), .io_outputs_child_2_1_HS_Ack(Ackin[5]), .io_outputs_child_2_1_Data_flit(Dataout[5]),
    .io_outputs_child_3_0_HS_Req(Reqout[6]), .io_outputs_child_3_0_HS_Ack(Ackin[6]), .io_outputs_child_3_0_Data_flit(Dataout[6]),
    .io_outputs_child_3_1_HS_Req(Reqout[7]), .io_outputs_child_3_1_HS_Ack(Ackin[7]), .io_outputs_child_3_1_Data_flit(Dataout[7]),
    .io_outputs_parent_0_HS_Req(Reqout[8]), .io_outputs_parent_0_HS_Ack(Ackin[8]), .io_outputs_parent_0_Data_flit(Dataout[8]),
    .io_outputs_parent_1_HS_Req(Reqout[9]), .io_outputs_parent_1_HS_Ack(Ackin[9]), .io_outputs_parent_1_Data_flit(Dataout[9]),
    .io_outputs_parent_2_HS_Req(Reqout[10]), .io_outputs_parent_2_HS_Ack(Ackin[10]), .io_outputs_parent_2_Data_flit(Dataout[10]),
    .io_outputs_parent_3_HS_Req(Reqout[11]), .io_outputs_parent_3_HS_Ack(Ackin[11]), .io_outputs_parent_3_Data_flit(Dataout[11])
  );

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head, input bit Tail, input [1:0] id, input bit upward
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head;
      make_flit[26] = Tail;
      if (upward) begin
        make_flit[7:2] = 6'd16; make_flit[13:8] = 6'd16;
        make_flit[19:14] = 6'd16; make_flit[25:20] = 6'd16;
      end else begin
        // L2 child0 subtree.
        make_flit[7:2] = 6'd2; make_flit[13:8] = 6'd2;
        make_flit[19:14] = 6'd3; make_flit[25:20] = 6'd3;
      end
      make_flit[1:0] = id;
    end
  endfunction

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b out=%b/%b",
               message, $time, Reqin, Ackout, Reqout, Ackin);
    end
  endtask

  task automatic wait_input_ack(input integer port);
    integer timeout;
    begin
      timeout = 0;
      while ((Ackout[port] !== Reqin[port]) && timeout < 20000) begin
        #1; timeout = timeout + 1;
      end
      check(Ackout[port] === Reqin[port], "input acknowledgement timed out");
    end
  endtask

  task automatic wait_four_parent_requests;
    integer timeout;
    begin
      timeout = 0;
      while ((((Reqout[8] === Ackin[8]) + (Reqout[9] === Ackin[9]) +
               (Reqout[10] === Ackin[10]) + (Reqout[11] === Ackin[11])) != 0) &&
             timeout < 20000) begin
        #1; timeout = timeout + 1;
      end
      check(Reqout[11:8] !== Ackin[11:8],
            "four packets did not occupy all parent lanes");
    end
  endtask

  task automatic send_up_phase(input bit Head, input bit Tail);
    begin
      Datain[0] = make_flit(Head, Tail, 2'd0, 1'b1);
      Datain[2] = make_flit(Head, Tail, 2'd1, 1'b1);
      Datain[4] = make_flit(Head, Tail, 2'd2, 1'b1);
      Datain[6] = make_flit(Head, Tail, 2'd3, 1'b1);
      #1; Reqin[0] = ~Reqin[0]; Reqin[2] = ~Reqin[2];
      Reqin[4] = ~Reqin[4]; Reqin[6] = ~Reqin[6];
    end
  endtask

  task automatic send_down_phase(input bit Head, input bit Tail);
    begin
      for (index = 0; index < 4; index = index + 1)
        Datain[8 + index] = make_flit(Head, Tail, index[1:0], 1'b0);
      #1; Reqin[11:8] = ~Reqin[11:8];
      for (index = 8; index < 12; index = index + 1)
        wait_input_ack(index);
    end
  endtask

  task automatic capture_down(input integer lane);
    integer id;
    begin
      id = Dataout[lane][1:0];
      check(!$isunknown({Reqout[lane], Dataout[lane]}),
            "downstream Flat10 transfer contains X/Z");
      if (down_count[id] == 0)
        lane_for_id[id] = lane;
      else
        check(lane_for_id[id] == lane, "packet changed child lane");
      down_count[id] = down_count[id] + 1;
      total_down = total_down + 1;
    end
  endtask

  always @(Reqout[0]) begin
    if (!reset && auto_child_ack && Reqout[0] !== Ackin[0]) begin
      #2; capture_down(0); #3; Ackin[0] = Reqout[0];
    end
  end
  always @(Reqout[1]) begin
    if (!reset && auto_child_ack && Reqout[1] !== Ackin[1]) begin
      #2; capture_down(1); #3; Ackin[1] = Reqout[1];
    end
  end

  initial begin
    for (index = 0; index < 12; index = index + 1) begin
      Datain[index] = 28'b0;
      lane_for_id[index & 3] = -1;
      down_count[index & 3] = 0;
    end
    #5; reset = 1'b0; #8;
    check(Ackout === 12'b0 && Reqout === 12'b0,
          "L2 Router reset phase mismatch");

    // Flat8: four different child directions fill the four parent lanes.
    send_up_phase(1'b1, 1'b0);
    wait_input_ack(0); wait_input_ack(2); wait_input_ack(4); wait_input_ack(6);
    wait_four_parent_requests();
    check(!$isunknown({Reqout, Ackout, Dataout[8], Dataout[9], Dataout[10], Dataout[11]}),
          "Flat8 Head contains X/Z");
    check(((4'b0001 << Dataout[8][1:0]) |
          (4'b0001 << Dataout[9][1:0]) |
          (4'b0001 << Dataout[10][1:0]) |
          (4'b0001 << Dataout[11][1:0])) == 4'b1111,
          "parent lanes did not carry four distinct requesters");
    Ackin[11:8] = Reqout[11:8]; #5;

    send_up_phase(1'b0, 1'b0);
    wait_input_ack(0); wait_input_ack(2); wait_input_ack(4); wait_input_ack(6);
    wait_four_parent_requests(); Ackin[11:8] = Reqout[11:8]; #5;
    send_up_phase(1'b0, 1'b1);
    wait_four_parent_requests();
    wait_input_ack(0); wait_input_ack(2); wait_input_ack(4); wait_input_ack(6);
    Ackin[11:8] = Reqout[11:8]; #12;
    check(Reqout === Ackin, "Flat8 packets did not return idle after Tail");

    // Flat10: four parent inputs contend for only two child0 output lanes.
    auto_child_ack = 1'b1;
    send_down_phase(1'b1, 1'b0);
    send_down_phase(1'b0, 1'b0);
    send_down_phase(1'b0, 1'b1);
    index = 0;
    while (total_down < 12 && index < 20000) begin #1; index = index + 1; end
    check(total_down == 12, "Flat10 contention did not drain all packets");
    for (index = 0; index < 4; index = index + 1)
      check(down_count[index] == 3, "Flat10 packet flit count mismatch");
    check(Reqout[7:2] === Ackin[7:2], "child0-bound packets escaped direction");
    #15;
    check(Reqout === Ackin, "L2 Router did not return idle");
    check(!$isunknown({Reqout, Ackout}), "stable L2 control contains X/Z");

    if (failures == 0)
      $display("TB_RESULT PASS CMR L2 Flat8/Flat10 continuous lane Router smoke");
    else
      $display("TB_RESULT FAIL CMR L2 multi-lane failures=%0d", failures);
    $finish;
  end

  initial begin
    #200000;
    $display("TB_RESULT FAIL global_timeout t=%0t in=%b/%b out=%b/%b down=%0d",
             $time, Reqin, Ackout, Reqout, Ackin, total_down);
    $finish;
  end
endmodule
