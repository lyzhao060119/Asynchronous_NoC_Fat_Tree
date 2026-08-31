`timescale 1ns / 1ps

// Parallel membership boundary for one non-anchor candidate in an Atomic V2
// arbitration round.  It answers only one question: did this candidate enter
// the round before the common round-close event?  The later rotated-greedy
// calculation is deliberately outside this cell and begins only after all
// four cells have closed.
module AsyncRoundMembershipCell #(
    parameter DelayValue = 1,
    parameter DelayUnitPs = 250
) (
    input  wire reset,
    input  wire round_reset,
    input  wire candidate_req,
    input  wire round_close,
    output wire candidate_ack,
    output wire member_seen,
    output wire close_ready
);
    wire cand_grant;
    wire close_grant;
    wire stage_closed;
    wire close_delayed;
    wire memberAccepted;

    // A candidate that wins is acknowledged and therefore withdraws from the
    // Mutex.  The common close request can then complete.  If close wins
    // first, stage_closed masks the late candidate until the next round.
    // member_seen and candidate_ack share one latch: both were already
    // set by cand_grant and cleared by round_reset.
    Mutex2 join_or_close (
        .req0(candidate_req & ~stage_closed & ~candidate_ack),
        .req1(round_close),
        .gnt0(cand_grant),
        .gnt1(close_grant)
    );

    DLatchBank #(.WIDTH(1)) accepted_latch (
        .reset(reset), .en(round_reset | cand_grant),
        .d(round_reset ? 1'b0 : (memberAccepted | cand_grant)),
        .q(memberAccepted)
    );
    assign candidate_ack = memberAccepted;
    assign member_seen = memberAccepted;
    DLatchBank #(.WIDTH(1)) closed_latch (
        .reset(reset), .en(round_reset | close_grant),
        .d(round_reset ? 1'b0 : (stage_closed | close_grant)),
        .q(stage_closed)
    );

    // Do not expose closure until the close state and its unchanged DEL250
    // matched-control path agree.  This is the same per-candidate timing
    // contract formerly used by each serial decision stage.
    DelayElement #(.DelayValue(DelayValue), .DelayUnitPs(DelayUnitPs)) close_margin (
        .I(close_grant), .Z(close_delayed)
    );
    MullerC2 close_consensus (
        .reset(reset | round_reset), .A(stage_closed), .B(close_delayed), .Z(close_ready)
    );
endmodule
