`timescale 1ns / 1ps

// Continuous paper Fig. 8 Read Control Unit for one CMR storage cell.
module ReadControlUnit #(
    parameter INITIAL_PHASE = 1'b0
) (
    input  wire reset,
    input  wire CellFull,
    input  wire ReadPointer,
    input  wire AckX,
    output wire Req,
    output wire CellEmpty
);
    // Upper Fig. 8 D latch: a selected slot forwards its CellFull phase.
    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) ReqLatch (
        .reset(reset),
        .en(ReadPointer),
        .d(CellFull),
        .q(Req)
    );

    // Lower Fig. 8 D latch remains open while Req and CellEmpty differ.
    // AckX catches CellEmpty up to Req and thereby closes the latch.
    wire CellEmptyEnable = Req ^ CellEmpty;
    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) CellEmptyLatch (
        .reset(reset),
        .en(CellEmptyEnable),
        .d(AckX),
        .q(CellEmpty)
    );
endmodule
