`timescale 1ns / 1ps

// Physical acknowledgement interval for a structural NoC16 sink.  A source
// compile define selects one *direct* library cell; do not wrap this in the
// generic DelayElement because DC retains unmapped generic cells in this
// signoff hierarchy.
module AsyncEndpointAckDelay (
    input  wire I,
    output wire Z
);
`ifdef ASIC_T28
`ifdef ASYNC_ENDPOINT_ACK_DELAY_075
    DEL075D1BWP12T30P140 ack_delay_cell (.I(I), .Z(Z));
`elsif ASYNC_ENDPOINT_ACK_DELAY_100
    DEL100D1BWP12T30P140 ack_delay_cell (.I(I), .Z(Z));
`elsif ASYNC_ENDPOINT_ACK_DELAY_150
    DEL150D1BWP12T30P140 ack_delay_cell (.I(I), .Z(Z));
`elsif ASYNC_ENDPOINT_ACK_DELAY_250
    DEL250D1BWP12T30P140 ack_delay_cell (.I(I), .Z(Z));
`else
    DEL050D1BWP12T30P140 ack_delay_cell (.I(I), .Z(Z));
`endif
`else
`ifdef ASYNC_ENDPOINT_ACK_DELAY_075
    assign #(0.075) Z = I;
`elsif ASYNC_ENDPOINT_ACK_DELAY_100
    assign #(0.100) Z = I;
`elsif ASYNC_ENDPOINT_ACK_DELAY_150
    assign #(0.150) Z = I;
`elsif ASYNC_ENDPOINT_ACK_DELAY_250
    assign #(0.250) Z = I;
`else
    assign #(0.050) Z = I;
`endif
`endif
endmodule
