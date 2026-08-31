`timescale 1ns / 1ps

// Continuous paper Fig. 7 Ack Generator.  Exactly one selected Write Control
// Unit changes phase for each accepted flit, so XOR merges the five events.
module WriteAckGenerator (
    input  wire [4:0] AckoutCell,
    output wire       Ackout
);
    assign Ackout = ^AckoutCell;
endmodule
