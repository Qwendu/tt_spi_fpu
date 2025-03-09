`default_nettype none
`timescale 10ns/1ns

module sampler(
	input clock,
	input reset,
	input signal,
	output sampled_signal,

	output falling,
	output rising
);
	reg [1:0] sample_register;
	always @(posedge clock)
	if(reset)
		sample_register <= {signal, signal};
	else
		sample_register <= {sample_register[0], signal};

	assign sampled_signal = sample_register[1];
	assign falling =  sample_register[1] & !sample_register[0];
	assign rising  = !sample_register[1] &  sample_register[0];

endmodule
