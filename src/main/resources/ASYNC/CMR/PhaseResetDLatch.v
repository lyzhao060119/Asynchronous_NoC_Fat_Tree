`timescale 1ns / 1ps

// Phase-aware resettable D latch used by the alternating Fig. 7/8 storage
// phases.  The ASIC implementation keeps D and E independent and applies the
// requested reset value through the T28 cell's dedicated asynchronous pin.
module PhaseResetDLatch #(
    parameter INITIAL_PHASE = 1'b0
) (
    input  wire reset,
    input  wire en,
    input  wire d,
    output wire q
);
`ifdef ASIC_T28
    wire reset_n = ~reset;
    generate
        if (INITIAL_PHASE == 1'b0) begin : reset_to_zero
            LHCNDQD1BWP12T30P140 latch_cell (
                .D(d),
                .E(en),
                .CDN(reset_n),
                .Q(q)
            );
        end else begin : reset_to_one
            LHSNDQD1BWP12T30P140 latch_cell (
                .D(d),
                .E(en),
                .SDN(reset_n),
                .Q(q)
            );
        end
    endgenerate
`else
    reg state;
    assign q = state;

    always @(*) begin
        if (reset)
            state = INITIAL_PHASE;
        else if (en)
            state = d;
    end
`endif
endmodule
