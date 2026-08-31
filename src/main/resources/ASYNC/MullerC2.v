`timescale 1ns / 1ps

module MullerC2(
    input  wire reset,
    input  wire A,
    input  wire B,
    output wire Z
);
    // Pure combinational self-feedback Muller equation.  Reset only clamps
    // the feedback node to zero; this module contains no latch or register.
    assign Z = reset ? 1'b0 : ((A & Z) | (A & B) | (B & Z));
endmodule
