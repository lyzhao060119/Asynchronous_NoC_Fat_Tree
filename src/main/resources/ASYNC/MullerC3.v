`timescale 1ns / 1ps

module MullerC3(
    input  wire reset,
    input  wire Grant,
    input  wire Done,
    input  wire MG,
    output wire PPE
);
    // Ultra Fig. 5(a) C3 state equation:
    // PPE+ = Done & ~Grant + PPE & (Done | MG).
    // Pure combinational self-feedback state equation.  Reset only clamps
    // the feedback node to zero; this module contains no latch or register.
    assign PPE = reset ? 1'b0 : ((PPE & MG) | (PPE & Done) | (Done & ~Grant));
endmodule
