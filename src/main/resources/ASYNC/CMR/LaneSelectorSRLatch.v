`timescale 1ns / 1ps

// Packet-lifetime lane select without an SR latch.  Mutex grant feeds back
// into the request so a lost OPM contest stays on the first winner until PPE
// falls: req[i] = (LaneIsEmpty[i] | LaneSelect[i]) & PPE.
module LaneSelectorSRLatch #(
    parameter LANES = 2
) (
    input wire reset,
    input wire [LANES-1:0] LaneIsEmpty,
    input wire PPE,
    output wire [LANES-1:0] LaneSelect
);
    wire [LANES-1:0] mutex_input_requests;
    genvar i;
    generate for (i = 0; i < LANES; i = i + 1) begin : select_hold
        assign mutex_input_requests[i] = (LaneIsEmpty[i] | LaneSelect[i]) & PPE;
    end endgenerate

    CMRMutexN #(.WIDTH(LANES)) mutex_in (
        .reset(reset),
        .req(mutex_input_requests),
        .grant(LaneSelect)
    );
endmodule
