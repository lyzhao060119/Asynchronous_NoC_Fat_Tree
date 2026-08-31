`timescale 1ns / 1ps

// Continuous paper Fig. 8 Phase Selector.  A speculative request on an
// incorrect local path is toggled back only after another path is enabled.
module ReadPhaseSelector #(
    parameter LOCAL_BRANCH = 0
) (
    input  wire       reset,
    input  wire       ReqX,
    input  wire       Ackin,
    input  wire [3:0] PathEnabled,
    output wire       Reqout
);
    localparam [3:0] LOCAL_MASK = (4'b0001 << LOCAL_BRANCH);
    wire PathEnabledLocal = |(PathEnabled & LOCAL_MASK);
    wire OtherPathEnabled = |(PathEnabled & ~LOCAL_MASK);
    wire WrongPath = ~PathEnabledLocal & OtherPathEnabled;
    wire CancelEnable = WrongPath & (Reqout ^ Ackin);
    wire CorrectionPhase;

    Toggle CorrectionToggle (
        .reset(reset),
        .En(CancelEnable),
        .Q(CorrectionPhase)
    );

    assign Reqout = ReqX ^ CorrectionPhase;
endmodule
