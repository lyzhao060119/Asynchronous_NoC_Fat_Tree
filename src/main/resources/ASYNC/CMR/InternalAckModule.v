`timescale 1ns / 1ps

// Fig. 6 Internal Ack Module. Concurrent RouteSel assertions constitute one
// address transaction and therefore generate one Ack_rc transition.
module InternalAckModule #(
    parameter PORTS = 4
) (
    input  wire             reset,
    input  wire [PORTS-1:0] RouteSel,
    output wire             Ack_rc
);
    wire RouteSelected = |RouteSel;

    Toggle AckToggle (
        .reset(reset),
        .En(RouteSelected),
        .Q(Ack_rc)
    );
endmodule
