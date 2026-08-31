`timescale 1ns / 1ps

// Fig. 6 Head Predictor. En starts open, closes after the Head Ackout, and
// reopens after the Tail Ackout.
module HeadPredictor (
    input  wire reset,
    input  wire complete,
    input  wire Tail,
    output wire En
);
`ifdef ASIC_T28
    wire n_reset;
    INVD0BWP12T30P140 ResetInv (.I(reset), .ZN(n_reset));
    DFSNQD1BWP12T30P140 en_state_reg (
        .D(Tail), .CP(complete), .SDN(n_reset), .Q(En)
    );
`else
    reg en_state;
    assign En = en_state;
    always @(posedge complete or posedge reset) begin
        if (reset)
            en_state <= 1'b1;
        else
            en_state <= Tail;
    end
`endif
endmodule
