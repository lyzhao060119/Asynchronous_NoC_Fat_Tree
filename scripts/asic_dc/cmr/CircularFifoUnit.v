`timescale 1ns / 1ps

// Synthesis boundary for the Transition Fig. 6/7 four-slot FIFO.  Keeping
// this wrapper separate lets its SDF be annotated without a NoC hierarchy.
module CircularFifoUnit (
    input  wire        reset,
    input  wire        Reqin,
    input  wire        Ackin,
    input  wire [27:0] Data_in,
    output wire        Ackout,
    output wire        Reqout,
    output wire [27:0] Data_out,
    output wire [3:0]  DebugWritePointer,
    output wire [3:0]  DebugReadPointer,
    output wire [3:0]  DebugFull,
    output wire [3:0]  DebugEmpty,
    output wire [3:0]  DebugCellReq,
    output wire [3:0]  DebugEn
);
    CircularFIFO #(.DEPTH(4), .FLIT_LENGTH(28)) fifo (
        .reset(reset), .Reqin(Reqin), .Ackin(Ackin), .Data_in(Data_in),
        .Ackout(Ackout), .Reqout(Reqout), .Data_out(Data_out),
        .DebugWritePointer(DebugWritePointer), .DebugReadPointer(DebugReadPointer),
        .DebugFull(DebugFull), .DebugEmpty(DebugEmpty), .DebugCellReq(DebugCellReq), .DebugEn(DebugEn)
    );
endmodule
