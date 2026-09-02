`timescale 1ns / 1ps

// Balanced OR reduction so 8-wide Ack/Commit trees do not collapse to a
// linear chain under MAXIMUM-SDF.  Recurses on half-width until a leaf.
module CmrOrReduce #(
    parameter WIDTH = 2
) (
    input  wire [WIDTH-1:0] in,
    output wire             out
);
    generate
        if (WIDTH == 1) begin : leaf
            assign out = in[0];
        end else if (WIDTH == 2) begin : pair
            assign out = in[0] | in[1];
        end else begin : split
            localparam integer LO = WIDTH / 2;
            localparam integer HI = WIDTH - LO;
            wire lo_or;
            wire hi_or;
            CmrOrReduce #(.WIDTH(LO)) u_lo (
                .in(in[LO-1:0]),
                .out(lo_or)
            );
            CmrOrReduce #(.WIDTH(HI)) u_hi (
                .in(in[WIDTH-1:LO]),
                .out(hi_or)
            );
            assign out = lo_or | hi_or;
        end
    endgenerate
endmodule

// Two-phase phase translator between one direction-level CMR read channel
// and a dynamically selected physical output lane.  LaneSelect may move while
// no OPM has granted the requester; Commit is one-hot and remains asserted for
// the packet once the second-level OPM mutex resolves.
module LanePhaseAdapter #(
    parameter LANES = 2
) (
    input  wire                 reset,
    input  wire                 Reqin,
    input  wire [LANES-1:0]     LaneSelect,
    input  wire [LANES-1:0]     Commit,
    input  wire [LANES-1:0]     Ackin,
    output wire                 Ackout,
    output wire [LANES-1:0]     Reqout
);
    wire SelectionValid;
    wire Assigned;
    wire SelectedAck;
    wire CommittedAck;
    wire PhaseOffset;
    wire [LANES-1:0] selected_ack_bits = LaneSelect & Ackin;
    wire [LANES-1:0] committed_ack_bits = Commit & Ackin;

    CmrOrReduce #(.WIDTH(LANES)) u_selection_valid (
        .in(LaneSelect),
        .out(SelectionValid)
    );
    CmrOrReduce #(.WIDTH(LANES)) u_assigned (
        .in(Commit),
        .out(Assigned)
    );
    CmrOrReduce #(.WIDTH(LANES)) u_selected_ack (
        .in(selected_ack_bits),
        .out(SelectedAck)
    );
    CmrOrReduce #(.WIDTH(LANES)) u_committed_ack (
        .in(committed_ack_bits),
        .out(CommittedAck)
    );

    // While arbitration is unresolved, continuously prepare the phase offset
    // for the currently selected lane.  Commit closes this latch before the
    // selected channel is allowed to carry a request.
    PhaseResetDLatch #(.INITIAL_PHASE(1'b0)) OffsetLatch (
        .reset(reset),
        .en(~Assigned & SelectionValid),
        .d(Ackout ^ SelectedAck),
        .q(PhaseOffset)
    );

    // Only the committed lane may advance the direction-level acknowledgement.
    // The Ack data/Assigned-close relationship is a paired relative-timing
    // constraint recorded for DC/P&R, not an RTL buffer.
    PhaseResetDLatch #(.INITIAL_PHASE(1'b0)) AckLatch (
        .reset(reset),
        .en(Assigned),
        .d(CommittedAck ^ PhaseOffset),
        .q(Ackout)
    );

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : lane_phase
            // An uncommitted channel is kept idle in its own phase.  Once
            // committed, every upstream two-phase transition is translated by
            // the offset captured above.
            assign Reqout[lane] = Commit[lane]
                ? (Reqin ^ PhaseOffset)
                : Ackin[lane];
        end
    endgenerate
endmodule

// Hold the first one-hot LaneSelect for the PathEnabled lifetime so a
// wormhole body cannot migrate to another physical lane when OtherGrant
// flickers.  HeldSelect tracks LaneSelect until the first capture.
module WormholeLaneLock #(
    parameter LANES = 2
) (
    input  wire             reset,
    input  wire             PathEnabled,
    input  wire [LANES-1:0] LaneSelect,
    output wire [LANES-1:0] HeldSelect
);
    wire HeldValid;
    wire [LANES-1:0] held_bits;

    CmrOrReduce #(.WIDTH(LANES)) u_held (
        .in(held_bits),
        .out(HeldValid)
    );

    genvar lane;
    generate
        for (lane = 0; lane < LANES; lane = lane + 1) begin : hold
            PhaseResetDLatch #(.INITIAL_PHASE(1'b0)) u_hold (
                .reset(reset | ~PathEnabled),
                .en(PathEnabled & LaneSelect[lane] & ~HeldValid),
                .d(1'b1),
                .q(held_bits[lane])
            );
        end
    endgenerate

    assign HeldSelect = HeldValid ? held_bits : LaneSelect;
endmodule
