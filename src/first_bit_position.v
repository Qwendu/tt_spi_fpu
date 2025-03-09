`default_nettype none


module first_bit_position#(
	parameter WIDTH = 32
)(
	input [WIDTH - 1: 0] value,
	output [$clog2(WIDTH) - 1: 0] pos /* verilator split_var */
);
	localparam l2 = $clog2(WIDTH);
	wire [(1 << l2) - 1 : 0] layers[l2 + 1] /* verilator split_var */;
	wire pos_bits[l2] /* verilator split_var */;
	assign layers[l2][WIDTH - 1 : 0] = value;
	assign layers[l2][(1 << l2) - 1: WIDTH] = 0;
	
	genvar it;
	generate
		for(it = l2; it >= 1; it = it - 1)
		begin
			assign pos_bits[it - 1] = |layers[it][(1 << it) - 1 : 1 << (it - 1)];
			assign pos[it - 1] = pos_bits[it - 1];
		end
		for(it = l2; it >= 1; it = it - 1)
		begin
			assign layers[it - 1][(1 << (it - 1)) - 1 : 0] = pos_bits[it - 1] ? 
				layers[it][(1 << it) - 1 : (1 << (it - 1))]:
				layers[it][(1 << (it - 1)) - 1 :         0];
		end
	endgenerate
endmodule
