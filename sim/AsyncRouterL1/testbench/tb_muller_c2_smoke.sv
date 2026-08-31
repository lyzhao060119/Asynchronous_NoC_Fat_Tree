`timescale 1ns/1ps

module tb_muller_c2_smoke;
    reg reset;
    reg A;
    reg B;
    wire Z;
    
    MullerC2 dut (.reset(reset), .A(A), .B(B), .Z(Z));

    task automatic check(input bit condition, input [8*80-1:0] message);
      if (!condition) begin
        $display("TB_FAIL MullerC2 %0s t=%0t A/B/Z=%b/%b/%b", message, $time, A, B, Z);
        $finish(1);
      end
    endtask

    initial begin
        reset = 1; A = 1'bx; B = 1'bx; #1;
        check(Z === 1'b0, "reset clears Z despite unknown inputs");
        reset = 0; A = 0; B = 0; #1;
        check(Z === 1'b0, "00 clears Z");
        A = 1; B = 0; #1;
        check(Z === 1'b0, "10 retains zero");
        A = 1; B = 1; #1;
        check(Z === 1'b1, "11 sets Z");
        A = 0; B = 1; #1;
        check(Z === 1'b1, "01 retains one");
        A = 0; B = 0; #1;
        check(Z === 1'b0, "00 clears one");
        $display("TB_RESULT PASS MullerC2 smoke");
        $finish;
    end
endmodule
