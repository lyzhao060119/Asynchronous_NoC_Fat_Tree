`timescale 1ns / 1ps

// Continuous paper Fig. 7 Write Control Unit for one CMR storage cell.
module WriteControlUnit #(
    parameter INITIAL_PHASE = 1'b0
) (
    input  wire       reset,
    input  wire       Reqin,
    input  wire       WritePointer,
    input  wire       Tail,
    input  wire [3:0] CellEmpty,
    output wire       Ackout,
    output wire       CellFull
);
    // Fig. 7 D latch: the selected cell captures the input request phase.
    PhaseResetDLatch #(.INITIAL_PHASE(INITIAL_PHASE)) CellFullLatch (
        .reset(reset),
        .en(WritePointer),
        .d(Reqin),
        .q(CellFull)
    );

    // A read interface has emptied this cell when its phase has caught up
    // with CellFull.  The Tail may acknowledge only after all four match.
    wire [3:0] CellEmptyMatched = ~(CellEmpty ^ {4{CellFull}});
    wire AllCellEmpty = &CellEmptyMatched;
    wire TailAck;

    Toggle #(.RESET_VALUE(INITIAL_PHASE)) TailCompletionToggle (
        .reset(reset),
        .En(AllCellEmpty),
        .Q(TailAck)
    );

    // Non-Tail flits acknowledge immediately from CellFull.  Tail selects
    // the delayed phase returned by the all-read completion Toggle.
    assign Ackout = Tail ? TailAck : CellFull;
endmodule
