`timescale 1ns / 1ps

module SRLatch (
    input  wire reset,
    input  wire S,
    input  wire R,
    output wire Q
);
`ifdef ASIC_T28
    // A constant-D, single-clear latch preserves reset/R-dominant SR state
    // without the double-asynchronous-control crossover of LHCSNDQD.
    wire Clear = reset | R;
    wire CDN = ~Clear;

    LHCNDQD1BWP12T30P140 sr_cell (
        .D(1'b1),
        .E(S),
        .CDN(CDN),
        .Q(Q)
    );
`else
    reg state;
    assign Q = state;

    always @(*) begin
        if (reset)
            state = 1'b0;
        else if (R)
            state = 1'b0;
        else if (S)
            state = 1'b1;
    end
`endif
endmodule

// Fig. 6 OPM Selector: RouteSel sets a packet-lifetime path; the matching
// TailPassed independently releases that path.  After TailPassed, ignore
// RouteSel until it has fallen so a still-high or glitching RouteSel cannot
// re-open the wormhole and replay a body that is still sitting in the buffer.
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
            wire BlockSet;
            wire SetQual = RouteSel[port] & ~BlockSet;

            SRLatch BlockLatch (
                .reset(reset),
                .S(TailPassed[port]),
                .R(~RouteSel[port]),
                .Q(BlockSet)
            );
            SRLatch PathLatch (
                .reset(reset),
                .S(SetQual),
                .R(TailPassed[port]),
                .Q(PathEnabled[port])
            );
        end
    endgenerate
endmodule
