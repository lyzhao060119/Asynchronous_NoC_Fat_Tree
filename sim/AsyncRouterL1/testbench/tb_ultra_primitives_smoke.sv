`timescale 1ns/1ps

module tb_ultra_primitives_smoke;
  reg c2_reset, c2_a, c2_b;
  wire c2_z;
  reg c3_grant, c3_done, c3_mg;
  wire c3_ppe;

  reg latch_reset, latch_en;
  reg [7:0] latch_d;
  wire [7:0] latch_q;

  reg [3:0] mutex_req;
  wire mutex_gnt0, mutex_gnt1, mutex_gnt2, mutex_gnt3;
  wire [3:0] mutex_gnt = {mutex_gnt3, mutex_gnt2, mutex_gnt1, mutex_gnt0};

  reg mt_reset;
  reg mt_in_req;
  reg [7:0] mt_in_data;
  wire mt_out_req;
  reg mt_out_ack;
  wire [7:0] mt_out_data;
  reg mt_prs_ready;

  MullerC2 u_c2(.reset(c2_reset), .A(c2_a), .B(c2_b), .Z(c2_z));
  MullerC3 u_c3(
    .reset(c2_reset),
    .Grant(c3_grant),
    .Done(c3_done),
    .MG(c3_mg),
    .PPE(c3_ppe)
  );
  DLatchBank #(.WIDTH(8)) u_latch(
    .reset(latch_reset), .en(latch_en), .d(latch_d), .q(latch_q)
  );
  Mutex4 u_mutex(
    .req0(mutex_req[0]), .req1(mutex_req[1]),
    .req2(mutex_req[2]), .req3(mutex_req[3]),
    .gnt0(mutex_gnt0), .gnt1(mutex_gnt1),
    .gnt2(mutex_gnt2), .gnt3(mutex_gnt3)
  );
  MousetrapStage #(.WIDTH(8)) u_mt(
    .reset(mt_reset),
    .ReqIn(mt_in_req),
    .DataIn(mt_in_data),
    .ReqX(mt_out_req),
    .AckX(mt_out_ack),
    .DataOut(mt_out_data),
    .PRSReady(mt_prs_ready)
  );

  function automatic integer pop4;
    input [3:0] v;
    begin
      pop4 = v[0] + v[1] + v[2] + v[3];
    end
  endfunction

  task automatic check_ok;
    input cond;
    input [256*8-1:0] msg;
    begin
      if (!cond) begin
        $display("TB_RESULT FAIL %0s t=%0t", msg, $time);
        $finish(1);
      end
    end
  endtask

  initial begin
    c2_reset = 1; c2_a = 1'bx; c2_b = 1'bx;
    c3_grant = 1; c3_done = 0; c3_mg = 0;
    latch_reset = 1; latch_en = 0; latch_d = 8'ha5;
    mutex_req = 4'b0000;
    mt_reset = 1'b1;
    mt_in_req = 1'b0;
    mt_in_data = 8'h00;
    mt_out_ack = 1'b0;
    mt_prs_ready = 1'b0;

    #2;
    check_ok(c2_z == 1'b0, "c2 reset clear");
    c2_reset = 0; c2_a = 0; c2_b = 0; #1;
    check_ok(c2_z == 1'b0, "c2 clear at zero inputs");
    c2_a = 1; c2_b = 1; #1;
    check_ok(c2_z == 1'b1, "c2 set");
    c2_a = 1; c2_b = 0; #1;
    check_ok(c2_z == 1'b1, "c2 hold");
    c2_a = 0; c2_b = 0; #1;
    check_ok(c2_z == 1'b0, "c2 clear");

    check_ok(c3_ppe == 1'b0, "asym c3 clear at Done/MG low");
    c3_done = 1; c3_grant = 0; c3_mg = 1; #1;
    check_ok(c3_ppe == 1'b1, "asym c3 set on done and grant low");
    c3_done = 1; c3_grant = 1; c3_mg = 1; #1;
    check_ok(c3_ppe == 1'b1, "asym c3 hold high");
    c3_done = 0; c3_mg = 0; #1;
    check_ok(c3_ppe == 1'b0, "asym c3 clear on done low and mg low");

    // Global reset is asynchronous and wins regardless of D/E.
    check_ok(latch_q == 8'h00, "latch asynchronous reset clear");
    latch_reset = 0; #1;
    latch_d = 8'ha5; latch_en = 1'b1; #1;
    check_ok(latch_q == 8'ha5, "latch transparent");
    latch_en = 1'b0; latch_d = 8'h3c; #1;
    check_ok(latch_q == 8'ha5, "latch hold");
    latch_reset = 1; #1;
    check_ok(latch_q == 8'h00, "latch reset clear while closed");
    latch_reset = 0;

    mutex_req = 4'b0001; #2;
    check_ok(mutex_gnt == 4'b0001, "mutex single req0");
    mutex_req = 4'b0000; #2;
    mutex_req = 4'b1111; #2;
    $display("TB_PROBE mutex concurrent req=%b gnt=%b pop=%0d t=%0t",
             mutex_req, mutex_gnt, pop4(mutex_gnt), $time);
    check_ok(pop4(mutex_gnt) == 1, "mutex one-hot concurrent");
    mutex_req = 4'b0000; #2;
    check_ok(mutex_gnt == 4'b0000, "mutex release");
    mutex_req = 4'b0100; #2;
    check_ok(mutex_gnt == 4'b0100, "mutex req2 after release");

    mt_reset = 1'b0; #1;
    mt_in_data = 8'h5a; #1;
    mt_in_req = ~mt_in_req; #2;
    check_ok(mt_out_req == mt_in_req, "mousetrap request propagated");
    check_ok(mt_out_req != mt_out_ack, "mousetrap output pending");
    check_ok(mt_out_data == 8'h5a, "mousetrap data captured");
    mt_in_data = 8'hc3; #2;
    check_ok(mt_out_data == 8'h5a, "mousetrap output hold while pending");
    mt_out_ack = mt_out_req; #2;
    check_ok(mt_out_req == mt_out_ack, "mousetrap output released");
    check_ok(mt_out_data == 8'hc3, "mousetrap latches reopen together");

    $display("TB_RESULT PASS req=%b grant=%b outData=%h",
             mt_in_req, mutex_gnt, mt_out_data);
    $finish;
  end
endmodule
