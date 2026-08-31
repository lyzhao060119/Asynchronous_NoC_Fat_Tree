`timescale 1ns/1ps

// Dynamic 1-child-lane -> 2-parent-lane Router smoke.  Two independent child
// packets initially request the same direction; ContinuousLaneSelector must
// converge onto distinct parent lanes and each packet must retain its lane
// through Head/Body/Tail.
module tb_cmr_router_l1_multilane_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [5:0] Reqin = 6'b0;
  reg [27:0] Datain [0:5];
  wire [5:0] Ackout;
  wire [5:0] Reqout;
  reg [5:0] Ackin = 6'b0;
  wire [27:0] Dataout [0:5];
  integer failures = 0;
  integer index;
  integer lane_for_child0;
  integer lane_for_child1;

  CMRRouter dut (
    .clock(clock), .reset(reset),
    .io_inputs_child_0_0_HS_Req(Reqin[0]),
    .io_inputs_child_0_0_HS_Ack(Ackout[0]),
    .io_inputs_child_0_0_Data_flit(Datain[0]),
    .io_inputs_child_1_0_HS_Req(Reqin[1]),
    .io_inputs_child_1_0_HS_Ack(Ackout[1]),
    .io_inputs_child_1_0_Data_flit(Datain[1]),
    .io_inputs_child_2_0_HS_Req(Reqin[2]),
    .io_inputs_child_2_0_HS_Ack(Ackout[2]),
    .io_inputs_child_2_0_Data_flit(Datain[2]),
    .io_inputs_child_3_0_HS_Req(Reqin[3]),
    .io_inputs_child_3_0_HS_Ack(Ackout[3]),
    .io_inputs_child_3_0_Data_flit(Datain[3]),
    .io_inputs_parent_0_HS_Req(Reqin[4]),
    .io_inputs_parent_0_HS_Ack(Ackout[4]),
    .io_inputs_parent_0_Data_flit(Datain[4]),
    .io_inputs_parent_1_HS_Req(Reqin[5]),
    .io_inputs_parent_1_HS_Ack(Ackout[5]),
    .io_inputs_parent_1_Data_flit(Datain[5]),
    .io_outputs_child_0_0_HS_Req(Reqout[0]),
    .io_outputs_child_0_0_HS_Ack(Ackin[0]),
    .io_outputs_child_0_0_Data_flit(Dataout[0]),
    .io_outputs_child_1_0_HS_Req(Reqout[1]),
    .io_outputs_child_1_0_HS_Ack(Ackin[1]),
    .io_outputs_child_1_0_Data_flit(Dataout[1]),
    .io_outputs_child_2_0_HS_Req(Reqout[2]),
    .io_outputs_child_2_0_HS_Ack(Ackin[2]),
    .io_outputs_child_2_0_Data_flit(Dataout[2]),
    .io_outputs_child_3_0_HS_Req(Reqout[3]),
    .io_outputs_child_3_0_HS_Ack(Ackin[3]),
    .io_outputs_child_3_0_Data_flit(Dataout[3]),
    .io_outputs_parent_0_HS_Req(Reqout[4]),
    .io_outputs_parent_0_HS_Ack(Ackin[4]),
    .io_outputs_parent_0_Data_flit(Dataout[4]),
    .io_outputs_parent_1_HS_Req(Reqout[5]),
    .io_outputs_parent_1_HS_Ack(Ackin[5]),
    .io_outputs_parent_1_Data_flit(Dataout[5])
  );

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head, input bit Tail, input [1:0] id
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head;
      make_flit[26] = Tail;
      // Outside this L1 subtree, hence both packets request parent direction.
      make_flit[7:2] = 6'd8;  make_flit[13:8] = 6'd8;
      make_flit[19:14] = 6'd8; make_flit[25:20] = 6'd8;
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

  task automatic wait_parent_requests;
    integer timeout;
    begin
      timeout = 0;
      while (((Reqout[4] === Ackin[4]) || (Reqout[5] === Ackin[5])) &&
             timeout < 20000) begin
        #1; timeout = timeout + 1;
      end
      check(Reqout[4] !== Ackin[4] && Reqout[5] !== Ackin[5],
            "two packets did not occupy both parent lanes");
    end
  endtask

  task automatic send_pair(input bit Head, input bit Tail);
    begin
      Datain[0] = make_flit(Head, Tail, 2'b01);
      Datain[1] = make_flit(Head, Tail, 2'b10);
      #1;
      Reqin[1:0] = ~Reqin[1:0];
    end
  endtask

  task automatic acknowledge_parents;
    begin
      Ackin[4] = Reqout[4];
      Ackin[5] = Reqout[5];
      #3;
    end
  endtask

  initial begin
    for (index = 0; index < 6; index = index + 1)
      Datain[index] = 28'b0;
    #5; reset = 1'b0; #5;
    check(Ackout === 6'b0 && Reqout === 6'b0,
          "L1 Router reset phase mismatch");

    send_pair(1'b1, 1'b0);
    wait_input_ack(0); wait_input_ack(1);
    wait_parent_requests();
    check(!$isunknown({Reqout, Ackout, Dataout[4], Dataout[5]}),
          "Head contains X/Z");
    check(Dataout[4][1:0] != Dataout[5][1:0],
          "both parent lanes carried the same requester");
    lane_for_child0 = Dataout[4][1:0] == 2'b01 ? 4 : 5;
    lane_for_child1 = Dataout[4][1:0] == 2'b10 ? 4 : 5;
    check(lane_for_child0 != lane_for_child1,
          "lane ownership did not resolve one-to-one");
    check(Reqout[0] === Ackin[0] && Reqout[1] === Ackin[1],
          "child ingress made a direction-level U-turn");
    acknowledge_parents();

    send_pair(1'b0, 1'b0);
    wait_input_ack(0); wait_input_ack(1);
    wait_parent_requests();
    check(Dataout[lane_for_child0][1:0] === 2'b01 &&
          Dataout[lane_for_child1][1:0] === 2'b10,
          "Body changed the selected parent lane");
    acknowledge_parents();

    send_pair(1'b0, 1'b1);
    wait_parent_requests();
    check(Dataout[lane_for_child0][1:0] === 2'b01 &&
          Dataout[lane_for_child1][1:0] === 2'b10 &&
          Dataout[4][26] && Dataout[5][26],
          "Tail changed lane or packet identity");
    wait_input_ack(0); wait_input_ack(1);
    acknowledge_parents();
    #6;
    check(Reqout === Ackin, "parent lanes did not return idle after Tail");
    check(!$isunknown({Reqout, Ackout}), "stable Router control contains X/Z");

    if (failures == 0)
      $display("TB_RESULT PASS CMR L1 1-to-2 continuous lane Router smoke");
    else
      $display("TB_RESULT FAIL CMR L1 multi-lane failures=%0d", failures);
    $finish;
  end

  initial begin
    #100000;
    $display("TB_RESULT FAIL global_timeout t=%0t in=%b/%b out=%b/%b",
             $time, Reqin, Ackout, Reqout, Ackin);
    $finish;
  end
endmodule
