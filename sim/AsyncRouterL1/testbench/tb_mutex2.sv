`timescale 1ns/1ps

module tb_mutex2 (
);
    reg req0 = 1'b0;
    reg req1 = 1'b0;
    wire gnt0;
    wire gnt1;

    Mutex2 dut (
        .req0(req0),
        .req1(req1),
        .gnt0(gnt0),
        .gnt1(gnt1)
    );
    
    initial begin
        #10;
        req0 = 1'b1;
        req1 = 1'b1;
    end
endmodule