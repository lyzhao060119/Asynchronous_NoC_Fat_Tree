`timescale 1ns / 1ps

module MousetrapStage #(
    parameter WIDTH = 1
) (
    input  wire             reset,
    input  wire             ReqIn,
    input  wire [WIDTH-1:0] DataIn,
    output wire             ReqX,
    input  wire             AckX,
    output wire [WIDTH-1:0] DataOut,
    input  wire             PRSReady
);
    wire latch_en;
    wire request_latch_q;
    wire [WIDTH-1:0] latch_q;

    // Mousetrap self-closing enable: while the locally latched request phase
    // matches AckX the stage is transparent. Capturing a new ReqIn phase makes
    // request_latch_q differ from AckX and closes both latches atomically.
    assign latch_en = ~(request_latch_q ^ AckX) & ~PRSReady;
    assign ReqX = request_latch_q;
    assign DataOut = latch_q;

    // Transition Fig. 4 / Ultra Fig. 5(a) Modified Mousetrap V1: request and
    // bundled data are captured by level-sensitive latches under the same
    // enable. ReqX must not be a combinational copy of ReqIn.
    DLatchBank #(.WIDTH(1)) request_latch (
        .reset(reset), .en(latch_en), .d(ReqIn),
        .q(request_latch_q)
    );

    DLatchBank #(.WIDTH(WIDTH)) data_latch (
        .reset(reset), .en(latch_en), .d(DataIn),
        .q(latch_q)
    );
endmodule
