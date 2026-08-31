`timescale 1ns/1ps
module tb_cmr_mutexn_smoke;
  reg reset = 1;
  reg [4:0] r5 = 0; wire [4:0] g5;
  reg [7:0] r8 = 0; wire [7:0] g8;
  reg [9:0] r10 = 0; wire [9:0] g10;
  reg [15:0] r16 = 0; wire [15:0] g16;
  reg [19:0] r20 = 0; wire [19:0] g20;
  integer failures = 0;

  CMRMutexN #(.WIDTH(5)) m5(reset,r5,g5);
  CMRMutexN #(.WIDTH(8)) m8(reset,r8,g8);
  CMRMutexN #(.WIDTH(10)) m10(reset,r10,g10);
  CMRMutexN #(.WIDTH(16)) m16(reset,r16,g16);
  CMRMutexN #(.WIDTH(20)) m20(reset,r20,g20);

  task check(input bit ok, input string why); begin
    if (!ok) begin failures++; $display("TB_CHECK_FAIL %s t=%0t",why,$time); end
  end endtask
  function automatic bit onehot20(input [19:0] value);
    onehot20 = value != 0 && ((value & (value-1'b1)) == 0);
  endfunction

  initial begin
    #2 reset=0;
    r5=5'b00100; r8=8'b10000000; r10=10'b0000010000;
    r16=16'h0002; r20=20'h80000; #5;
    check(g5==r5,"mutex5 individual"); check(g8==r8,"mutex8 individual");
    check(g10==r10,"mutex10 individual"); check(g16==r16,"mutex16 individual");
    check(g20==r20,"mutex20 individual");
    r5=0; r8=0; r10=0; r16=0; r20=0; #4;

    r20={20{1'b1}}; #8;
    check(onehot20(g20),"mutex20 simultaneous onehot");
    check((g20 & r20)==g20,"mutex20 grant requested");
    r20=20'hfffff; #3;
    check(onehot20(g20),"mutex20 winner hold");
    r20=0; #5; check(g20==0,"mutex20 release");

    r5=5'b10001; r8=8'b10000001; r10=10'b1000000001;
    r16=16'h8001; #8;
    check(g5!=0 && ((g5&(g5-1'b1))==0),"mutex5 contention");
    check(g8!=0 && ((g8&(g8-1'b1))==0),"mutex8 contention");
    check(g10!=0 && ((g10&(g10-1'b1))==0),"mutex10 contention");
    check(g16!=0 && ((g16&(g16-1'b1))==0),"mutex16 contention");
    if (failures==0) $display("TB_RESULT PASS CMR exact TAC mutex smoke");
    else $display("TB_RESULT FAIL CMR exact TAC mutex failures=%0d",failures);
    $finish;
  end
endmodule
