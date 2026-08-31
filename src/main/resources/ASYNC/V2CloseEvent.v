`timescale 1ns / 1ps

// The Ack/TP sampling event must be downstream of the actual V2 latch-enable
// pin.  Keep this inverter as an explicit implementation boundary so DC may
// not take the pre-enable mismatch node as the DFF clock.
module V2CloseEvent (
    input  wire latch_enable,
    output wire close_clock
);
`ifdef ASIC_T28
    INVD0BWP12T30P140 close_event_inv (
        .I(latch_enable), .ZN(close_clock)
    );
`else
    assign close_clock = ~latch_enable;
`endif
endmodule
