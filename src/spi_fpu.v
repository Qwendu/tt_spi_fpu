`default_nettype none



module spi_fpu(
	input clock,
	input reset,

	input  SPI_clock,
	input  SPI_in,
	input  SPI_not_chip_select,
	output SPI_out
);
	reg [31:0] float_registers[4];
	
	wire in_data_valid;
	wire [7:0] in_data;
	wire out_data_valid, out_data_ready;
	wire [7:0] out_data;
	spi_rx spi(
		.clock(clock),
		.reset(reset),
		.SPI_clock(SPI_clock),
		.SPI_in(SPI_in),
		.SPI_out(SPI_out),
		.SPI_not_chip_select(SPI_not_chip_select),
	);

	localparam COMMAND_IO  = 0;
	localparam COMMAND_ADD = 1;
	
	localparam STATE_idle    = 0;
	localparam STATE_io      = 1;
	localparam STATE_compute = 2;
	localparam STATE_done    = 3;
	reg [1:0] state;
	reg [1:0] command;
	reg [1:0] reg_a, reg_b, reg_result;
	reg [2:0] in_byte_count;
	reg [1:0] out_byte_count;
	always @(posedge clock)
	if(reset)
	begin
		state <= STATE_idle;
		command <= COMMAND_IO;
		reg_a <= 0;
		reg_b <= 0;
		reg_result <= 0;
		in_byte_count  <= 0;
		out_byte_count <= 0;
	end else case(state)
	STATE_idle:
		if(in_data_valid)
		begin
			command     <= in_data[7:6];
			reg_a       <= in_data[5:4];
			reg_b       <= in_data[3:2];
			reg_result  <= in_data[1:0];
			state <= command == COMMAND_IO ? STATE_io : STATE_compute;
		end
	STATE_io:
		if(out_data_valid & out_data_ready)
			out_byte_count <= out_byte_count + 1;
		if(in_data_valid)
		begin
			in_byte_count <= in_byte_count + 1;
			float_registers[in_byte_count[2] == 0 ? reg_a : reg_b][8 * in_byte_count[1:0] +: 8] <= in_data;
		end
	STATE_compute:
		case(command)
		COMMAND_ADD: float_registers[reg_result] <= float_add_result;
		default: begin end
		endcase
	STATE_done:
		in_byte_count <= 0;
		out_byte_count <= 0;
		if(SPI_not_chip_select)
			state <= STATE_idle;
	endcase
	
	assing out_data = float_registers[reg_result][byte_count[1:0]];
	
endmodule
