`timescale 1ns / 1ps

// Small standalone structures for FPGA characterization of async primitives.
// They are not instantiated by the NoC. Use them in a separate calibration
// project with ASYNC_PRIMITIVES=fpga resources and the async primitive XDC.

module DelayElementRingOscillator
#(parameter DelayValue = 16)
(
    input  wire enable,
    output wire ro_out
);
    wire delayed;
    wire feedback;

    assign feedback = enable ? ~delayed : 1'b0;

    DelayElement #(.DelayValue(DelayValue)) delay_chain (
        .I(feedback),
        .Z(delayed)
    );

    assign ro_out = delayed;
endmodule

module Mutex2ConflictProbe(
    input  wire enable,
    output wire gnt0,
    output wire gnt1
);
    wire req0 = enable;
    wire req1 = enable;

    Mutex2 mutex (
        .req0(req0),
        .req1(req1),
        .gnt0(gnt0),
        .gnt1(gnt1)
    );
endmodule
