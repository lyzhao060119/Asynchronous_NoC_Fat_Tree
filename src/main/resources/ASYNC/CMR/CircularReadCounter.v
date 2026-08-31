`timescale 1ns / 1ps

// Transition Fig. 6 read counter for the four-control-block ring.
// It follows the physical 0 -> 1 -> 2 -> 3 -> 0 order; phase conversion is
// supplied separately by the EmptyNext Fig. 6 ring.
module CircularReadCounter (
    input wire reset,
    input wire Reqout,
    input wire Ackin,
    output wire [3:0] ReadPointer
);
    wire HandshakeComplete = ~(Reqout ^ Ackin);
    reg [3:0] ReadPointerState;
    assign ReadPointer = ReadPointerState;

    always @(posedge HandshakeComplete or posedge reset) begin
        if (reset)
            ReadPointerState <= 4'b0001;
        else begin
            case (ReadPointerState)
                4'b0001: ReadPointerState <= 4'b0010;
                4'b0010: ReadPointerState <= 4'b0100;
                4'b0100: ReadPointerState <= 4'b1000;
                default: ReadPointerState <= 4'b0001;
            endcase
        end
    end
endmodule
