`timescale 1ns / 1ps

// Synthesizable FPGA delay element. DelayValue maps to a LUT1 buffer chain.
// Real delay must be taken from post-route timing or board calibration.
module DelayElement
#(
    parameter DelayValue = 1,
    parameter DelayUnitPs = 150
)
(
    input  wire I,
    output wire Z
);

    (* DONT_TOUCH = "TRUE", KEEP = "TRUE" *) wire [DelayValue:0] d_tmp;

    assign d_tmp[0] = I;

    genvar i;
    generate
        for (i = 0; i < DelayValue; i = i + 1) begin : DelayUnit_delay
            (* DONT_TOUCH = "TRUE" *)
            LUT1 #(.INIT(2'b10)) D0 (
                .O(d_tmp[i+1]),
                .I0(d_tmp[i])
            );
        end
    endgenerate

    assign Z = d_tmp[DelayValue];

endmodule
