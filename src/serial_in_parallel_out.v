`default_nettype none
`timescale 10ns/1ns

module serial_in_parallel_out #(
	parameter DATA_WIDTH=8
) (
	input clock,
	input reset,
	input shift_trigger,
	
	input signal,
	output reg [DATA_WIDTH-1:0] data
);

	always @(posedge clock)
	if(reset)
		data <= 0;
	else if(shift_trigger)
		data <= {data[DATA_WIDTH-2:0], signal};
endmodule
