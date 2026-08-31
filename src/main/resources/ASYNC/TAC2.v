`timescale 1ns / 1ps

// IEEE ASYNC 2015 Fig. 1(a), 2x1 tree-arbiter cell (TAC).
// The two C elements synchronize local mutex acquisition (ResultMasked) with
// the returned root grant.  Grant0/Grant1 also form the root/result masking
// window exactly as shown by the two feedback paths in the figure.
module TAC2(
    input  wire reset,
    input  wire req0,
    input  wire req1,
    input  wire root_grant,
    output wire req_up,
    output wire grant0,
    output wire grant1,
    output wire arbo0,
    output wire arbo1,
    output wire result_masked0,
    output wire result_masked1
);
    Mutex2 local_mutex(
        .req0(req0), .req1(req1), .gnt0(arbo0), .gnt1(arbo1)
    );

    // Result masking and request propagation/root masking from Fig. 1(a).
    // The current final winner masks the opposing local result and its eager
    // contribution to ReqUp, while its own request keeps the path asserted.
    assign result_masked0 = arbo0 & ~grant1;
    assign result_masked1 = arbo1 & ~grant0;
    assign req_up = (req0 & ~grant1) | (req1 & ~grant0);

    // The only C elements in this 2x1 TAC.
    MullerC2 grant_join0(
        .reset(reset), .A(result_masked0), .B(root_grant), .Z(grant0)
    );
    MullerC2 grant_join1(
        .reset(reset), .A(result_masked1), .B(root_grant), .Z(grant1)
    );
endmodule
