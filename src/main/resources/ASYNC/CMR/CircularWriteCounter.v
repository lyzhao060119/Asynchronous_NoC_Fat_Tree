`timescale 1ns / 1ps

// Transition Fig. 6 write counter for the four-control-block ring.
// The one-hot physical pointer visits 0 -> 1 -> 2 -> 3 -> 0.  Fig. 6's
// Gray-phase relation is carried by the FullNext cross-connection, not by a
// Gray permutation of the physical storage pointer.
module CircularWriteCounter (
    input wire reset,
    input wire Reqin,
    input wire Ackout,
    output wire [3:0] WritePointer
);
    wire HandshakeComplete = ~(Reqin ^ Ackout);
    reg [3:0] WritePointerState;
    assign WritePointer = WritePointerState;

    always @(posedge HandshakeComplete or posedge reset) begin
        if (reset)
            WritePointerState <= 4'b0001;
        else begin
            case (WritePointerState)
                4'b0001: WritePointerState <= 4'b0010;
                4'b0010: WritePointerState <= 4'b0100;
                4'b0100: WritePointerState <= 4'b1000;
                default: WritePointerState <= 4'b0001;
            endcase
        end
    end
endmodule
