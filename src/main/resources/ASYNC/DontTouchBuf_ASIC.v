`timescale 1ns / 1ps

// One TSMC 28nm BUFFD0.  Protect with set_dont_touch in DC.
module DontTouchBuf (
    input  wire I,
    output wire Z
);

    BUFFD0BWP12T30P140 D0 (
        .I(I),
        .Z(Z)
    );

endmodule
