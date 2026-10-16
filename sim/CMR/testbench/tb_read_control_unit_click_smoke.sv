`timescale 1ns/1ps

module tb_read_control_unit_click_smoke;
  reg reset = 1'b1;
  reg CellFull = 1'b0;
  reg ReadPointer = 1'b1;
  reg AckX = 1'b0;
  wire Req;
  wire CellEmpty;
  integer failures = 0;

  ReadControlUnit dut (
    .io_reset(reset), .io_CellFull(CellFull),
    .io_ReadPointer(ReadPointer), .io_AckX(AckX),
    .io_Req(Req), .io_CellEmpty(CellEmpty)
  );

  task automatic check(input bit condition, input string message);
    if (!condition) begin
      failures = failures + 1;
      $display("TB_RESULT FAIL %s t=%0t full=%b rp=%b ackx=%b req=%b empty=%b",
               message, $time, CellFull, ReadPointer, AckX, Req, CellEmpty);
    end
  endtask

  initial begin
    #2; reset = 1'b0; #2;
    check(Req === 1'b0 && CellEmpty === 1'b0, "reset phase mismatch");

    CellFull = 1'b1;
    #5; // DEL20 = 4 ns in DelayElement_sim
    check(Req === 1'b1, "selected full cell did not toggle Req");
    check(CellEmpty === 1'b1, "CellEmpty did not toggle with Req");
    check(Req === CellEmpty, "Req and CellEmpty are not directly phase-coupled");

    AckX = 1'b1;
    #5;
    check(Req === 1'b1 && CellEmpty === 1'b1,
          "downstream AckX alone retriggered the Click controller");

    CellFull = 1'b0;
    #5;
    check(Req === 1'b0 && CellEmpty === 1'b0,
          "next CellFull phase did not toggle Req and CellEmpty together");

    if (failures == 0)
      $display("TB_RESULT PASS ReadControlUnit Click direct phase coupling");
    else
      $display("TB_RESULT FAIL ReadControlUnit Click failures=%0d", failures);
    $finish;
  end
endmodule
