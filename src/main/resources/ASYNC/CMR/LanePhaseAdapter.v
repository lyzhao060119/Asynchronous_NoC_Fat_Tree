`timescale 1ns / 1ps

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
    wire SelectionValid = |LaneSelect;
    wire Assigned = |Commit;
    wire SelectedAck = |(LaneSelect & Ackin);
    wire CommittedAck = |(Commit & Ackin);
    wire PhaseOffset;

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
