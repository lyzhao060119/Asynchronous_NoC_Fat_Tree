`timescale 1ns / 1ps

module DLatchBank #(
    parameter WIDTH = 1
) (
    input  wire             reset,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output wire [WIDTH-1:0] q
);
`ifdef ASIC_T28
    // T28 has an asynchronous-clear transparent latch.  Global reset is high
    // at the Router boundary while CDN is low-active in the library.
    wire cdn = ~reset;
    genvar bit_index;
    generate
        for (bit_index = 0; bit_index < WIDTH; bit_index = bit_index + 1) begin : resettable_latch
            LHCNDQD1BWP12T30P140 latch_cell (
                .D(d[bit_index]), .E(en), .CDN(cdn), .Q(q[bit_index])
            );
        end
    endgenerate
`else
    reg [WIDTH-1:0] q_reg;
    assign q = q_reg;
    // Simulation / FPGA model of the same resettable transparent latch.
    always @(*) begin
        if (reset) q_reg = {WIDTH{1'b0}};
        else if (en) q_reg = d;
    end
`endif
endmodule
