`timescale 1ns / 1ps

module DontTouchBuf (
    input  wire I,
    output wire Z
);

    (* DONT_TOUCH = "TRUE" *)
    LUT1 #(.INIT(2'b10)) D0 (
        .O(Z),
        .I0(I)
    );

endmodule
