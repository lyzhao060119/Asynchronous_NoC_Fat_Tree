`timescale 1ns / 1ps

// Functional simulation model only. The slightly different # delays avoid
// both zero-delay oscillation and the non-physical symmetric solution where
// an exact digital tie produces two grants. Real mutex devices always contain
// mismatch; this deterministic 10 ps simulation skew is not an arbitration
// priority guarantee and is not synthesizable.
module Mutex2(
    input  wire req0,
    input  wire req1,
    output wire gnt0,
    output wire gnt1
);
    wire q0;
    wire q1;

    assign #(0.10) q0 = ~(req0 & q1);
    assign #(0.11) q1 = ~(req1 & q0);
    assign gnt0 = ~q0;
    assign gnt1 = ~q1;
endmodule
