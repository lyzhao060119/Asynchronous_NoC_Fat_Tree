`timescale 1ns / 1ps

// Functional simulation model only. The # delay gives deterministic event
// ordering in RTL simulation and is not a physical timing model.
module DelayElement
#(
    parameter DelayValue = 10,
    parameter DelayUnitPs = 150
)
(
    input  wire I,
    output wire Z
);

    assign #(0.2*DelayValue) Z = I;

endmodule
