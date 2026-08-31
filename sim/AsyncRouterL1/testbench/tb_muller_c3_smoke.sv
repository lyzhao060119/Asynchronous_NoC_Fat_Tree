`timescale 1ns/1ps

module tb_muller_c3_smoke;
  reg reset, grant, done, mg;
  wire ppe;

  MullerC3 dut (.reset(reset), .Grant(grant), .Done(done), .MG(mg), .PPE(ppe));

  task automatic check(input bit condition, input [8*96-1:0] message);
    if (!condition) begin
      $display("TB_FAIL MullerC3 %0s t=%0t reset/grant/done/mg/ppe=%b/%b/%b/%b/%b", message, $time, reset, grant, done, mg, ppe);
      $finish(1);
    end
  endtask

  initial begin
    reset = 1'b1; grant = 1'b0; done = 1'b0; mg = 1'bx;
    #1; check(ppe === 1'b0, "reset protocol must clear PPE despite MG X");
    reset = 1'b0; mg = 1'b0;
    #1; check(ppe === 1'b0, "Done/MG low must clear PPE");

    // Head: set PPE while Grant is absent, then remove the set condition.
    done = 1'b1; grant = 1'b0;
    #1; check(ppe === 1'b1, "Done & !Grant must set PPE");
    grant = 1'b1; mg = 1'b1;
    #1; check(ppe === 1'b1, "PPE must hold after Grant rises");

    // OPM Ack has followed Req for a Head/Body, but MG keeps the path alive.
    done = 1'b0;
    #1; check(ppe === 1'b1, "Done low with MG high must retain PPE");

    // Tail: masked grant falls after local TP, permitting release.
    mg = 1'b0;
    #1; check(ppe === 1'b0, "Done low with MG low must clear PPE");

    $display("TB_RESULT PASS MullerC3 smoke");
    $finish;
  end
endmodule
