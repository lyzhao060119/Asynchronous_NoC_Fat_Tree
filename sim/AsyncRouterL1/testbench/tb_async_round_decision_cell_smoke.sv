`timescale 1ns/1ps
module tb_async_round_decision_cell_smoke;
  reg reset=1, round_reset=0, candidate_req=0, close_req=0, close_out_ack=1;
  reg [4:0] candidate_mask=0, candidate_onehot=0, accepted_in=0, winner_in=0;
  wire candidate_ack, close_ack, close_out_req;
  wire [4:0] accepted_out, winner_out;

  AsyncRoundDecisionCell #(.DelayValue(1),.DelayUnitPs(250)) dut(
    .reset(reset),.round_reset(round_reset),.candidate_req(candidate_req),
    .candidate_mask(candidate_mask),.candidate_onehot(candidate_onehot),
    .accepted_in(accepted_in),.winner_in(winner_in),.close_req(close_req),
    .close_out_ack(close_out_ack),.candidate_ack(candidate_ack),.close_ack(close_ack),
    .close_out_req(close_out_req),.accepted_out(accepted_out),.winner_out(winner_out));

  task fail(input [8*100-1:0] s); begin $display("TB_RESULT FAIL %0s",s); $fatal(1,"AsyncRoundDecisionCell smoke failed"); end endtask
  task clear_cell; begin
    reset=1; round_reset=0; candidate_req=0; close_req=0; #1;
    reset=0; #1;
  end endtask

  initial begin
    // Reset release with no token/candidate must leave every local protocol
    // state empty; this catches a latch D=1 race at reset deassertion.
    clear_cell;
    if(candidate_ack || close_out_req || close_ack || accepted_out!==5'b0 || winner_out!==5'b0)
      fail("reset release remains empty");

    // Candidate offer precedes close: it enters this round and is merged.
    clear_cell;
    accepted_in=5'b00001; winner_in=5'b00001;
    candidate_mask=5'b00110; candidate_onehot=5'b00010;
    candidate_req=1; #0.4; close_req=1; #2;
    if(!candidate_ack || !close_out_req || accepted_out!==5'b00111 || winner_out!==5'b00011)
      fail("candidate before close joins");
    candidate_req=0; close_req=0; round_reset=1; #1; round_reset=0; #1;

    // Close wins first: a later request cannot alter this round's frozen Q.
    accepted_in=5'b00001; winner_in=5'b00001;
    candidate_mask=5'b00110; candidate_onehot=5'b00010;
    close_req=1; #0.5; candidate_req=1; #2;
    if(candidate_ack || accepted_out!==5'b00001 || winner_out!==5'b00001)
      fail("late candidate deferred");
    candidate_req=0; close_req=0; round_reset=1; #1; round_reset=0; #1;

    // A seen candidate that conflicts is acknowledged but not admitted.
    accepted_in=5'b00101; winner_in=5'b00001;
    candidate_mask=5'b00110; candidate_onehot=5'b00010;
    candidate_req=1; #0.4; close_req=1; #2;
    if(!candidate_ack || accepted_out!==5'b00101 || winner_out!==5'b00001)
      fail("conflict candidate remains pending");
    $display("TB_RESULT PASS AsyncRoundDecisionCell smoke");
    $finish;
  end
endmodule
