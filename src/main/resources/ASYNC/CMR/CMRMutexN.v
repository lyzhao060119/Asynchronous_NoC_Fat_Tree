`timescale 1ns / 1ps

// CMR-private baseline 2x1 TAC (ASYNC 2015 Fig. 1). Arbo and result-mask
// signals are internal implementation nodes, not protocol outputs.
module CMRTAC2(
    input wire reset, input wire req0, input wire req1, input wire root_grant,
    output wire req_up, output wire grant0, output wire grant1
);
    wire arbo0, arbo1, result_masked0, result_masked1;
    Mutex2 local_mutex(.req0(req0), .req1(req1), .gnt0(arbo0), .gnt1(arbo1));
    assign result_masked0 = arbo0 & ~grant1;
    assign result_masked1 = arbo1 & ~grant0;
    assign req_up = (req0 & ~grant1) | (req1 & ~grant0);
    MullerC2 grant_join0(.reset(reset), .A(result_masked0), .B(root_grant), .Z(grant0));
    MullerC2 grant_join1(.reset(reset), .A(result_masked1), .B(root_grant), .Z(grant1));
endmodule

// Exact-width baseline-TAC subtrees. Each subtree propagates one eager request
// upward and receives one grant from its parent; no inactive leaves are added.
module CMRTACSub2(input wire reset, input wire [1:0] req,
                  input wire root_grant, output wire req_up,
                  output wire [1:0] grant);
    CMRTAC2 n(.reset(reset), .req0(req[0]), .req1(req[1]),
           .root_grant(root_grant), .req_up(req_up),
           .grant0(grant[0]), .grant1(grant[1]));
endmodule

module CMRTACSub3(input wire reset, input wire [2:0] req,
                  input wire root_grant, output wire req_up,
                  output wire [2:0] grant);
    wire right_req, left_grant, right_grant;
    CMRTACSub2 right(.reset(reset), .req(req[2:1]),
        .root_grant(right_grant), .req_up(right_req), .grant(grant[2:1]));
    CMRTAC2 n(.reset(reset), .req0(req[0]), .req1(right_req),
        .root_grant(root_grant), .req_up(req_up),
        .grant0(left_grant), .grant1(right_grant));
    assign grant[0] = left_grant;
endmodule

module CMRTACSub4(input wire reset, input wire [3:0] req,
                  input wire root_grant, output wire req_up,
                  output wire [3:0] grant);
    wire left_req, right_req, left_grant, right_grant;
    CMRTACSub2 left(.reset(reset), .req(req[1:0]),
        .root_grant(left_grant), .req_up(left_req), .grant(grant[1:0]));
    CMRTACSub2 right(.reset(reset), .req(req[3:2]),
        .root_grant(right_grant), .req_up(right_req), .grant(grant[3:2]));
    CMRTAC2 n(.reset(reset), .req0(left_req), .req1(right_req),
        .root_grant(root_grant), .req_up(req_up),
        .grant0(left_grant), .grant1(right_grant));
endmodule

module CMRTACSub5(input wire reset, input wire [4:0] req,
                  input wire root_grant, output wire req_up,
                  output wire [4:0] grant);
    wire left_req, right_req, left_grant, right_grant;
    CMRTACSub2 left(.reset(reset), .req(req[1:0]),
        .root_grant(left_grant), .req_up(left_req), .grant(grant[1:0]));
    CMRTACSub3 right(.reset(reset), .req(req[4:2]),
        .root_grant(right_grant), .req_up(right_req), .grant(grant[4:2]));
    CMRTAC2 n(.reset(reset), .req0(left_req), .req1(right_req),
        .root_grant(root_grant), .req_up(req_up),
        .grant0(left_grant), .grant1(right_grant));
endmodule

module CMRTACSub8(input wire reset, input wire [7:0] req,
                  input wire root_grant, output wire req_up,
                  output wire [7:0] grant);
    wire left_req, right_req, left_grant, right_grant;
    CMRTACSub4 left(.reset(reset), .req(req[3:0]),
        .root_grant(left_grant), .req_up(left_req), .grant(grant[3:0]));
    CMRTACSub4 right(.reset(reset), .req(req[7:4]),
        .root_grant(right_grant), .req_up(right_req), .grant(grant[7:4]));
    CMRTAC2 n(.reset(reset), .req0(left_req), .req1(right_req),
        .root_grant(root_grant), .req_up(req_up),
        .grant0(left_grant), .grant1(right_grant));
endmodule

module CMRTACSub10(input wire reset, input wire [9:0] req,
                   input wire root_grant, output wire req_up,
                   output wire [9:0] grant);
    wire left_req, right_req, left_grant, right_grant;
    CMRTACSub5 left(.reset(reset), .req(req[4:0]),
        .root_grant(left_grant), .req_up(left_req), .grant(grant[4:0]));
    CMRTACSub5 right(.reset(reset), .req(req[9:5]),
        .root_grant(right_grant), .req_up(right_req), .grant(grant[9:5]));
    CMRTAC2 n(.reset(reset), .req0(left_req), .req1(right_req),
        .root_grant(root_grant), .req_up(req_up),
        .grant0(left_grant), .grant1(right_grant));
endmodule

module CMRMutexN #(parameter WIDTH = 5) (
    input wire reset,
    input wire [WIDTH-1:0] req,
    output wire [WIDTH-1:0] grant
);
    generate
        if (WIDTH == 1) begin : w1
            assign grant[0] = req[0];
        end else if (WIDTH == 2) begin : w2
            Mutex2 root(.req0(req[0]), .req1(req[1]),
                        .gnt0(grant[0]), .gnt1(grant[1]));
        end else if (WIDTH == 4) begin : w4
            Mutex4 root(.req0(req[0]), .req1(req[1]),
                        .req2(req[2]), .req3(req[3]),
                        .gnt0(grant[0]), .gnt1(grant[1]),
                        .gnt2(grant[2]), .gnt3(grant[3]));
        end else if (WIDTH == 5) begin : w5
            CMRFlatArbiter5 flat(.reset(reset), .req(req), .grant(grant));
        end else if (WIDTH == 8) begin : w8
            CMRFlatArbiter8 flat(.reset(reset), .req(req), .grant(grant));
        end else if (WIDTH == 10) begin : w10
            CMRFlatArbiter10 flat(.reset(reset), .req(req), .grant(grant));
        end else if (WIDTH == 16) begin : w16
            wire lreq, rreq, lg, rg;
            CMRTACSub8 l(.reset(reset), .req(req[7:0]),
                .root_grant(lg), .req_up(lreq), .grant(grant[7:0]));
            CMRTACSub8 r(.reset(reset), .req(req[15:8]),
                .root_grant(rg), .req_up(rreq), .grant(grant[15:8]));
            Mutex2 root(.req0(lreq), .req1(rreq), .gnt0(lg), .gnt1(rg));
        end else if (WIDTH == 20) begin : w20
            wire lreq, rreq, lg, rg;
            CMRTACSub10 l(.reset(reset), .req(req[9:0]),
                .root_grant(lg), .req_up(lreq), .grant(grant[9:0]));
            CMRTACSub10 r(.reset(reset), .req(req[19:10]),
                .root_grant(rg), .req_up(rreq), .grant(grant[19:10]));
            Mutex2 root(.req0(lreq), .req1(rreq), .gnt0(lg), .gnt1(rg));
        end else begin : unsupported
            assign grant = {WIDTH{1'b0}};
        end
    endgenerate
endmodule
