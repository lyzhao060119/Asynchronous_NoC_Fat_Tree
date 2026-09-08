`timescale 1ns / 1ps

// Packet-lifetime lane selection. Once selected, a lane remains requested
// while PacketActive is high. Arbitration losers wait; they do not reselect.
module LaneSelecterCelement #(
    parameter LANES = 2
) (
    input wire reset,
    input wire [LANES-1:0] LaneIsEmpty,
    input wire PacketActive,
    output wire [LANES-1:0] LaneSelect
);
    wire [LANES-1:0] mutex_input_requests;
    wire [LANES-1:0] mutex_input_grants;
    wire [LANES-1:0] C_grant;
    genvar i;
    generate for (i = 0; i < LANES; i = i + 1) begin : select_hold
        assign mutex_input_requests[i] =
            (LaneSelect[i] | LaneIsEmpty[i]) & PacketActive;
        MullerC2 mcc (
            .reset(reset),
            .A(mutex_input_grants[i]),
            .B(mutex_input_requests[i]),
            .Z(C_grant[i])
        );
    end endgenerate
    CMRMutexN #(.WIDTH(LANES)) mutex_in (
        .reset(reset),
        .req(mutex_input_requests),
        .grant(mutex_input_grants)
    );
    CMRMutexN #(.WIDTH(LANES)) mutex_out (
        .reset(reset),
        .req(C_grant),
        .grant(LaneSelect)
    );
endmodule
