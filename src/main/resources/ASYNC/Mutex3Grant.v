`timescale 1ns / 1ps

// IEEE ASYNC 2015 Fig. 2(a), standalone three-way arbitration core.
// A request traverses exactly two Mutex2 stages:
//   A: MutexC-A then MutexA-B; B: MutexA-B then MutexB-C;
//   P: MutexB-C then MutexC-A.
// The X ring is deliberately not replaced by a direct all-pairs comparison.
module Mutex3Grant(
    input  wire req_a,
    input  wire req_b,
    input  wire req_p,
    output wire grant_a,
    output wire grant_b,
    output wire grant_p
);
    wire x_a;
    wire x_b;
    wire x_p;
    wire y_a;
    wire y_b;
    wire y_p;

    // Fig. 2(a) deadlock detector: if each request owns exactly its first
    // mutex stage, temporarily withdraw A so P can complete its second stage.
    wire deadlock = x_a & x_b & x_p;
    wire req_a_live = req_a & ~deadlock;

    Mutex2 mutex_c_a(
        .req0(req_a_live), .req1(x_p), .gnt0(x_a), .gnt1(y_p)
    );
    Mutex2 mutex_a_b(
        .req0(x_a), .req1(req_b), .gnt0(y_a), .gnt1(x_b)
    );
    Mutex2 mutex_b_p(
        .req0(x_b), .req1(req_p), .gnt0(y_b), .gnt1(x_p)
    );

    // Fig. 2(a) grant synchronizer.  These are the three AND gates with a
    // bubble on the preceding Y input; there is no Grant-to-Grant feedback
    // and no C-element in the standalone root arbiter.
    assign grant_a = y_a & ~y_p;
    assign grant_b = y_b & ~y_a;
    assign grant_p = y_p & ~y_b;

endmodule
