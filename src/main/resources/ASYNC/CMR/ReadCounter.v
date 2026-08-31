`timescale 1ns / 1ps

// Continuous paper Fig. 8 five-slot one-hot Read Counter.  ReqX starts a
// two-phase read transaction and AckX completes it; advance only on the
// unequal-to-equal handshake completion edge.  This cold-start adaptation
// begins at cell 0 so it matches the existing Write Counter.
module ReadCounter #(
    parameter DEPTH = 5
) (
    input  wire             reset,
    input  wire             ReqX,
    input  wire             AckX,
    output wire [DEPTH-1:0] ReadPointer
);
    wire HandshakeComplete = ~(ReqX ^ AckX);
    reg [DEPTH-1:0] ReadPointerState;

    assign ReadPointer = ReadPointerState;

    always @(posedge HandshakeComplete or posedge reset) begin
        if (reset)
            ReadPointerState <= {{DEPTH-1{1'b0}}, 1'b1};
        else
            ReadPointerState <= {ReadPointerState[DEPTH-2:0], ReadPointerState[DEPTH-1]};
    end
endmodule
