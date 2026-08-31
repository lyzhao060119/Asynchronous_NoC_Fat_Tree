`timescale 1ns / 1ps

// ASYNC 2015 Fig. 5 uses a packet of locally arbitrated requesters which
// forwards one eager ReqUp to a simple root.  These cells intentionally expose
// only the TAC protocol (ReqUp/RootGrant/Grant[]); Arbo, enables, and masks
// remain local implementation state.

// Fig. 2 three-way arbitration core.  Three pairwise mutexes form the A-B,
// B-C and C-A ring.  A simultaneous cyclic partial acquisition is broken by
// suppressing requester A, exactly the paper's deadlock-detector policy.
module CMRMutex3Core(
    input  wire       reset,
    input  wire [2:0] req,
    output wire [2:0] arbo
);
    wire ab0, ab1, bc1, bc2, ca2, ca0;
    wire cyclic_partial;
    wire req0_effective;

    // A valid complete winner holds both mutexes adjacent to that requester.
    assign arbo[0] = ab0 & ca0;
    assign arbo[1] = ab1 & bc1;
    assign arbo[2] = bc2 & ca2;

    // The Fig. 2 detector kills ReqA only when all three requests are present
    // yet no requester owns its two adjacent mutexes.  reset participates so
    // that no stale correction survives reset.
    assign cyclic_partial = !reset && (&req) && !(|arbo);
    assign req0_effective = req[0] & !cyclic_partial;

    Mutex2 mutex_ab(.req0(req0_effective), .req1(req[1]),
                    .gnt0(ab0), .gnt1(ab1));
    Mutex2 mutex_bc(.req0(req[1]), .req1(req[2]),
                    .gnt0(bc1), .gnt1(bc2));
    Mutex2 mutex_ca(.req0(req[2]), .req1(req0_effective),
                    .gnt0(ca2), .gnt1(ca0));
endmodule

// Paper Fig. 5(a) 3x1 TAC.  The Fig. 2 grant synchronizer is intentionally
// outside the arbitration core: these Muller-C joins are its TAC-level grant
// synchronization with the returned root permission.
module CMRTAC3(
    input  wire       reset,
    input  wire [2:0] req,
    input  wire       root_grant,
    output wire       req_up,
    output wire [2:0] grant
);
    wire [2:0] arbo;
    wire [2:0] en;
    wire [2:0] result_masked;

    CMRMutex3Core core(.reset(reset), .req(req), .arbo(arbo));
    assign en[0] = ~(grant[1] | grant[2]);
    assign en[1] = ~(grant[0] | grant[2]);
    assign en[2] = ~(grant[0] | grant[1]);
    assign req_up = |(req & en);
    assign result_masked = arbo & en;
    MullerC2 join0(.reset(reset), .A(result_masked[0]), .B(root_grant), .Z(grant[0]));
    MullerC2 join1(.reset(reset), .A(result_masked[1]), .B(root_grant), .Z(grant[1]));
    MullerC2 join2(.reset(reset), .A(result_masked[2]), .B(root_grant), .Z(grant[2]));
endmodule

// Paper Fig. 5(a) fast 4x1 TAC: the three Mutex2 instances of the baseline
// four-way core resolve left, right, and middle contests in parallel.  The
// macro cell retains one eager forwarding layer and one grant-join layer.
module CMRTAC4(
    input  wire       reset,
    input  wire [3:0] req,
    input  wire       root_grant,
    output wire       req_up,
    output wire [3:0] grant
);
    wire [3:0] arbo;
    wire [3:0] en;
    wire [3:0] result_masked;

    Mutex4 core(.req0(req[0]), .req1(req[1]), .req2(req[2]), .req3(req[3]),
                .gnt0(arbo[0]), .gnt1(arbo[1]),
                .gnt2(arbo[2]), .gnt3(arbo[3]));
    assign en[0] = ~(grant[1] | grant[2] | grant[3]);
    assign en[1] = ~(grant[0] | grant[2] | grant[3]);
    assign en[2] = ~(grant[0] | grant[1] | grant[3]);
    assign en[3] = ~(grant[0] | grant[1] | grant[2]);
    assign req_up = |(req & en);
    assign result_masked = arbo & en;
    MullerC2 join0(.reset(reset), .A(result_masked[0]), .B(root_grant), .Z(grant[0]));
    MullerC2 join1(.reset(reset), .A(result_masked[1]), .B(root_grant), .Z(grant[1]));
    MullerC2 join2(.reset(reset), .A(result_masked[2]), .B(root_grant), .Z(grant[2]));
    MullerC2 join3(.reset(reset), .A(result_masked[3]), .B(root_grant), .Z(grant[3]));
endmodule

// Fig. 3/Fig. 5 macro-level flattened arbiters.  Each client crosses one TAC
// then one simple root mutex, instead of a recursively deep client path.
module CMRFlatArbiter5(input wire reset, input wire [4:0] req,
                       output wire [4:0] grant);
    wire req_left, req_right, root_left, root_right;
    CMRTAC3 left(.reset(reset), .req(req[2:0]), .root_grant(root_left),
                 .req_up(req_left), .grant(grant[2:0]));
    CMRTAC2 right(.reset(reset), .req0(req[3]), .req1(req[4]),
                  .root_grant(root_right), .req_up(req_right),
                  .grant0(grant[3]), .grant1(grant[4]));
    Mutex2 root(.req0(req_left), .req1(req_right),
                .gnt0(root_left), .gnt1(root_right));
endmodule

module CMRFlatArbiter7(input wire reset, input wire [6:0] req,
                       output wire [6:0] grant);
    wire req_left, req_right, root_left, root_right;
    CMRTAC3 left(.reset(reset), .req(req[2:0]), .root_grant(root_left),
                 .req_up(req_left), .grant(grant[2:0]));
    CMRTAC4 right(.reset(reset), .req(req[6:3]), .root_grant(root_right),
                  .req_up(req_right), .grant(grant[6:3]));
    Mutex2 root(.req0(req_left), .req1(req_right),
                .gnt0(root_left), .gnt1(root_right));
endmodule

module CMRFlatArbiter8(input wire reset, input wire [7:0] req,
                       output wire [7:0] grant);
    wire req_left, req_right, root_left, root_right;
    CMRTAC4 left(.reset(reset), .req(req[3:0]), .root_grant(root_left),
                 .req_up(req_left), .grant(grant[3:0]));
    CMRTAC4 right(.reset(reset), .req(req[7:4]), .root_grant(root_right),
                  .req_up(req_right), .grant(grant[7:4]));
    Mutex2 root(.req0(req_left), .req1(req_right),
                .gnt0(root_left), .gnt1(root_right));
endmodule

// 10 = 3 + 3 + 4.  The three leaf TACs execute in parallel and the Fig. 2
// three-way core is used as the single macro root, preserving two arbitration
// layers from any requester to its final grant.
module CMRFlatArbiter10(input wire reset, input wire [9:0] req,
                        output wire [9:0] grant);
    wire req0, req1, req2;
    wire root0, root1, root2;
    CMRTAC3 leaf0(.reset(reset), .req(req[2:0]), .root_grant(root0),
                  .req_up(req0), .grant(grant[2:0]));
    CMRTAC3 leaf1(.reset(reset), .req(req[5:3]), .root_grant(root1),
                  .req_up(req1), .grant(grant[5:3]));
    CMRTAC4 leaf2(.reset(reset), .req(req[9:6]), .root_grant(root2),
                  .req_up(req2), .grant(grant[9:6]));
    CMRMutex3Core root(.reset(reset), .req({req2, req1, req0}),
                       .arbo({root2, root1, root0}));
endmodule
