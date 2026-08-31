`timescale 1ns / 1ps

// Parent-biased five-way anchor selector: (I0,I1), (I2,I3), and Parent I4.
// This primitive deliberately does not reserve output masks or create an ACG
// event; AtomicMulticastAdmission will consume grant[] in a later change.
module Mutex5Anchor(
    input  wire       reset,
    input  wire [4:0] req,
    output wire [4:0] grant
);
    wire req_a;
    wire req_b;
    wire local_a0;
    wire local_a1;
    wire local_b0;
    wire local_b1;
    wire arbo_a0;
    wire arbo_a1;
    wire arbo_b0;
    wire arbo_b1;
    wire masked_a0;
    wire masked_a1;
    wire masked_b0;
    wire masked_b1;
    wire root_a;
    wire root_b;
    wire root_p;
    wire deadlock;
    wire unused_x_a;
    wire unused_x_b;
    wire unused_x_p;
    wire unused_y_a;
    wire unused_y_b;
    wire unused_y_p;

    TAC2 tac_a(
        .reset(reset),
        .req0(req[0]), .req1(req[1]), .root_grant(root_a),
        .req_up(req_a), .grant0(local_a0), .grant1(local_a1),
        .arbo0(arbo_a0), .arbo1(arbo_a1),
        .result_masked0(masked_a0), .result_masked1(masked_a1)
    );
    TAC2 tac_b(
        .reset(reset),
        .req0(req[2]), .req1(req[3]), .root_grant(root_b),
        .req_up(req_b), .grant0(local_b0), .grant1(local_b1),
        .arbo0(arbo_b0), .arbo1(arbo_b1),
        .result_masked0(masked_b0), .result_masked1(masked_b1)
    );
    Mutex3Grant root(
        .req_a(req_a), .req_b(req_b), .req_p(req[4]),
        .grant_a(root_a), .grant_b(root_b), .grant_p(root_p)
    );

    assign grant[0] = local_a0;
    assign grant[1] = local_a1;
    assign grant[2] = local_b0;
    assign grant[3] = local_b1;
    assign grant[4] = root_p & req[4];
endmodule
