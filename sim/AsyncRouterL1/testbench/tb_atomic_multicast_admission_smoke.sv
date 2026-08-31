`timescale 1ns/1ps
// Interface-only smoke for AtomicMulticastArbiterV2.  RS is held until the
// packet is admitted/released; the test never uses implementation probes.
module tb_atomic_multicast_admission_smoke;
  reg clock=0, reset=1;
  reg [3:0] rs[0:4];
  reg [4:0] all_tail_passed=0, output_tail_busy=0;
  wire [3:0] admitted_rs[0:4];
  wire [4:0] active;
  wire [4:0] tail_release_ready;
  wire [2:0] owner[0:4];
  wire [4:0] packet_mask[0:4];
  integer i;
  localparam [2:0] NONE=3'd5;

  AtomicMulticastArbiterV2 dut(
    .clock(clock),.reset(reset),
    .io_RS_0_0(rs[0][0]),.io_RS_0_1(rs[0][1]),.io_RS_0_2(rs[0][2]),.io_RS_0_3(rs[0][3]), .io_RS_1_0(rs[1][0]),.io_RS_1_1(rs[1][1]),.io_RS_1_2(rs[1][2]),.io_RS_1_3(rs[1][3]), .io_RS_2_0(rs[2][0]),.io_RS_2_1(rs[2][1]),.io_RS_2_2(rs[2][2]),.io_RS_2_3(rs[2][3]), .io_RS_3_0(rs[3][0]),.io_RS_3_1(rs[3][1]),.io_RS_3_2(rs[3][2]),.io_RS_3_3(rs[3][3]), .io_RS_4_0(rs[4][0]),.io_RS_4_1(rs[4][1]),.io_RS_4_2(rs[4][2]),.io_RS_4_3(rs[4][3]),
    .io_allTailPassed_0(all_tail_passed[0]),.io_allTailPassed_1(all_tail_passed[1]),.io_allTailPassed_2(all_tail_passed[2]),.io_allTailPassed_3(all_tail_passed[3]),.io_allTailPassed_4(all_tail_passed[4]),
    .io_outputTailBusy_0(output_tail_busy[0]),.io_outputTailBusy_1(output_tail_busy[1]),.io_outputTailBusy_2(output_tail_busy[2]),.io_outputTailBusy_3(output_tail_busy[3]),.io_outputTailBusy_4(output_tail_busy[4]),
    .io_admittedRS_0_0(admitted_rs[0][0]),.io_admittedRS_0_1(admitted_rs[0][1]),.io_admittedRS_0_2(admitted_rs[0][2]),.io_admittedRS_0_3(admitted_rs[0][3]), .io_admittedRS_1_0(admitted_rs[1][0]),.io_admittedRS_1_1(admitted_rs[1][1]),.io_admittedRS_1_2(admitted_rs[1][2]),.io_admittedRS_1_3(admitted_rs[1][3]), .io_admittedRS_2_0(admitted_rs[2][0]),.io_admittedRS_2_1(admitted_rs[2][1]),.io_admittedRS_2_2(admitted_rs[2][2]),.io_admittedRS_2_3(admitted_rs[2][3]), .io_admittedRS_3_0(admitted_rs[3][0]),.io_admittedRS_3_1(admitted_rs[3][1]),.io_admittedRS_3_2(admitted_rs[3][2]),.io_admittedRS_3_3(admitted_rs[3][3]), .io_admittedRS_4_0(admitted_rs[4][0]),.io_admittedRS_4_1(admitted_rs[4][1]),.io_admittedRS_4_2(admitted_rs[4][2]),.io_admittedRS_4_3(admitted_rs[4][3]),
    .io_outputOwner_0(owner[0]),.io_outputOwner_1(owner[1]),.io_outputOwner_2(owner[2]),.io_outputOwner_3(owner[3]),.io_outputOwner_4(owner[4]),
    .io_packetMask_0(packet_mask[0]),.io_packetMask_1(packet_mask[1]),.io_packetMask_2(packet_mask[2]),.io_packetMask_3(packet_mask[3]),.io_packetMask_4(packet_mask[4]),
    .io_packetActive_0(active[0]),.io_packetActive_1(active[1]),.io_packetActive_2(active[2]),.io_packetActive_3(active[3]),.io_packetActive_4(active[4]),
    .io_tailReleaseReady_0(tail_release_ready[0]),.io_tailReleaseReady_1(tail_release_ready[1]),.io_tailReleaseReady_2(tail_release_ready[2]),.io_tailReleaseReady_3(tail_release_ready[3]),.io_tailReleaseReady_4(tail_release_ready[4]));
  always #5 clock=~clock;

  task fail(input [8*100-1:0] s); begin
    $display("TB_RESULT FAIL %0s active=%b owner=%d,%d,%d,%d,%d masks=%b,%b,%b,%b,%b",
      s,active,owner[0],owner[1],owner[2],owner[3],owner[4],packet_mask[0],packet_mask[1],packet_mask[2],packet_mask[3],packet_mask[4]);
    $fatal(1,"AtomicMulticastArbiterV2 smoke failed");
  end endtask
  task reset_dut; integer j; begin
    for(j=0;j<5;j=j+1) rs[j]=0;
    all_tail_passed=0; output_tail_busy=0; reset=1; #10; reset=0; #10;
    if(active!==5'b0 || tail_release_ready!==5'b11111 || owner[0]!==NONE || owner[1]!==NONE || owner[2]!==NONE || owner[3]!==NONE || owner[4]!==NONE)
      fail("reset state");
  end endtask
  task release_one(input integer input_id); begin
    rs[input_id]=0; all_tail_passed[input_id]=1; #8;
    all_tail_passed[input_id]=0;
  end endtask
  task check_legal_edge(input integer input_id, input integer branch);
    integer output_id;
    begin
      output_id = (branch < input_id) ? branch : branch + 1;
      reset_dut; rs[input_id] = (4'b0001 << branch); #10;
      if(!active[input_id] || owner[output_id]!==input_id[2:0] || packet_mask[input_id] !== (5'b00001 << output_id)) begin
        $display("LEGAL_EDGE input=%0d branch=%0d output=%0d rs=%b",input_id,branch,output_id,rs[input_id]);
        fail("legal input/output branch mapping");
      end
      release_one(input_id); #4;
    end
  endtask

  initial begin
    // I0 branch3 maps to O4.
    reset_dut; rs[0]=4'b1000; #12;
    if(!active[0] || packet_mask[0]!==5'b10000 || owner[4]!==3'd0 || admitted_rs[0]!==4'b1000) fail("single head admission");
    release_one(0); #5;
    if(active[0] || !tail_release_ready[0] || owner[4]!==NONE) fail("single tail release");

    // Exhaust the static no-U-turn mapping: every input's four RS branches
    // must reserve exactly its corresponding physical output.
    for(i=0;i<5;i=i+1) begin : legal_input
      check_legal_edge(i,0); check_legal_edge(i,1); check_legal_edge(i,2); check_legal_edge(i,3);
    end

    // Parent I4 -> O0/O1; I0 -> O2/O3.  Both complete sets are disjoint.
    reset_dut; rs[4]=4'b0011; rs[0]=4'b0110; #18;
    if(!active[4] || !active[0] || owner[0]!==3'd4 || owner[1]!==3'd4 || owner[2]!==3'd0 || owner[3]!==3'd0)
      fail("disjoint parallel admission");
    release_one(4); #3;
    if(active[4] || !active[0] || owner[2]!==3'd0 || owner[3]!==3'd0) fail("disjoint release isolation");
    release_one(0); #4;

    // A request that arrives after the anchor transaction has closed cannot
    // rewrite its owner bundle. It is admitted only in the following round.
    reset_dut; rs[4]=4'b0001; #8; // I4 owns O0
    rs[0]=4'b0001; #0.05;
    if(active[0] || owner[0]!==3'd4) fail("late candidate cannot alter frozen transaction");
    #10;
    if(!active[0] || owner[0]!==3'd4 || owner[1]!==3'd0) fail("late candidate next round admission");
    release_one(4); release_one(0); #4;

    // I4 first owns O1; later I0 requests the same output and must remain
    // pending until I4's complete set is released.
    reset_dut; rs[4]=4'b0010; #10; rs[0]=4'b0001; #10;
    if(!active[4] || active[0] || owner[1]!==3'd4) fail("overlap blocks complete set");
    release_one(4); #10;
    if(!active[0] || owner[1]!==3'd0 || packet_mask[0]!==5'b00010) fail("overlap retries after release");
    release_one(0); #4;

    // Anchor I4, then rotated order I0/I1/I2/I3.  I2 conflicts with I0 on
    // O1 while I0/I1/I3 are pairwise disjoint with the anchor.
    reset_dut; rs[4]=4'b0001; rs[0]=4'b0001; rs[1]=4'b0010; rs[2]=4'b0010; rs[3]=4'b1000; #20;
    if(!active[4] || !active[0] || !active[1] || active[2] || !active[3]) fail("rotated greedy winners");
    if(owner[0]!==3'd4 || owner[1]!==3'd0 || owner[2]!==3'd1 || owner[4]!==3'd3) fail("rotated greedy owners");
    release_one(4); release_one(0); release_one(1); release_one(3); #10;
    if(!active[2] || owner[1]!==3'd2) fail("conflict candidate next round");
    release_one(2); #4;

    // After owner clears, old TP still blocks re-allocation until tail busy
    // deasserts. I0's O4 request remains pending during that barrier.
    reset_dut; rs[0]=4'b1000; #10; rs[0]=0; all_tail_passed[0]=1; output_tail_busy[4]=1; #10;
    all_tail_passed[0]=0; rs[1]=4'b1000; #10;
    if(active[1] || owner[4]!==NONE) fail("tail busy barrier");
    output_tail_busy[4]=0; #12;
    if(!active[1] || owner[4]!==3'd1) fail("tail busy clears then admits");
    release_one(1); #4;

    $display("TB_RESULT PASS AtomicMulticastArbiterV2 interface smoke");
    $finish;
  end
endmodule
