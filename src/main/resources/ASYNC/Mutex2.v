`timescale 1ns / 1ps

module Mutex2(
    input  wire req0,
    input  wire req1,
    output wire gnt0,
    output wire gnt1
);
    wire q0;
    wire q1;

    assign q0 = ~(req0 & q1);
    assign q1 = ~(req1 & q0);

    nor nor_4_gnt0(gnt0, q0, q0, q0, q0);
    nor nor_4_gnt1(gnt1, q1, q1, q1, q1);
endmodule
