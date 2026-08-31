`timescale 1ns / 1ps

// Continuous paper Fig. 8 five-input XOR Request Generator.
module ReadRequestGenerator (
    input  wire [4:0] Req,
    output wire       ReqX
);
    assign ReqX = ^Req;
endmodule
