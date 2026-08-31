`timescale 1ns/1ps
// Interface-level TailJoin smoke.  Sticky state is verified through its
// architectural result allTailPassed, never through a probe port.
module tb_multicast_tail_join_smoke;
  reg clock=0, reset=1; reg [3:0] tp[0:4]; reg [4:0] mask[0:4], active=0; reg [2:0] owner[0:4];
  wire [4:0] all_tail, busy; integer i;
  MulticastTailJoin dut(
    .clock(clock),.reset(reset),
    .io_TailPassed_0_0(tp[0][0]),.io_TailPassed_0_1(tp[0][1]),.io_TailPassed_0_2(tp[0][2]),.io_TailPassed_0_3(tp[0][3]), .io_TailPassed_1_0(tp[1][0]),.io_TailPassed_1_1(tp[1][1]),.io_TailPassed_1_2(tp[1][2]),.io_TailPassed_1_3(tp[1][3]), .io_TailPassed_2_0(tp[2][0]),.io_TailPassed_2_1(tp[2][1]),.io_TailPassed_2_2(tp[2][2]),.io_TailPassed_2_3(tp[2][3]), .io_TailPassed_3_0(tp[3][0]),.io_TailPassed_3_1(tp[3][1]),.io_TailPassed_3_2(tp[3][2]),.io_TailPassed_3_3(tp[3][3]), .io_TailPassed_4_0(tp[4][0]),.io_TailPassed_4_1(tp[4][1]),.io_TailPassed_4_2(tp[4][2]),.io_TailPassed_4_3(tp[4][3]),
    .io_packetMask_0(mask[0]),.io_packetMask_1(mask[1]),.io_packetMask_2(mask[2]),.io_packetMask_3(mask[3]),.io_packetMask_4(mask[4]),
    .io_packetActive_0(active[0]),.io_packetActive_1(active[1]),.io_packetActive_2(active[2]),.io_packetActive_3(active[3]),.io_packetActive_4(active[4]),
    .io_outputOwner_0(owner[0]),.io_outputOwner_1(owner[1]),.io_outputOwner_2(owner[2]),.io_outputOwner_3(owner[3]),.io_outputOwner_4(owner[4]),
    .io_allTailPassed_0(all_tail[0]),.io_allTailPassed_1(all_tail[1]),.io_allTailPassed_2(all_tail[2]),.io_allTailPassed_3(all_tail[3]),.io_allTailPassed_4(all_tail[4]),
    .io_outputTailBusy_0(busy[0]),.io_outputTailBusy_1(busy[1]),.io_outputTailBusy_2(busy[2]),.io_outputTailBusy_3(busy[3]),.io_outputTailBusy_4(busy[4]));
  always #5 clock=~clock;
  initial begin
    for(i=0;i<5;i=i+1) begin tp[i]=0; mask[i]=0; owner[i]=3'd5; end
    #2 reset=0; active[0]=1; mask[0]=5'b00110; owner[1]=0; owner[2]=0;
    // Output1's legal local source for input0 is index 0; output2's is index 0.
    tp[1][0]=1; #1; tp[1][0]=0; #1;
    if(all_tail[0]) begin $display("TB_RESULT FAIL premature allTailPassed"); $finish(1); end
    tp[2][0]=1; #1;
    if(!all_tail[0] || !busy[2]) begin $display("TB_RESULT FAIL sticky tail join"); $finish(1); end
    $display("TB_RESULT PASS TailJoin interface smoke"); $finish;
  end
endmodule
