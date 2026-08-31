`timescale 1ns / 1ps

module Mutex4(
    input  wire req0,
    input  wire req1,
    input  wire req2,
    input  wire req3,
    output wire gnt0,
    output wire gnt1,
    output wire gnt2,
    output wire gnt3
);
    wire left_req;
    wire right_req;
    wire left_gnt;
    wire right_gnt;
    wire left_gnt0;
    wire left_gnt1;
    wire right_gnt0;
    wire right_gnt1;

    assign left_req = req0 | req1;
    assign right_req = req2 | req3;

    Mutex2 u_left_mutex (
        .req0(req0),
        .req1(req1),
        .gnt0(left_gnt0),
        .gnt1(left_gnt1)
    );

    Mutex2 u_right_mutex (
        .req0(req2),
        .req1(req3),
        .gnt0(right_gnt0),
        .gnt1(right_gnt1)
    );

    Mutex2 u_middle_mutex (
        .req0(left_req),
        .req1(right_req),
        .gnt0(left_gnt),
        .gnt1(right_gnt)
    );

    // Hierarchical grant composition must withdraw the old leaf as soon as
    // that leaf loses its request. A state-holding C-element here retains the
    // old grant while a sibling waits in the same group and briefly (or
    // permanently in RTL) exposes two grants. Metastability is contained by
    // the three Mutex2 instances; these gates only qualify their resolved
    // leaf decisions with the resolved group decision.
    assign gnt0 = left_gnt  & left_gnt0;
    assign gnt1 = left_gnt  & left_gnt1;
    assign gnt2 = right_gnt & right_gnt0;
    assign gnt3 = right_gnt & right_gnt1;
endmodule
