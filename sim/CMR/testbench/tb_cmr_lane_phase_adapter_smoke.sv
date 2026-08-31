`timescale 1ns/1ps
module tb_cmr_lane_phase_adapter_smoke;
  reg reset=1, reqin=0;
  reg [1:0] select=0, commit=0, ackin=0;
  wire ackout; wire [1:0] reqout;
  integer failures=0;
  LanePhaseAdapter #(.LANES(2)) dut(reset,reqin,select,commit,ackin,ackout,reqout);
  task check(input bit ok,input string why); begin
    if(!ok) begin failures++; $display("TB_CHECK_FAIL %s t=%0t",why,$time); end
  end endtask
  initial begin
    #2 reset=0;
    select=2'b01; #1; commit=2'b01; #1;
    check(reqout[0]===ackin[0] && ackout===reqin,"lane0 idle phase");
    reqin=1; #2; check(reqout[0]!==ackin[0] && ackout==0,"lane0 backpressure");
    ackin[0]=reqout[0]; #2; check(ackout==1,"lane0 ack translated");
    select=0; #1;
    check(ackout==1,"ack held after select drop while committed");
    commit=0; select=2'b10; #2; commit=2'b10; #1;
    check(reqout[1]===ackin[1] && ackout==1,"lane1 different history idle");
    reqin=0; #2; check(reqout[1]!==ackin[1] && ackout==1,"falling request held");
    ackin[1]=reqout[1]; #2; check(ackout==0,"lane1 falling ack translated");
    commit=0; select=0; #2;
    check(ackout==0,"ack phase retained without assignment");
    if(failures==0) $display("TB_RESULT PASS CMR lane phase adapter smoke");
    else $display("TB_RESULT FAIL CMR phase adapter failures=%0d",failures);
    $finish;
  end
endmodule
