`timescale 1ns/1ps

module tb_read_phase_selector_click_smoke;
  reg reset = 1'b1;
  reg ReqX = 1'b0;
  reg Ackin = 1'b0;
  reg [3:0] PathEnabled = 4'b0000;
  wire Reqout;
  wire AckX;
  integer failures = 0;

  ReadPhaseSelector dut (
    .io_reset(reset), .io_ReqX(ReqX), .io_Ackin(Ackin),
    .io_PathEnabled(PathEnabled), .io_Reqout(Reqout), .io_AckX(AckX)
  );

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t reqx=%b ackx=%b reqout=%b ackin=%b path=%b",
               message, $time, ReqX, AckX, Reqout, Ackin, PathEnabled);
    end
  endtask

  initial begin
    #2; reset = 1'b0; #2;
    check(Reqout === 1'b0 && AckX === 1'b0, "reset phase mismatch");

    // localBranch=0: bit zero is the local enable selected by mask 0001.
    PathEnabled = 4'b0001;
    ReqX = 1'b1;
    #5; // DEL20 = 4 ns in DelayElement_sim
    check(Reqout === 1'b1, "local request did not reach Reqout");
    check(AckX === 1'b0, "AckX completed before downstream Ackin");

    Ackin = 1'b1;
    #1;
    check(Reqout === 1'b1 && AckX === 1'b1,
          "AckX did not complete after downstream Ackin");

    ReqX = 1'b0;
    #5;
    check(Reqout === 1'b0 && AckX === 1'b1,
          "next ReqX phase did not toggle Reqout");

    Ackin = 1'b0;
    #1;
    check(AckX === 1'b0, "AckX did not complete the return phase");

    if (failures == 0)
      $display("TB_RESULT PASS ReadPhaseSelector Click local mask and downstream completion");
    else
      $display("TB_RESULT FAIL ReadPhaseSelector Click failures=%0d", failures);
    $finish;
  end
endmodule
