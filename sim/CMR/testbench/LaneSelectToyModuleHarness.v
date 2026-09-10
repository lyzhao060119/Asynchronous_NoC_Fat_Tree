`timescale 1ns/1ps

module LaneSelectToyModuleHarness (
    input wire reset,
    input wire [3:0] LaneIsEmpty,
    input wire PPE,
    output wire [3:0] LaneSelect
);
    LaneSelectToyModule dut (
        .reset(reset), .LaneIsEmpty(LaneIsEmpty), .PPE(PPE),
        .LaneSelect(LaneSelect)
    );
endmodule
