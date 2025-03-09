
module left_shifter #(
	parameter WIDTH = 32
) (
	input [WIDTH - 1:0] value,
	input [$clog2(WIDTH)-1:0] ammount,
	output[WIDTH - 1:0] result
);

	wire [WIDTH - 1:0] levels[$clog2(WIDTH) + 1] /* verilator split_var */;
	assign levels[0] = value;
	genvar layer;
	genvar bit_;
	generate
		for(layer = 0; layer < $clog2(WIDTH); layer = layer + 1)
		begin
			for(bit_ = 0; bit_ < WIDTH; bit_ = bit_ + 1)
			begin
				assign levels[layer + 1][bit_] = ammount[layer] ? (bit_ - (1<<layer) < 0 ? 1'b0 : levels[layer][bit_ - (1 << layer)]) : levels[layer][bit_];
			end
		end
	endgenerate
	assign result = levels[$clog2(WIDTH)];
endmodule
