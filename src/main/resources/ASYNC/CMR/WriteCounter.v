`timescale 1ns / 1ps

// Continuous paper Fig. 7 five-slot one-hot Write Counter.  A request makes
// the two-phase channel unequal; the pointer advances only when Ackout catches
// Reqin and the complete handshake returns to the equal phase.
module WriteCounter #(
    parameter DEPTH = 5
) (
    input  wire             reset,
    input  wire             Reqin,
    input  wire             Ackout,
    output wire [DEPTH-1:0] WritePointer
);
    wire HandshakeComplete = ~(Reqin ^ Ackout);
    reg [DEPTH-1:0] WritePointerState;

    assign WritePointer = WritePointerState;

    always @(posedge HandshakeComplete or posedge reset) begin
        if (reset)
            WritePointerState <= {{DEPTH-1{1'b0}}, 1'b1};
        else
            WritePointerState <= {WritePointerState[DEPTH-2:0], WritePointerState[DEPTH-1]};
    end
endmodule
