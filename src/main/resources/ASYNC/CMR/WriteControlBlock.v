`timescale 1ns / 1ps

// Transition paper Fig. 7(a) Write Control Block for one circular FIFO slot.
// Fig. 7(a) uses Full_(i+1) as a phase selector.  It is not an independent
// per-slot request latch: the selected slot captures ReqIN ^ FullNext.
module WriteControlBlock #(
    parameter INITIAL_PHASE = 1'b0
) (
    input  wire reset,
    input  wire FullNext,       // Full_(i+1), supplied by Fig. 6 ring wiring
    input  wire Empty,          // Empty_i from the Read Control Block
    input  wire WritePointer,   // one-hot select for this slot
    input  wire Reqin,          // global two-phase request from upstream
    output wire Full,           // Full_i to the Read Control Block
    output wire En,             // data latch enable, active-high transparent
    output wire Ackout          // per-slot contribution to global Ackout
);

    // Slot is empty when Full_i and Empty_i are at the same logic level.
    wire SlotEmpty = ~(Full ^ Empty);

    // Write is enabled only for the selected empty slot.
    wire WriteEnable = WritePointer & SlotEmpty;

    // Fig. 7(a) Phase Select XOR.
    wire MatchedReq = Reqin ^ FullNext;

    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) FullLatch (
        .reset(reset),
        .en(WriteEnable),
        .d(MatchedReq),
        .q(Full)
    );

    // Data latch uses the same enable as Full: only the selected empty slot
    // is transparent, and both close when the slot becomes full.
    assign En = WriteEnable;

    // Per-slot acknowledge is the captured request phase.
    assign Ackout = Full;

endmodule
