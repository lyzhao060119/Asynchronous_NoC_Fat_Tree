`timescale 1ns / 1ps

// Continuous paper Fig. 8 Ack Generator.  Equality is restored either by a
// correct-path Ackin or by the Phase Selector's second speculative toggle.
module ReadAckGenerator (
    input  wire reset,
    input  wire Reqout,
    input  wire Ackin,
    output wire AckX
);
    wire Completion = ~(Reqout ^ Ackin);

    Toggle CompletionToggle (
        .reset(reset),
        .En(Completion),
        .Q(AckX)
    );
endmodule
