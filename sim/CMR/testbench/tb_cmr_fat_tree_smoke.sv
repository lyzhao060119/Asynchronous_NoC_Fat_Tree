`timescale 1ns/1ps

module tb_cmr_fat_tree_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg [1:0] Reqin = 2'b0;
  reg [27:0] Datain [0:1];
  wire [1:0] Ackout;
  wire [7:0] TopReqout;
  wire [27:0] TopDataout [0:7];
  reg [7:0] TopAckin = 8'b0;
  integer failures = 0;
  integer lane0;
  integer lane1;
  integer lane;
  integer count;
  integer timeout;

  CMRFatTreeSmokeHarness dut (
    .clock(clock), .reset(reset),
    .io_Reqin_0(Reqin[0]), .io_Reqin_1(Reqin[1]),
    .io_Datain_0_flit(Datain[0]), .io_Datain_1_flit(Datain[1]),
    .io_Ackout_0(Ackout[0]), .io_Ackout_1(Ackout[1]),
    .io_TopReqout_0(TopReqout[0]), .io_TopReqout_1(TopReqout[1]),
    .io_TopReqout_2(TopReqout[2]), .io_TopReqout_3(TopReqout[3]),
    .io_TopReqout_4(TopReqout[4]), .io_TopReqout_5(TopReqout[5]),
    .io_TopReqout_6(TopReqout[6]), .io_TopReqout_7(TopReqout[7]),
    .io_TopDataout_0_flit(TopDataout[0]),
    .io_TopDataout_1_flit(TopDataout[1]),
    .io_TopDataout_2_flit(TopDataout[2]),
    .io_TopDataout_3_flit(TopDataout[3]),
    .io_TopDataout_4_flit(TopDataout[4]),
    .io_TopDataout_5_flit(TopDataout[5]),
    .io_TopDataout_6_flit(TopDataout[6]),
    .io_TopDataout_7_flit(TopDataout[7]),
    .io_TopAckin_0(TopAckin[0]), .io_TopAckin_1(TopAckin[1]),
    .io_TopAckin_2(TopAckin[2]), .io_TopAckin_3(TopAckin[3]),
    .io_TopAckin_4(TopAckin[4]), .io_TopAckin_5(TopAckin[5]),
    .io_TopAckin_6(TopAckin[6]), .io_TopAckin_7(TopAckin[7])
  );

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head, input bit Tail, input [1:0] id
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head; make_flit[26] = Tail;
      // Outside the local 8x8 tree, forcing L1 -> L2 -> L3 -> top.
      make_flit[7:2] = 6'd32; make_flit[13:8] = 6'd32;
      make_flit[19:14] = 6'd32; make_flit[25:20] = 6'd32;
      make_flit[1:0] = id;
    end
  endfunction

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b top=%b/%b",
               message, $time, Reqin, Ackout, TopReqout, TopAckin);
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
      while (Ackout !== Reqin && timeout < 1000) begin
        #1; timeout = timeout + 1;
      end
      check(Ackout === Reqin, "source acknowledgements timed out");
    end
  endtask

  task automatic wait_two_top_requests;
    begin
      timeout = 0; count = 0;
      while (count != 2 && timeout < 1000) begin
        #1; timeout = timeout + 1; count = 0;
        for (lane = 0; lane < 8; lane = lane + 1)
          if (TopReqout[lane] !== TopAckin[lane]) count = count + 1;
      end
      check(count == 2, "two packets did not reach distinct top lanes");
    end
  endtask

  task automatic acknowledge_top;
    begin
      for (lane = 0; lane < 8; lane = lane + 1)
        if (TopReqout[lane] !== TopAckin[lane]) TopAckin[lane] = TopReqout[lane];
      #5;
    end
  endtask

  initial begin
    Datain[0] = 0; Datain[1] = 0;
    #8; reset = 1'b0; #8;
    check(Ackout === 2'b0 && TopReqout === 8'b0, "Fat Tree reset mismatch");

    send_pair(1'b1, 1'b0); wait_input_acks(); wait_two_top_requests();
    lane0 = -1; lane1 = -1;
    for (lane = 0; lane < 8; lane = lane + 1) begin
      if (TopReqout[lane] !== TopAckin[lane] && TopDataout[lane][1:0] == 2'b01)
        lane0 = lane;
      if (TopReqout[lane] !== TopAckin[lane] && TopDataout[lane][1:0] == 2'b10)
        lane1 = lane;
    end
    check(lane0 >= 0 && lane1 >= 0 && lane0 != lane1,
          "top Head identity/ownership mismatch");
    acknowledge_top();

    send_pair(1'b0, 1'b0); wait_input_acks(); wait_two_top_requests();
    check(TopDataout[lane0][1:0] == 2'b01 &&
          TopDataout[lane1][1:0] == 2'b10,
          "Body changed its top lane");
    acknowledge_top();

    send_pair(1'b0, 1'b1); wait_input_acks(); wait_two_top_requests();
    check(TopDataout[lane0][1:0] == 2'b01 &&
          TopDataout[lane1][1:0] == 2'b10 &&
          TopDataout[lane0][26] && TopDataout[lane1][26],
          "Tail changed top lane or identity");
    acknowledge_top(); #12;
    check(TopReqout === TopAckin, "top requests did not retire after Tail");
    check(!$isunknown({TopReqout, TopAckin, Ackout}), "Fat Tree stable X/Z");

    if (failures == 0)
      $display("TB_RESULT PASS CMR 1-to-2-to-4-to-8 Fat Tree smoke");
    else
      $display("TB_RESULT FAIL CMR Fat Tree failures=%0d", failures);
    $finish;
  end
endmodule
