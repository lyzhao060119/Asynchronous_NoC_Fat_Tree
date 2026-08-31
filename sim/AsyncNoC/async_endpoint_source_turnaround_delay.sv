`timescale 1ns / 1ps
`default_nettype none

// CMR-WP-01 source-side turnaround guard.  This belongs between a NoC input
// Ack and the AckX input of the source Mousetrap: it delays reopening the
// source storage, never the CMR Ack path or an individual flit field.
//
// Keep direct library cells here.  A generic DelayElement is intentionally
// not used because the NoC signoff flow must not retain an unmapped generic
// timing primitive.
module AsyncEndpointSourceTurnaroundDelay (
    input  wire I,
    output wire Z
);
`ifdef ASIC_T28
  wire mid;
  DEL150D1BWP12T30P140 delay_150 (.I(I),   .Z(mid));
  DEL050D1BWP12T30P140 delay_050 (.I(mid), .Z(Z));
`else
  assign #(0.200) Z = I;
`endif
endmodule

`default_nettype wire
