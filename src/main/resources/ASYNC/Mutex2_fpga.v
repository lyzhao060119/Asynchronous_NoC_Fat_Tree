`timescale 1ns / 1ps

// Synthesizable FPGA mutex model built from a cross-coupled LUT NAND pair.
// This preserves the structural feedback loop, but metastability resolution
// time must be characterized on the target device.
module Mutex2(
    input  wire req0,
    input  wire req1,
    output wire gnt0,
    output wire gnt1
);
    (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) wire q0;
    (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) wire q1;

    (* DONT_TOUCH = "TRUE" *)
    LUT2 #(.INIT(4'h7)) q0_nand (
        .O(q0),
        .I0(req0),
        .I1(q1)
    );

    (* DONT_TOUCH = "TRUE" *)
    LUT2 #(.INIT(4'h7)) q1_nand (
        .O(q1),
        .I0(req1),
        .I1(q0)
    );

    assign gnt0 = ~q0;
    assign gnt1 = ~q1;
endmodule
