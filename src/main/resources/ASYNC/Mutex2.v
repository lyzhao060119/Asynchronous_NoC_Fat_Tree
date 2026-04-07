`timescale 1ns / 1ps

module Mutex2(
    input  wire req0,
    input  wire req1,
    output wire gnt0,
    output wire gnt1
);
    wire q0;
    wire q1;

    assign #(0.1) q0 = ~(req0 & q1);
    assign #(0.1) q1 = ~(req1 & q0);
    assign gnt0 = ~q0;
    assign gnt1 = ~q1;
endmodule
