`timescale 1ns / 1ps

// Functional sim stand-in for one BUFFD0 (~10 ps).
module DontTouchBuf (
    input  wire I,
    output wire Z
);

    assign #0.01 Z = I;

endmodule
