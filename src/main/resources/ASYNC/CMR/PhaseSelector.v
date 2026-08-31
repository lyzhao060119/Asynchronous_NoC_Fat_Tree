`timescale 1ns / 1ps

// Fig. 6 Phase Selector.  The paper drives Toggle from the pending window
// phEn = !Head & (Reqin ^ Ackout), not from handshake completion.
module PhaseSelector (
    input  wire reset,
    input  wire complete,
    input  wire Reqin,
    input  wire Head,
    output wire Req_pc
);
    wire n_head;
    wire phEn;
    wire phase;

    // The Phase Selector observes the non-inverted request/ack phase event;
    // HeadPredictor separately receives the inverted completion phase.
    // phEn = !Head & (Reqin ^ Ackout).
    Toggle PhaseToggle (
        .reset(reset),
        .En(phEn),
        .Q(phase)
    );

`ifdef ASIC_T28
    // Keep the phase-event cone fully mapped at the async module boundary;
    // DC otherwise retains the small boolean cone as GTECH under preserved
    // hierarchy.  MUX2ND's inverted output implements Reqin ^ phase.
    wire n_phase;
    INVD0BWP12T30P140 HeadInv (.I(Head), .ZN(n_head));
    AN2D0BWP12T30P140 PhaseEnableAnd (
        .A1(n_head), .A2(complete), .Z(phEn)
    );
    INVD0BWP12T30P140 PhaseInv (.I(phase), .ZN(n_phase));
    MUX2ND0BWP12T30P140 PhaseXor (
        .I0(n_phase), .I1(phase), .S(Reqin), .ZN(Req_pc)
    );
`else
    assign n_head = ~Head;
    assign phEn = n_head & complete;
    assign Req_pc = Reqin ^ phase;
`endif
endmodule
