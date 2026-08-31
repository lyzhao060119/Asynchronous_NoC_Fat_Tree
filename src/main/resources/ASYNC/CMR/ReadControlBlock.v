`timescale 1ns / 1ps

// Transition paper Fig. 7(b) Read Control Block for one circular FIFO slot.
// Fig. 7(b) uses Empty_(i+1) as the acknowledge phase selector.
module ReadControlBlock #(
    parameter INITIAL_PHASE = 1'b0
) (
    input  wire reset,
    input  wire Full,           // Full_i from the Write Control Block
    input  wire Empty,          // current Empty_i for this slot
    input  wire EmptyNext,      // Empty_(i+1), supplied by Fig. 6 ring wiring
    input  wire ReadPointer,    // one-hot select for this slot (frozen while pending)
    input  wire Ackin,          // global two-phase acknowledge from downstream
    output wire Req,            // per-slot contribution to global Reqout
    output wire Empty_out       // updated Empty_i for this slot
);

    // Fig. 7(b): ReadPointer_i directly controls the request latch.
    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) ReqLatch (
        .reset(reset),
        .en(ReadPointer),
        .d(Full),
        .q(Req)
    );

    // Acknowledge routing: the latch is transparent while the read is pending
    // (Req and Empty differ), routing downstream AckIN back to Empty_i.  When
    // AckIN finally matches Req, Empty_i catches up and the latch closes.
    wire EmptyEnable = Req ^ Empty;

    // Fig. 7(b) Phase Select XOR before the acknowledge latch.
    wire MatchedAck = Ackin ^ EmptyNext;

    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) EmptyLatch (
        .reset(reset),
        .en(EmptyEnable),
        .d(MatchedAck),
        .q(Empty_out)
    );

endmodule
