`timescale 1ns / 1ps

module PathStateDFF (
    input  wire reset,
    input  wire RouteSel,
    input  wire TailPassed,
    output wire Q
);
`ifdef ASIC_T28
    // RouteSel is the local event clock: its rising edge opens the path.
    // TailPassed asynchronously clears the state after the tail is accepted.
    wire clear_n = ~(reset | TailPassed);
    DFCNQD1BWP12T30P140 path_state_reg (
        .D(1'b1),
        .CP(RouteSel),
        .CDN(clear_n),
        .Q(Q)
    );
`else
    reg state;
    assign Q = state;

    always @(posedge RouteSel or posedge TailPassed or posedge reset) begin
        if (reset || TailPassed)
            state <= 1'b0;
        else
            state <= 1'b1;
    end
`endif
endmodule

// Fig. 6 OPM Selector: the rising edge of RouteSel sets a packet-lifetime
// path; TailPassed asynchronously clears it after the tail has been accepted.
module OPMSelector #(
    parameter PORTS = 4
) (
    input  wire             reset,
    input  wire [PORTS-1:0] RouteSel,
    input  wire [PORTS-1:0] TailPassed,
    output wire [PORTS-1:0] PathEnabled
);
    genvar port;
    generate
        for (port = 0; port < PORTS; port = port + 1) begin : selector
            PathStateDFF PathState (
                .reset(reset),
                .RouteSel(RouteSel[port]),
                .TailPassed(TailPassed[port]),
                .Q(PathEnabled[port])
            );
        end
    endgenerate
endmodule
