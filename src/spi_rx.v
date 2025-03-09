`default_nettype none
`timescale 10ns/1ns

// CPOL=1
// CPHA=1
module spi_rx (
	input clock,
	input reset,

	input  SPI_clock,
	input  SPI_in,
	output SPI_out,
	input  SPI_not_chip_select,

	output reg   in_data_valid,
	output [7:0] in_data,
	// DO not wait for the next module to be ready, blocking will miss SPI data! input        in_data_ready,

/* verilator lint_off UNUSED */
	input        out_data_valid,

	input  [7:0] out_data,
/* verilator lint_on UNUSED */
	output reg   out_data_ready,

	output active
);
	/* verilator lint_off UNUSED */
	wire [7:0] unused;
	/* verilator lint_on UNUSED */
	wire SPI_clock_sampled, SPI_clock_rising, SPI_clock_falling;
	sampler SPI_clock_sampler(
		.clock(clock),
		.reset(reset),
		.signal(SPI_clock),
		.sampled_signal(SPI_clock_sampled),
		.falling(SPI_clock_falling),
		.rising(SPI_clock_rising)
	);
	wire SPI_not_chip_select_sampled, SPI_not_chip_select_rising, SPI_not_chip_select_falling;
	sampler SPI_not_chip_select_sampler(
		.clock(clock),
		.reset(reset),
		.signal(SPI_not_chip_select),
		.sampled_signal(SPI_not_chip_select_sampled),
		.falling(SPI_not_chip_select_falling),
		.rising(SPI_not_chip_select_rising)
	);
	assign active = !SPI_not_chip_select_sampled;
	wire SPI_in_sampled, SPI_in_rising, SPI_in_falling;
	sampler SPI_in_sampler(
		.clock(clock),
		.reset(reset),
		.signal(SPI_in),
		.sampled_signal(SPI_in_sampled),
		.falling(SPI_in_falling),
		.rising(SPI_in_rising)
	);
	wire [7:0] SPI_in_shift_data;
	serial_in_parallel_out #(.DATA_WIDTH(8)) SPI_in_shifter (
		.clock(clock),
		.reset(reset),
		.shift_trigger(SPI_clock_rising),
		.signal(SPI_in_sampled),
		.data(SPI_in_shift_data)
	);
	assign in_data = SPI_in_shift_data;

	localparam STATE_idle = 0;
	localparam STATE_io   = 1;

	reg [3:0] state = STATE_idle;
	reg [2:0] in_bit_counter;

	always @(posedge clock)
	if(reset)
		in_bit_counter <= 7;
	else case(state)
	STATE_io:
	begin
		if(SPI_clock_falling)
			in_bit_counter <= in_bit_counter + 1;
		
		if(in_bit_counter == 7 && SPI_clock_rising)
			in_data_valid <= 1'b1;
		else
			in_data_valid <= 1'b0;
	end
	default: begin end
	endcase

	always @(posedge clock)
	if(reset)
	begin
		state <= STATE_idle;
	end else begin
		if(SPI_not_chip_select_falling)
			state <= STATE_io;
		if(SPI_not_chip_select_rising)
			state <= STATE_idle;
	end

	reg [7:0] out_data_r;
	always @(posedge clock)
	if(reset)
	begin
		out_data_r <= 8'b0;
		out_data_ready <= 1;
	end else begin
		if(out_data_valid & out_data_ready)
		begin
			out_data_r <= out_data;
			out_data_ready <= 0;
		end else if(SPI_clock_falling & out_bit_counter == 7)
			out_data_ready <= 1;
	end

	reg [2:0] out_bit_counter;
	always @(posedge clock)
	if(reset)
	begin
		out_bit_counter <= 0;
	end else if(state == STATE_io)
	begin
		if(SPI_clock_rising)
			out_bit_counter <= out_bit_counter + 1;
	end

	reg SPI_out_r;
	always @(posedge clock)
		if(SPI_clock_falling)
			SPI_out_r <= out_data_r[7 - out_bit_counter];
	
	assign SPI_out = SPI_out_r;//out_data_r[7 - out_bit_counter];

	assign unused = {3'b0, SPI_clock_sampled, SPI_not_chip_select_sampled, SPI_not_chip_select_falling, SPI_in_rising, SPI_in_falling};
endmodule
