`timescale 1ns / 1ps

// Fig. 6 RouteSel bit: RouteSel[i] = Mat[i] & BundlingSignal.
// Each multicast bit is an identical T28 AND2 so DC cannot fold the
// quadtree decode cone into a shared AOI/OA stack and invent bit skew.
module RouteSelAnd2 (
    input  wire A,
    input  wire B,
    output wire Z
);
`ifdef ASIC_T28
    (* dont_touch = "true" *)
    AN2D0BWP12T30P140 g (
        .A1(A),
        .A2(B),
        .Z(Z)
    );
`else
    assign Z = A & B;
`endif
endmodule
