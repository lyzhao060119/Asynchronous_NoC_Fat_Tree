`timescale 1ns / 1ps

// One asynchronous rotated-greedy decision stage.  CandidateReq and the
// close token contend in Mutex2.  Candidate wins record membership for this
// round; close wins exclude late candidates from this round.  Both outcomes
// leave an uncommitted packetPresent request intact for a later round.
module AsyncRoundDecisionCell #(
    parameter DelayValue = 1,
    parameter DelayUnitPs = 250
) (
    input  wire       reset,
    input  wire       round_reset,
    input  wire       candidate_req,
    input  wire [4:0] candidate_mask,
    input  wire [4:0] candidate_onehot,
    input  wire [4:0] accepted_in,
    input  wire [4:0] winner_in,
    input  wire       close_req,
    input  wire       close_out_ack,
    output wire       candidate_ack,
    output wire       close_ack,
    output wire       close_out_req,
    output wire [4:0] accepted_out,
    output wire [4:0] winner_out
);
    wire cand_grant;
    wire close_grant;
    wire candidate_seen;
    wire stage_closed;
    wire close_ready;
    wire close_delayed;
    wire out_valid;
    wire conflict;
    wire take;
    wire [4:0] accepted_d;
    wire [4:0] winner_d;

    // Once stage_closed is asserted, a late candidate is masked.  If both
    // requests are close, Mutex2 contains the metastability and returns only
    // one stable grant.
    Mutex2 join_or_close (
        .req0(candidate_req & ~stage_closed & ~candidate_ack),
        .req1(close_req),
        .gnt0(cand_grant),
        .gnt1(close_grant)
    );

    // Ack remains asserted until round reset so a still-pending candidate
    // cannot re-offer itself to the same stage after Mutex2 releases.
    DLatchBank #(.WIDTH(1)) seen_latch (
        .reset(reset), .en(round_reset | cand_grant),
        .d(round_reset ? 1'b0 : (candidate_seen | cand_grant)),
        .q(candidate_seen)
    );
    DLatchBank #(.WIDTH(1)) candidate_ack_latch (
        .reset(reset), .en(round_reset | cand_grant),
        .d(round_reset ? 1'b0 : (candidate_ack | cand_grant)),
        .q(candidate_ack)
    );
    DLatchBank #(.WIDTH(1)) closed_latch (
        .reset(reset), .en(round_reset | close_grant),
        .d(round_reset ? 1'b0 : (stage_closed | close_grant)),
        .q(stage_closed)
    );

    // close_ready is a consensus point: the stage only advances after its
    // close state and matched-control path agree.
    DelayElement #(.DelayValue(DelayValue), .DelayUnitPs(DelayUnitPs)) decision_margin (
        .I(close_grant), .Z(close_delayed)
    );
    MullerC2 close_consensus (
        .reset(reset | round_reset), .A(stage_closed), .B(close_delayed), .Z(close_ready)
    );

    assign conflict   = |(candidate_mask & accepted_in);
    assign take       = candidate_seen & ~conflict;
    assign accepted_d = take ? (accepted_in | candidate_mask) : accepted_in;
    assign winner_d   = take ? (winner_in | candidate_onehot) : winner_in;

    // Data latches remain transparent until the matched close control is
    // complete; their Q values are then the only values exported downstream.
    DLatchBank #(.WIDTH(5)) accepted_latch (
        .reset(reset), .en(round_reset | ~out_valid),
        .d(round_reset ? 5'b0 : accepted_d),
        .q(accepted_out)
    );
    DLatchBank #(.WIDTH(5)) winner_latch (
        .reset(reset), .en(round_reset | ~out_valid),
        .d(round_reset ? 5'b0 : winner_d),
        .q(winner_out)
    );
    DLatchBank #(.WIDTH(1)) valid_latch (
        .reset(reset), .en(round_reset | close_ready),
        .d(round_reset ? 1'b0 : (out_valid | close_ready)),
        .q(out_valid)
    );

    assign close_out_req = out_valid;
    // Ack propagates upstream only after the downstream stage has captured
    // the immutable output bundle.  The final stage's Ack comes from the
    // transaction latch.
    assign close_ack = out_valid & close_out_ack;
endmodule
