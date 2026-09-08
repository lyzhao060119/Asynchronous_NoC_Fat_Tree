`timescale 1ns / 1ps

// One independent two-phase adapter per lane. The two Toggle Q outputs are
// the only signals presented to the OPM/IPM sides.
module LanePhaseAdapterDFF #(
    parameter LANES = 2
) (
    input  wire       reset,
    input  wire [LANES-1:0] LaneSelect,
    input  wire [LANES-1:0] IPMReqOut,
    input  wire [LANES-1:0] OPMAckOut,
    output wire [LANES-1:0] IPMAckIn,
    output wire [LANES-1:0] OPMReqIn
);
    wire [LANES-1:0] OPMReqInFire;
    wire [LANES-1:0] IPMAckInFire;

    genvar i;
    generate for (i = 0; i < LANES; i = i + 1) begin : lane
        assign OPMReqInFire[i] = LaneSelect[i] & (IPMReqOut[i] ^ IPMAckIn[i]);

        assign IPMAckInFire[i] = ~(LaneSelect[i] & (OPMAckOut[i] ^ OPMReqIn[i]));

        Toggle #(.RESET_VALUE(1'b0)) OPMReqIn_reg (
            .reset(reset), .En(OPMReqInFire[i]), .Q(OPMReqIn[i])
        );
        Toggle #(.RESET_VALUE(1'b0)) IPMAckIn_reg (
            .reset(reset), .En(IPMAckInFire[i]), .Q(IPMAckIn[i])
        );

    end endgenerate
endmodule
