`timescale 1ns/1ps

module cmr_router_lane_harness_case #(parameter integer ACTIVE_PARENTS = 2);
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [1:0] Reqin = 2'b0;
  reg [27:0] Datain [0:1];
  wire [1:0] Ackout;
  wire [7:0] ParentReqout;
  wire [27:0] ParentDataout [0:7];
  reg [7:0] ParentAckin = 8'b0;
  integer failures = 0;
  integer lane0;
  integer lane1;
  integer lane;
  integer count;
  integer timeout;

  CMRRouterLaneSmokeHarness dut (
    .clock(clock), .reset(reset),
    .io_Reqin_0(Reqin[0]), .io_Reqin_1(Reqin[1]),
    .io_Datain_0_flit(Datain[0]), .io_Datain_1_flit(Datain[1]),
    .io_Ackout_0(Ackout[0]), .io_Ackout_1(Ackout[1]),
    .io_ParentReqout_0(ParentReqout[0]),
    .io_ParentReqout_1(ParentReqout[1]),
    .io_ParentReqout_2(ParentReqout[2]),
    .io_ParentReqout_3(ParentReqout[3]),
    .io_ParentReqout_4(ParentReqout[4]),
    .io_ParentReqout_5(ParentReqout[5]),
    .io_ParentReqout_6(ParentReqout[6]),
    .io_ParentReqout_7(ParentReqout[7]),
    .io_ParentDataout_0_flit(ParentDataout[0]),
    .io_ParentDataout_1_flit(ParentDataout[1]),
    .io_ParentDataout_2_flit(ParentDataout[2]),
    .io_ParentDataout_3_flit(ParentDataout[3]),
    .io_ParentDataout_4_flit(ParentDataout[4]),
    .io_ParentDataout_5_flit(ParentDataout[5]),
    .io_ParentDataout_6_flit(ParentDataout[6]),
    .io_ParentDataout_7_flit(ParentDataout[7]),
    .io_ParentAckin_0(ParentAckin[0]),
    .io_ParentAckin_1(ParentAckin[1]),
    .io_ParentAckin_2(ParentAckin[2]),
    .io_ParentAckin_3(ParentAckin[3]),
    .io_ParentAckin_4(ParentAckin[4]),
    .io_ParentAckin_5(ParentAckin[5]),
    .io_ParentAckin_6(ParentAckin[6]),
    .io_ParentAckin_7(ParentAckin[7])
  );

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head, input bit Tail, input [1:0] id
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head;
      make_flit[26] = Tail;
      make_flit[7:2] = 6'd32; make_flit[13:8] = 6'd32;
      make_flit[19:14] = 6'd32; make_flit[25:20] = 6'd32;
      make_flit[1:0] = id;
    end
  endfunction

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL P=%0d %s t=%0t req=%b ack=%b",
               ACTIVE_PARENTS, message, $time, ParentReqout, ParentAckin);
    end
  endtask

  task automatic send_pair(input bit Head, input bit Tail);
    begin
      Datain[0] = make_flit(Head, Tail, 2'b01);
      Datain[1] = make_flit(Head, Tail, 2'b10);
      #1; Reqin = ~Reqin;
    end
  endtask

  task automatic wait_input_acks;
    begin
      timeout = 0;
      while ((Ackout !== Reqin) && timeout < 200) begin
        #1; timeout = timeout + 1;
      end
      check(Ackout === Reqin, "input acknowledgements timed out");
    end
  endtask

  task automatic wait_two_parent_requests;
    begin
      timeout = 0; count = 0;
      while (count != 2 && timeout < 200) begin
        #1; timeout = timeout + 1; count = 0;
        for (lane = 0; lane < ACTIVE_PARENTS; lane = lane + 1)
          if (ParentReqout[lane] !== ParentAckin[lane]) count = count + 1;
      end
      check(count == 2, "two requests did not converge onto distinct lanes");
      for (lane = ACTIVE_PARENTS; lane < 8; lane = lane + 1)
        check(ParentReqout[lane] === ParentAckin[lane],
              "inactive padded test observation lane changed");
    end
  endtask

  task automatic acknowledge_active;
    begin
      for (lane = 0; lane < ACTIVE_PARENTS; lane = lane + 1)
        if (ParentReqout[lane] !== ParentAckin[lane])
          ParentAckin[lane] = ParentReqout[lane];
      #3;
    end
  endtask

  initial begin
    Datain[0] = 0; Datain[1] = 0;
    #5; reset = 1'b0; #5;
    check(ParentReqout === 8'b0 && Ackout === 2'b0, "reset mismatch");

    send_pair(1'b1, 1'b0); wait_input_acks(); wait_two_parent_requests();
    lane0 = -1; lane1 = -1;
    for (lane = 0; lane < ACTIVE_PARENTS; lane = lane + 1) begin
      if (ParentReqout[lane] !== ParentAckin[lane] &&
          ParentDataout[lane][1:0] == 2'b01) lane0 = lane;
      if (ParentReqout[lane] !== ParentAckin[lane] &&
          ParentDataout[lane][1:0] == 2'b10) lane1 = lane;
    end
    check(lane0 >= 0 && lane1 >= 0 && lane0 != lane1,
          "Head ownership was not one-to-one");
    acknowledge_active();

    send_pair(1'b0, 1'b0); wait_input_acks(); wait_two_parent_requests();
    check(ParentDataout[lane0][1:0] == 2'b01 &&
          ParentDataout[lane1][1:0] == 2'b10,
          "Body migrated away from its Head lane");
    acknowledge_active();

    send_pair(1'b0, 1'b1); wait_two_parent_requests();
    check(ParentDataout[lane0][1:0] == 2'b01 &&
          ParentDataout[lane1][1:0] == 2'b10 &&
          ParentDataout[lane0][26] && ParentDataout[lane1][26],
          "Tail migrated or lost identity");
    wait_input_acks(); acknowledge_active(); #6;
    check(ParentReqout === ParentAckin, "requests did not retire after Tail");
    check(!$isunknown({ParentReqout, ParentAckin, Ackout}),
          "stable controls contain X/Z");

    if (failures == 0)
      $display("TB_RESULT PASS CMR exact P=%0d Router lane harness", ACTIVE_PARENTS);
    else
      $display("TB_RESULT FAIL CMR exact P=%0d failures=%0d",
               ACTIVE_PARENTS, failures);
    $finish;
  end
endmodule

module tb_cmr_router_lane_l1_smoke;
  cmr_router_lane_harness_case #(.ACTIVE_PARENTS(2)) test();
endmodule
module tb_cmr_router_lane_l2_smoke;
  cmr_router_lane_harness_case #(.ACTIVE_PARENTS(4)) test();
endmodule
module tb_cmr_router_lane_l3_smoke;
  cmr_router_lane_harness_case #(.ACTIVE_PARENTS(8)) test();
endmodule
