`timescale 1ns / 1ps

// Transition paper Fig. 6/7 circular FIFO.
//
// The paper topology has four physical register/control-block slots. The
// blocks are connected through the Fig. 6 Gray-phase successor map.
module CircularFIFO #(
    parameter DEPTH = 4,
    parameter FLIT_LENGTH = 28
) (
    input  wire                     reset,
    input  wire                     Reqin,
    input  wire                     Ackin,
    input  wire [FLIT_LENGTH-1:0]   Data_in,
    output wire                     Ackout,
    output wire                     Reqout,
    output wire [FLIT_LENGTH-1:0]   Data_out,
    // Read-only observability ports for unit-level post-synthesis SDF.
    // They do not feed any FIFO control or data path.
    output wire [3:0]               DebugWritePointer,
    output wire [3:0]               DebugReadPointer,
    output wire [3:0]               DebugFull,
    output wire [3:0]               DebugEmpty,
    output wire [3:0]               DebugCellReq,
    output wire [3:0]               DebugEn
);
    // slot0..3 = 0,0,1,1. Full, Empty and Req reset to the same phases.
    localparam [3:0] SLOT_PHASE = 4'b1100;

`ifndef SYNTHESIS
    initial begin
        if (DEPTH != 4)
            $error("CircularFIFO implements only the Transition Fig. 6 four-slot ring");
    end
`endif

    wire [3:0] WritePointer;
    wire [3:0] ReadCounterPtr;
    wire [3:0] ReadPointer;
    wire [3:0] Full;
    wire [3:0] Empty;
    wire [3:0] CellReq;
    wire [3:0] En;
    wire [FLIT_LENGTH-1:0] SlotData [0:3];

    // Fig. 6 phase-select successor map: {next(0), next(1), next(2),
    // next(3)} = {1, 3, 0, 2}. Explicit wires retain paper signal names.
    wire [3:0] FullNext;
    wire [3:0] EmptyNext;
    assign FullNext[0] = Full[1];
    assign FullNext[1] = Full[3];
    assign FullNext[2] = Full[0];
    assign FullNext[3] = Full[2];
    assign EmptyNext[0] = Empty[1];
    assign EmptyNext[1] = Empty[3];
    assign EmptyNext[2] = Empty[0];
    assign EmptyNext[3] = Empty[2];

    CircularWriteCounter write_counter (
        .reset(reset),
        .Reqin(Reqin),
        .Ackout(Ackout),
        .WritePointer(WritePointer)
    );
    CircularReadCounter read_counter (
        .reset(reset),
        .Reqout(Reqout),
        .Ackin(Ackin),
        .ReadPointer(ReadCounterPtr)
    );

    // Fig. 6: after Reqout starts a transfer, the selected RCB request latch
    // is closed until Ackin completes it; the counter token advances then.
    // Data_out keeps using the raw counter token throughout the transfer.
    assign ReadPointer = ReadCounterPtr & {4{~(Reqout ^ Ackin)}};

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : slot
            WriteControlBlock #(.INITIAL_PHASE(SLOT_PHASE[i])) wcb (
                .reset(reset),
                .FullNext(FullNext[i]),
                .Empty(Empty[i]),
                .WritePointer(WritePointer[i]),
                .Reqin(Reqin),
                .Full(Full[i]),
                .En(En[i]),
                .Ackout()
            );
            ReadControlBlock #(.INITIAL_PHASE(SLOT_PHASE[i])) rcb (
                .reset(reset),
                .Full(Full[i]),
                .Empty(Empty[i]),
                .EmptyNext(EmptyNext[i]),
                .ReadPointer(ReadPointer[i]),
                .Ackin(Ackin),
                .Req(CellReq[i]),
                .Empty_out(Empty[i])
            );
            DLatchBank #(.WIDTH(FLIT_LENGTH)) data_reg (
                .reset(reset), .en(En[i]), .d(Data_in), .q(SlotData[i])
            );
        end
    endgenerate

    assign Ackout = ^Full;
    assign Reqout = ^CellReq;
    assign DebugWritePointer = WritePointer;
    assign DebugReadPointer = ReadCounterPtr;
    assign DebugFull = Full;
    assign DebugEmpty = Empty;
    assign DebugCellReq = CellReq;
    assign DebugEn = En;

    reg [FLIT_LENGTH-1:0] data_out_reg;
    integer d;
    always @(*) begin
        data_out_reg = {FLIT_LENGTH{1'b0}};
        for (d = 0; d < 4; d = d + 1)
            if (ReadCounterPtr[d])
                data_out_reg = SlotData[d];
    end
    assign Data_out = data_out_reg;
endmodule
