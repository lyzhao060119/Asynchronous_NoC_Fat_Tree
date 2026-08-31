`timescale 1ns / 1ps

// ASIC delay element for TSMC 28nm (tcbn28hpcplus BWP12T30P140).
// DelayValue maps to a chain of DEL*D1 cells selected by DelayUnitPs.
// Sweep (2026-07-23): global DEL250/DEL150 PASS; global DEL100/DEL075 FAIL.
// Protect instances with set_dont_touch in DC; calibrate with post-synth SDF.
module DelayElement
#(
    parameter DelayValue = 1,
    parameter DelayUnitPs = 150
)
(
    input  wire I,
    output wire Z
);

    wire [DelayValue:0] d_tmp;

    assign d_tmp[0] = I;

    genvar i;
    generate
        if (DelayValue == 0) begin : DelayUnit_bypass
            assign Z = I;
        end else if (DelayUnitPs == 50) begin : DelayUnit_chain_050
            for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
                DEL050D1BWP12T30P140 D0 (
                    .I(d_tmp[i]),
                    .Z(d_tmp[i+1])
                );
            end
            assign Z = d_tmp[DelayValue];
        end else if (DelayUnitPs == 75) begin : DelayUnit_chain_075
            for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
                DEL075D1BWP12T30P140 D0 (
                    .I(d_tmp[i]),
                    .Z(d_tmp[i+1])
                );
            end
            assign Z = d_tmp[DelayValue];
        end else if (DelayUnitPs == 100) begin : DelayUnit_chain_100
            for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
                DEL100D1BWP12T30P140 D0 (
                    .I(d_tmp[i]),
                    .Z(d_tmp[i+1])
                );
            end
            assign Z = d_tmp[DelayValue];
        end else if (DelayUnitPs == 150) begin : DelayUnit_chain_150
            for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
                DEL150D1BWP12T30P140 D0 (
                    .I(d_tmp[i]),
                    .Z(d_tmp[i+1])
                );
            end
            assign Z = d_tmp[DelayValue];
        end else if (DelayUnitPs == 250) begin : DelayUnit_chain_250
            for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
                DEL250D1BWP12T30P140 D0 (
                    .I(d_tmp[i]),
                    .Z(d_tmp[i+1])
                );
            end
            assign Z = d_tmp[DelayValue];
        end else begin : DelayUnit_bad_param
            unsupported_delay_unit_ps unsupported_delay_unit_ps();
        end
    endgenerate

endmodule
