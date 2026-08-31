`timescale 1ns / 1ps

// Paper Toggle: one output transition for every rising En event.
module Toggle #(
    parameter RESET_VALUE = 1'b0
) (
    input  wire reset,
    input  wire En,
    output wire Q
);
`ifdef ASIC_T28
    // Keep the Fig. 6/7/8 Toggle interface while mapping its state directly
    // to a T28 flip-flop: D = !Q and CP = En.  RESET_VALUE selects the
    // matching single asynchronous reset port; no GTECH/SEQGEN inference is
    // left for DC.
    wire n_reset;
    wire n_state;
    INVD0BWP12T30P140 ResetInv (.I(reset), .ZN(n_reset));
    INVD0BWP12T30P140 StateInv (.I(Q), .ZN(n_state));
    generate
      if (RESET_VALUE == 1'b0) begin : ClearResetToggle
        DFCNQD1BWP12T30P140 state_reg (
            .D(n_state), .CP(En), .CDN(n_reset), .Q(Q)
        );
      end else begin : SetResetToggle
        DFSNQD1BWP12T30P140 state_reg (
            .D(n_state), .CP(En), .SDN(n_reset), .Q(Q)
        );
      end
    endgenerate
`else
    reg state;
    assign Q = state;

    always @(posedge En or posedge reset) begin
        if (reset)
            state <= RESET_VALUE;
        else
            state <= ~state;
    end
`endif
endmodule
