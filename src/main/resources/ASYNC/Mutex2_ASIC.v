`timescale 1ns / 1ps

// ASIC mutex for TSMC 28nm: cross-coupled ND2 latch followed by the
// four-input-NOR output filters of the extended-isochronic-fork basic
// arbiter.  Tying all four NOR inputs to one latch node deliberately retains
// the physical filter cell; it must not be Boolean-collapsed to an inverter.
// The filter constrains metastability propagation only.  It does not replace
// physical mutex characterization or make digital SDF an analogue model.
module Mutex2(
    input  wire req0,
    input  wire req1,
    output wire gnt0,
    output wire gnt1
);
    wire q0;
    wire q1;

    ND2D1BWP12T30P140 q0_nand (
        .A1(req0),
        .A2(q1),
        .ZN(q0)
    );

    // Intentional drive mismatch, analogue of Mutex2_sim's 0.10/0.11 ns
    // skew.  Matched ND2D1 pairs let simultaneous both-req 0->1 edges
    // cancel in SDF inertial delay, leaving q0=q1=ZN=1 with req=11 forever.
    ND2D2BWP12T30P140 q1_nand (
        .A1(req1),
        .A2(q0),
        .ZN(q1)
    );

    NR4D1BWP12T30P140 gnt0_filter (
        .A1(q0),
        .A2(q0),
        .A3(q0),
        .A4(q0),
        .ZN(gnt0)
    );

    NR4D1BWP12T30P140 gnt1_filter (
        .A1(q1),
        .A2(q1),
        .A3(q1),
        .A4(q1),
        .ZN(gnt1)
    );
endmodule
