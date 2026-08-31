`timescale 1ns/1ps
module tb_cmr_continuous_lane_smoke;
  reg reset=1; reg [1:0] want=0;
  wire [1:0] select0, select1;
  wire [1:0] opm_req0 = {select1[0],select0[0]};
  wire [1:0] opm_req1 = {select1[1],select0[1]};
  wire [1:0] opm_g0, opm_g1;
  wire [1:0] sel_req0 = {want[0] & ~opm_g1[1], want[0] & ~opm_g0[1]};
  wire [1:0] sel_req1 = {want[1] & ~opm_g1[0], want[1] & ~opm_g0[0]};
  integer failures=0;
  CMRMutexN #(.WIDTH(2)) s0(reset,sel_req0,select0);
  CMRMutexN #(.WIDTH(2)) s1(reset,sel_req1,select1);
  CMRMutexN #(.WIDTH(2)) o0(reset,opm_req0,opm_g0);
  CMRMutexN #(.WIDTH(2)) o1(reset,opm_req1,opm_g1);
  task check(input bit ok,input string why); begin
    if(!ok) begin failures++; $display("TB_CHECK_FAIL %s t=%0t",why,$time); end
  end endtask
  initial begin
    #2 reset=0; want=2'b11; #12;
    $display("LANE_STATE t=%0t sel0=%b sel1=%b o0=%b o1=%b req0=%b req1=%b",
             $time,select0,select1,opm_g0,opm_g1,opm_req0,opm_req1);
    check((select0==2'b01)||(select0==2'b10),"input0 one lane");
    check((select1==2'b01)||(select1==2'b10),"input1 one lane");
    check((|opm_g0) && (|opm_g1),"both free lanes eventually occupied");
    check(!((opm_g0[0]&opm_g1[0]) || (opm_g0[1]&opm_g1[1])),
          "one input cannot own two lanes");
    want[0]=0; #7;
    check(!(opm_g0[0]|opm_g1[0]),"input0 release");
    want[0]=1; #10;
    check((|opm_g0) && (|opm_g1),"released lane reused");
    if(failures==0) $display("TB_RESULT PASS CMR continuous two-level lane smoke");
    else $display("TB_RESULT FAIL CMR lane failures=%0d",failures);
    $finish;
  end
endmodule
