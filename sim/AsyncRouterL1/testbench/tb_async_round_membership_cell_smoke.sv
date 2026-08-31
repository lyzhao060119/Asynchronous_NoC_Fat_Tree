`timescale 1ns/1ps

module tb_async_round_membership_cell_smoke;
  reg reset=1, round_reset=0, candidate_req=0, round_close=0;
  wire candidate_ack, member_seen, close_ready;

  AsyncRoundMembershipCell #(.DelayValue(1),.DelayUnitPs(250)) dut(
    .reset(reset), .round_reset(round_reset), .candidate_req(candidate_req), .round_close(round_close),
    .candidate_ack(candidate_ack), .member_seen(member_seen), .close_ready(close_ready));

  task fail(input [8*100-1:0] s); begin
    $display("TB_RESULT FAIL %0s seen=%b ack=%b ready=%b",s,member_seen,candidate_ack,close_ready);
    $fatal(1,"AsyncRoundMembershipCell smoke failed");
  end endtask
  task clear_round; begin
    candidate_req=0; round_close=0; round_reset=1; #1; round_reset=0; #1;
    if(member_seen!==0 || candidate_ack!==0 || close_ready!==0) fail("round reset clear");
  end endtask

  initial begin
    #1; reset=0; #1;
    if(member_seen!==0 || candidate_ack!==0 || close_ready!==0) fail("reset clear");

    // Candidate wins first, is remembered and acknowledged, then common close
    // completes.  The membership bit must remain high through closure.
    candidate_req=1; #0.2;
    if(member_seen!==1 || candidate_ack!==1) fail("candidate first capture");
    round_close=1; #1;
    if(member_seen!==1 || close_ready!==1) fail("candidate first close");
    clear_round;

    // Close wins first.  A later candidate cannot enter this round.
    round_close=1; #1;
    if(close_ready!==1 || member_seen!==0) fail("close first");
    candidate_req=1; #0.5;
    if(member_seen!==0 || candidate_ack!==0) fail("late candidate deferred");
    clear_round;

    // Near boundary arrival is allowed to resolve either way, but must close
    // exactly once and must not leave an unknown or dual membership state.
    candidate_req=1; #0.01; round_close=1; #1;
    if(close_ready!==1 || (^member_seen===1'bx) || (^candidate_ack===1'bx)) fail("near simultaneous close");
    clear_round;

    // The acknowledge holds a winning candidate off the same round even if
    // its source request remains asserted.
    candidate_req=1; #0.2; round_close=1; #1;
    if(member_seen!==1 || candidate_ack!==1 || close_ready!==1) fail("same round duplicate suppression");
    $display("TB_RESULT PASS AsyncRoundMembershipCell smoke");
    $finish;
  end
endmodule
