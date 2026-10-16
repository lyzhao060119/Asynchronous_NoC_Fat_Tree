`timescale 1ns/1ps

module tb_cmr_ipm_click_smoke;
  reg clock = 1'b0;
  reg reset = 1'b1;
  reg Reqin = 1'b0;
  reg [27:0] Datain = 28'b0;
  reg [3:0] Ackin = 4'b0000;
  reg [3:0] TailPassed = 4'b0000;
  wire Ackout;
  wire [3:0] Reqout;
  wire [27:0] Dataout [0:3];
  wire [3:0] PathEnabled;
  integer failures = 0;

  IPM dut (
    .clock(clock), .reset(reset), .io_Reqin(Reqin), .io_Datain_flit(Datain),
    .io_Ackout(Ackout),
    .io_Ackin_0(Ackin[0]), .io_Ackin_1(Ackin[1]),
    .io_Ackin_2(Ackin[2]), .io_Ackin_3(Ackin[3]),
    .io_TailPassed_0(TailPassed[0]), .io_TailPassed_1(TailPassed[1]),
    .io_TailPassed_2(TailPassed[2]), .io_TailPassed_3(TailPassed[3]),
    .io_Reqout_0(Reqout[0]), .io_Reqout_1(Reqout[1]),
    .io_Reqout_2(Reqout[2]), .io_Reqout_3(Reqout[3]),
    .io_Dataout_0_flit(Dataout[0]), .io_Dataout_1_flit(Dataout[1]),
    .io_Dataout_2_flit(Dataout[2]), .io_Dataout_3_flit(Dataout[3]),
    .io_PathEnabled_0(PathEnabled[0]), .io_PathEnabled_1(PathEnabled[1]),
    .io_PathEnabled_2(PathEnabled[2]), .io_PathEnabled_3(PathEnabled[3])
  );

  always #5 clock = ~clock;

  function automatic [27:0] make_flit(
    input bit Head, input bit Tail,
    input [5:0] x0, input [5:0] y0,
    input [5:0] x1, input [5:0] y1
  );
    begin
      make_flit = 28'b0;
      make_flit[27] = Head;
      make_flit[26] = Tail;
      make_flit[7:2] = x0;  make_flit[13:8] = y0;
      make_flit[19:14] = x1; make_flit[25:20] = y1;
    end
  endfunction

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t in=%b/%b path=%b out=%b/%b",
               message, $time, Reqin, Ackout, PathEnabled, Reqout, Ackin);
    end
  endtask

  initial begin
    #5; reset = 1'b0; #3;
    check(!$isunknown({Ackout, Reqout, PathEnabled}), "reset output contains X/Z");

    // L1 parent ingress, rectangle (0,0)-(1,1): all four local branches.
    Datain = make_flit(1'b1, 1'b0, 0, 0, 1, 1);
    Reqin = 1'b1;
    #12;
    check(Ackout === Reqin, "IPM did not accept multicast Head");
    check(PathEnabled === 4'b1111, "RCU local branch mapping mismatch");
    check(Reqout === 4'b1111, "four local Read requests are not pending");
    check(Dataout[0] === Datain && Dataout[1] === Datain &&
          Dataout[2] === Datain && Dataout[3] === Datain,
          "IPM did not retain Head on all selected branches");

    // Each output must remain pending independently until its Ackin arrives.
    Ackin[0] = Reqout[0];
    #3;
    check(Reqout[0] === Ackin[0],
          "acknowledged IPM branch changed request phase without a new flit");
    check(Reqout[1] !== Ackin[1] && Reqout[2] !== Ackin[2] &&
          Reqout[3] !== Ackin[3], "unacknowledged IPM branches advanced early");

    if (failures == 0)
      $display("TB_RESULT PASS CMR IPM Click multicast/backpressure smoke");
    else
      $display("TB_RESULT FAIL CMR IPM Click failures=%0d", failures);
    $finish;
  end
endmodule
