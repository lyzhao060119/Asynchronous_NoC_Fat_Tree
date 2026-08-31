`timescale 1ns/1ps

// Diagnostic-only reproduction of ContinuousLaneSelector(laneCount = 2).
// Keep the candidate equation identical to CMRLaneArbitration.scala so an
// asserted PathEnabled with both lanes idle produces the field req=2'b11.
module CMRLaneSelectorMutex2Harness (
    input  wire       reset,
    input  wire       PathEnabled,
    input  wire [1:0] OtherGrant,
    output wire [1:0] mutex_req,
    output wire [1:0] LaneSelect
);
    assign mutex_req[0] = PathEnabled & ~OtherGrant[0];
    assign mutex_req[1] = PathEnabled & ~OtherGrant[1];

    CMRMutexN #(.WIDTH(2)) mutex (
        .reset(reset),
        .req(mutex_req),
        .grant(LaneSelect)
    );
endmodule
