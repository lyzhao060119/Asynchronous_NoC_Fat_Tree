`timescale 1ns / 1ps

module DelayElement
#(parameter DelayValue = 10)
(
	input	wire	I,
	output	wire	Z
    );
	
	assign	#(0.2*DelayValue)	Z = I;

endmodule
