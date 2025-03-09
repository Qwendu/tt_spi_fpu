`default_nettype none

// icetime says max of 3 MHz, which is fine

module spi_fpu(
	input reset,
	input clock,
	input SPI_clock,
	input SPI_in,
	output SPI_out,
	input SPI_not_chip_select
);
	/* verilator lint_off UNUSED */
	wire [7:0] SPI_input_data;
	wire       SPI_input_data_valid;

	wire [7:0] SPI_output_data;
	wire       SPI_output_data_valid;
	wire       SPI_output_data_ready;
	wire       SPI_active;
	/* verilator lint_on UNUSED */
	spi_rx spi(
		.clock(clock),
		.reset(reset),
		.SPI_in(SPI_in),
		.SPI_out(SPI_out),
		.SPI_clock(SPI_clock),
		.SPI_not_chip_select(SPI_not_chip_select),

		.in_data_valid(SPI_input_data_valid),
		.in_data(SPI_input_data),

		.out_data_valid(SPI_output_data_valid),
		.out_data(SPI_output_data),
		.out_data_ready(SPI_output_data_ready),
		.active(SPI_active)
	);

	wire        float_result_ready;
	wire [31:0] float_result;
	reg  [31:0] float_registers[4] /*verilator public */;

	localparam COMMAND_WRITE_TO_REG  = 2'h0;
	localparam COMMAND_PERFORM_ADD   = 2'h1;
	localparam COMMAND_READ_FROM_REG = 2'h2;



	localparam STATE_IDLE               = 0;
	localparam STATE_READ_COMMAND       = 1;
	localparam STATE_IO_READ_TARGET_REG = 2;
	localparam STATE_IO                 = 3;
	localparam STATE_COMPUTE_READ_REGS  = 4;
	localparam STATE_COMPUTE_WAIT_FOR   = 5;
	localparam STATE_WAIT_FOR_END       = 6;

	reg [2:0] state;
	reg [1:0] read_command;
	reg [1:0] byte_counter;
	reg [1:0] register_id_result;
	reg [1:0] register_id_input_a;
	reg [1:0] register_id_input_b;

	always @(posedge clock)
	if(reset)
	begin
		state               <= STATE_IDLE;
		register_id_result  <= 0;
		register_id_input_a <= 0;
		register_id_input_b <= 0;
		float_registers[0] <= 0;
		float_registers[1] <= 0;
		float_registers[2] <= 0;
		float_registers[3] <= 0;
	end else if(!SPI_active)
		state <= STATE_IDLE;
	else case(state)
	STATE_IDLE: 
	begin
		if(SPI_active)
			state <= STATE_READ_COMMAND;
	end
	STATE_READ_COMMAND:
	begin
		if(SPI_input_data_valid)
		begin
			byte_counter <= 0;
			read_command[1:0] <= SPI_input_data[1:0];
			case(SPI_input_data[1:0])
			COMMAND_WRITE_TO_REG : state <= STATE_IO_READ_TARGET_REG;
			COMMAND_PERFORM_ADD  : state <= STATE_COMPUTE_READ_REGS;
			COMMAND_READ_FROM_REG: state <= STATE_IO_READ_TARGET_REG;
			default: state <= STATE_WAIT_FOR_END;
			endcase
		end
	end
	STATE_IO_READ_TARGET_REG:
	begin
		if(SPI_input_data_valid)
		begin
			register_id_result <= SPI_input_data[1:0];
			state <= STATE_IO;
		end
	end
	STATE_IO:
	begin
		case(read_command)
		COMMAND_WRITE_TO_REG:
			if(SPI_input_data_valid)
			begin
				float_registers[register_id_result][byte_counter * 8 +: 8] <= SPI_input_data;
				byte_counter <= byte_counter + 1;

				if(byte_counter == 2'd3)  state <= STATE_WAIT_FOR_END;
			end
		COMMAND_READ_FROM_REG:
			if(SPI_output_data_ready)
			begin
				byte_counter <= byte_counter + 1;
				if(byte_counter == 2'd3)  state <= STATE_WAIT_FOR_END;
			end
		default: state <= STATE_WAIT_FOR_END;
		endcase
	end
	STATE_COMPUTE_READ_REGS:
	begin
		if(SPI_input_data_valid)
		begin
			case(byte_counter)
			2'h0: register_id_input_a <= SPI_input_data[1:0];
			2'h1: register_id_input_b <= SPI_input_data[1:0];
			2'h2:
			begin
				register_id_result  <= SPI_input_data[1:0];
				state <= STATE_COMPUTE_WAIT_FOR;
			end
			default: state <= STATE_WAIT_FOR_END;
			endcase
			byte_counter <= byte_counter + 1;
		end
	end
	STATE_COMPUTE_WAIT_FOR:
		if(float_result_ready)
		begin
			float_registers[register_id_result] <= float_result;
			state <= STATE_WAIT_FOR_END;
		end
	STATE_WAIT_FOR_END:
	begin
	end

	endcase
	assign SPI_output_data       = state == STATE_IO ? float_registers[register_id_result][byte_counter * 8 +: 8] : 8'b0;
	assign SPI_output_data_valid = state == STATE_IO && read_command == COMMAND_READ_FROM_REG;

	float_adder_v2 adder(
		.clock(clock),
		.reset(reset),
		.in_valid(state == STATE_COMPUTE_WAIT_FOR),
		.in_a(float_registers[register_id_input_a]),
		.in_b(float_registers[register_id_input_b]),
		.out(float_result),
		.out_valid(float_result_ready),
		.out_reference(32'b0)
	);
endmodule
